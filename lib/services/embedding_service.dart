import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

/// Service for generating text embeddings via configurable providers.
///
/// Supports:
/// - Ollama native: POST /api/embeddings  {model, prompt}
/// - OpenAI-compatible: POST /v1/embeddings  {model, input}
///   (covers OpenAI, OpenRouter, and any OpenAI-compatible endpoint)
class EmbeddingService {
  final String baseUrl;
  final String model;
  final String apiKey;
  final String provider; // 'ollama' or 'openai'
  final http.Client _client;

  /// Embedding cache: text → vector. Avoids recomputing for unchanged text.
  final Map<String, List<double>> _cache = {};

  EmbeddingService({
    required this.baseUrl,
    required this.model,
    this.apiKey = '',
    this.provider = 'ollama',
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
    if (provider.toLowerCase() == 'ollama') {
      return await _fetchOllamaEmbedding(text);
    } else {
      return await _fetchOpenAiEmbedding(text);
    }
  }

  /// Entfernt trailing Slashes UND bereits enthaltene API-Suffixe, damit
  /// z.B. der Default 'https://ollama.com/api' nicht zu
  /// '/api/api/embeddings' wird (analog zur Normalisierung im
  /// OllamaCloudService).
  static String _normalizeBase(String base) {
    var b = base.replaceAll(RegExp(r'/+$'), '');
    // OpenRouter serviert alles unter /api/v1/... — das /api NICHT strippen,
    // sonst geht die Anfrage an openrouter.ai/v1/... (404).
    if (b.toLowerCase().contains('openrouter')) {
      return b.replaceAll(RegExp(r'/v1$'), '');
    }
    b = b.replaceAll(RegExp(r'/(api/v1|api|v1)$'), '');
    return b;
  }

  Future<List<double>?> _fetchOllamaEmbedding(String text) async {
    final normalizedBase = _normalizeBase(baseUrl);
    final url = Uri.parse('$normalizedBase/api/embeddings');

    final response = await _client
        .post(
          url,
          headers: {
            'Content-Type': 'application/json',
            if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey',
          },
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
        'EmbeddingService Ollama: HTTP ${response.statusCode}: ${response.body}',
      );
      return null;
    }
  }

  Future<List<double>?> _fetchOpenAiEmbedding(String text) async {
    final normalizedBase = _normalizeBase(baseUrl);
    final url = Uri.parse('$normalizedBase/v1/embeddings');

    final response = await _client
        .post(
          url,
          headers: {
            'Content-Type': 'application/json',
            if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey',
          },
          body: jsonEncode({
            'model': model,
            'input': text,
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = data['data'];
      if (choices is List && choices.isNotEmpty) {
        final embedding = choices.first['embedding'];
        if (embedding is List) {
          return embedding.map((v) => (v as num).toDouble()).toList();
        }
      }
      return null;
    } else {
      debugPrint(
        'EmbeddingService OpenAI: HTTP ${response.statusCode}: ${response.body}',
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
