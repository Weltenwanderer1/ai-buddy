import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

/// Service for generating text embeddings via Ollama's local embedding API.
///
/// Uses `nomic-embed-text` model by default.
/// Base URL: http://127.0.0.1:11434 (local Ollama instance)
class EmbeddingService {
  final String baseUrl;
  final String model;
  final http.Client _client;

  /// Embedding cache: text → vector. Avoids recomputing for unchanged text.
  final Map<String, List<double>> _cache = {};

  EmbeddingService({
    this.baseUrl = 'http://127.0.0.1:11434',
    this.model = 'nomic-embed-text',
    http.Client? client,
  }) : _client = client ?? http.Client();

  /// Returns the embedding for [text], using cache if available.
  /// Returns null if the embedding server is unavailable.
  Future<List<double>?> getEmbedding(String text) async {
    final normalized = text.trim();
    if (normalized.isEmpty) return null;

    // Check cache
    final cached = _cache[normalized];
    if (cached != null) return cached;

    try {
      final embedding = await _fetchEmbedding(normalized);
      if (embedding != null) {
        _cache[normalized] = embedding;
      }
      return embedding;
    } catch (e) {
      debugPrint('EmbeddingService: failed to get embedding: $e');
      return null;
    }
  }

  /// Batch embed multiple texts at once.
  Future<Map<String, List<double>>> getEmbeddings(List<String> texts) async {
    final result = <String, List<double>>{};
    for (final text in texts) {
      final embedding = await getEmbedding(text);
      if (embedding != null) {
        result[text] = embedding;
      }
    }
    return result;
  }

  /// Clear the embedding cache.
  void clearCache() => _cache.clear();

  Future<List<double>?> _fetchEmbedding(String text) async {
    final url = Uri.parse('$baseUrl/api/embeddings');

    final response = await _client
        .post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'model': model,
            'prompt': text,
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final embedding = data['embedding'];
      if (embedding is List) {
        return embedding.map((v) => (v as num).toDouble()).toList();
      }
      return null;
    } else {
      debugPrint(
        'EmbeddingService: HTTP ${response.statusCode}: ${response.body}',
      );
      return null;
    }
  }

  /// Compute cosine similarity between two embedding vectors.
  /// Returns 0.0 for null/empty vectors.
  static double cosineSimilarity(List<double>? a, List<double>? b) {
    if (a == null || b == null || a.isEmpty || b.isEmpty) return 0.0;
    if (a.length != b.length) return 0.0;

    double dot = 0.0;
    double normA = 0.0;
    double normB = 0.0;

    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }

    if (normA == 0.0 || normB == 0.0) return 0.0;

    return dot / (sqrt(normA) * sqrt(normB));
  }

  void dispose() => _client.close();
}
