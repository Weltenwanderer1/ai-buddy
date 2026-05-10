import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'embedding_service.dart';

const _uuid = Uuid();

/// Memory item stored locally, optionally with an embedding vector.
class MemoryItem {
  final String id;
  final String content;
  final String source; // 'user', 'assistant', 'system'
  final DateTime timestamp;
  final Map<String, dynamic> metadata;

  /// Embedding vector for semantic similarity search. May be null if not yet computed.
  final List<double>? embedding;

  MemoryItem({
    required this.id,
    required this.content,
    required this.source,
    DateTime? timestamp,
    this.metadata = const {},
    this.embedding,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'content': content,
        'source': source,
        'timestamp': timestamp.toIso8601String(),
        'metadata': metadata,
        if (embedding != null) 'embedding': embedding,
      };

  factory MemoryItem.fromJson(Map<String, dynamic> json) => MemoryItem(
        id: json['id'] as String? ?? _uuid.v4(),
        content: json['content'] as String? ?? '',
        source: json['source'] as String? ?? 'system',
        timestamp: json['timestamp'] != null
            ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
            : DateTime.now(),
        metadata: _safeMetadataCast(json['metadata']),
        embedding: _parseEmbedding(json['embedding']),
      );

  /// Safely cast metadata from JSON — handles non-String keys and type issues.
  static Map<String, dynamic> _safeMetadataCast(dynamic raw) {
    if (raw is! Map) return {};
    return raw.map((k, v) => MapEntry(k.toString(), v));
  }

  /// Parse embedding from JSON (List<double> or null).
  static List<double>? _parseEmbedding(dynamic raw) {
    if (raw == null) return null;
    if (raw is List) {
      try {
        return raw.map((v) => (v as num).toDouble()).toList();
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}

/// Memory Service — manages short-term and long-term memory.
///
/// Configuration is injected via constructor (from SettingsService):
/// - promotionThreshold: how many repeats before promoting to long-term
/// - ttlMinutes: short-term memory time-to-live in minutes
class MemoryService extends ChangeNotifier {
  final int promotionThreshold;
  final Duration ttl;

  List<MemoryItem> _shortTerm = [];
  List<MemoryItem> _longTerm = [];

  @visibleForTesting
  List<MemoryItem> get shortTermList => _shortTerm;
  @visibleForTesting
  List<MemoryItem> get longTermList => _longTerm;

  List<MemoryItem> get shortTermMemories => List.unmodifiable(_shortTerm);
  List<MemoryItem> get longTermMemories => List.unmodifiable(_longTerm);

  Directory? _dataDir;

  /// Optional override for data directory (useful for testing without path_provider).
  /// If null, init() will use getApplicationDocumentsDirectory().
  final Directory? _dataDirOverride;

  /// Optional embedding service for semantic similarity.
  /// If null, falls back to token overlap similarity.
  EmbeddingService? _embeddingService;

  /// Embedding cache for memory content and queries.
  final Map<String, List<double>> _embeddingCache = {};

  MemoryService({
    this.promotionThreshold = 3,
    this.ttl = const Duration(minutes: 60),
    Directory? dataDirOverride,
    EmbeddingService? embeddingService,
  }) : _dataDirOverride = dataDirOverride,
       _embeddingService = embeddingService;

  /// Inject or replace the embedding service at runtime.
  void setEmbeddingService(EmbeddingService service) {
    _embeddingService = service;
  }

  /// Get the current embedding service (may be null).
  EmbeddingService? get embeddingService => _embeddingService;

  Future<void> init() async {
    _dataDir = _dataDirOverride ?? await _getDataDir();
    await _loadShortTerm();
    await _loadLongTerm();
  }

  // --- Add ---

  Future<void> addShortTerm(
    String content, {
    String source = 'user',
    Map<String, dynamic>? metadata,
  }) async {
    final now = DateTime.now();

    MemoryItem? similar;
    for (final item in _shortTerm) {
      if (now.difference(item.timestamp) <= ttl && _similarity(content, item.content) > 0.6) {
        similar = item;
        break;
      }
    }

    if (similar != null) {
      final repeatRaw = similar.metadata['repeatCount'];
      final newCount = (repeatRaw is num ? repeatRaw.toInt() : 1) + 1;
      final updated = MemoryItem(
        id: similar.id,
        content: similar.content,
        source: similar.source,
        timestamp: similar.timestamp,
        metadata: {...similar.metadata, 'repeatCount': newCount},
      );
      final sid = similar.id;
      _shortTerm.removeWhere((m) => m.id == sid);

      if (newCount >= promotionThreshold) {
        _longTerm.add(MemoryItem(
          id: updated.id,
          content: updated.content,
          source: updated.source,
          timestamp: updated.timestamp,
          metadata: {
            ...updated.metadata,
            'promotedAt': DateTime.now().toIso8601String(),
          },
        ));
      } else {
        _shortTerm.add(updated);
      }
    } else {
      _shortTerm.add(MemoryItem(
        id: _uuid.v4(),
        content: content,
        source: source,
        metadata: {'repeatCount': 1, ...?metadata},
      ));
    }

    // Purge expired short-term
    _shortTerm.removeWhere((m) => now.difference(m.timestamp) > ttl);

    notifyListeners();
    await _saveShortTerm();
    if (similar != null && similar.metadata['repeatCount'] is num &&
        ((similar.metadata['repeatCount'] as num).toInt() + 1) >= promotionThreshold) {
      await _saveLongTerm();
    }

    // Generate embedding async, non-blocking
    _generateEmbeddingForLatest(content);
  }

  Future<void> addLongTerm(
    String content, {
    String source = 'system',
    Map<String, dynamic>? metadata,
  }) async {
    _longTerm.add(MemoryItem(
      id: _uuid.v4(),
      content: content,
      source: source,
      metadata: metadata ?? {},
    ));
    notifyListeners();
    await _saveLongTerm();
    // Generate embedding async, non-blocking
    _generateEmbeddingForLatest(content);
  }

  Future<void> clearShortTerm() async {
    _shortTerm.clear();
    notifyListeners();
    await _saveShortTerm();
  }

  Future<void> clearLongTerm() async {
    _longTerm.clear();
    notifyListeners();
    await _saveLongTerm();
  }

  Future<void> clearAll() async {
    _shortTerm.clear();
    _longTerm.clear();
    notifyListeners();
    await Future.wait([
      _saveShortTerm(),
      _saveLongTerm(),
    ]);
  }

  /// Delete a memory item by ID (from either short-term or long-term).
  Future<void> deleteById(String id) async {
    _shortTerm.removeWhere((m) => m.id == id);
    _longTerm.removeWhere((m) => m.id == id);
    notifyListeners();
    await _saveShortTerm();
    await _saveLongTerm();
  }

  /// Returns memories relevant to a query.
  /// Uses semantic embedding similarity if available, otherwise falls back
  /// to simple token overlap.
  Future<List<MemoryItem>> getRelevantMemories(String query, {int limit = 5}) async {
    if (query.trim().isEmpty) return [];

    // Try embedding-based similarity if embedding service is available
    if (_embeddingService != null) {
      final queryEmbedding = await _getOrComputeEmbedding(query);
      if (queryEmbedding != null) {
        return _getRelevantWithEmbeddings(queryEmbedding, limit: limit);
      }
    }

    // Fallback: token overlap
    return _getRelevantWithTokenOverlap(query, limit: limit);
  }

  /// Get embedding for query text, using cache.
  Future<List<double>?> _getOrComputeEmbedding(String text) async {
    final normalized = text.trim();

    // Check local cache
    if (_embeddingCache.containsKey(normalized)) {
      return _embeddingCache[normalized];
    }

    // Check memory item embeddings
    for (final mem in [..._shortTerm, ..._longTerm]) {
      if (mem.embedding != null && mem.content.trim() == normalized) {
        _embeddingCache[normalized] = mem.embedding!;
        return mem.embedding;
      }
    }

    // Try to fetch from embedding service
    final embedding = await _embeddingService?.getEmbedding(normalized);
    if (embedding != null) {
      _embeddingCache[normalized] = embedding;
    }
    return embedding;
  }

  /// Semantic similarity using embeddings.
  List<MemoryItem> _getRelevantWithEmbeddings(List<double> queryEmbedding, {int limit = 5}) {
    final scored = <({MemoryItem item, double score})>[];
    for (final mem in [..._shortTerm, ..._longTerm]) {
      double sim;
      if (mem.embedding != null && mem.embedding!.isNotEmpty) {
        sim = EmbeddingService.cosineSimilarity(queryEmbedding, mem.embedding!);
      } else {
        // Fall back to token overlap for items without embeddings
        sim = _similarity('', mem.content) * 0.3; // Reduced weight
      }
      final ageHours = DateTime.now().difference(mem.timestamp).inHours;
      final recency = 1.0 / (1.0 + ageHours / 24.0);
      scored.add((item: mem, score: sim * 0.7 + recency * 0.3));
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(limit).map((s) => s.item).toList();
  }

  /// Token overlap fallback.
  List<MemoryItem> _getRelevantWithTokenOverlap(String query, {int limit = 5}) {
    final scored = <({MemoryItem item, double score})>[];
    for (final mem in [..._shortTerm, ..._longTerm]) {
      final sim = _similarity(query, mem.content);
      final ageHours = DateTime.now().difference(mem.timestamp).inHours;
      final recency = 1.0 / (1.0 + ageHours / 24.0);
      scored.add((item: mem, score: sim * 0.7 + recency * 0.3));
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(limit).map((s) => s.item).toList();
  }

  /// Generate embedding for the latest memory with the given content, non-blocking.
  Future<void> _generateEmbeddingForLatest(String content) async {
    if (_embeddingService == null) return;

    try {
      final embedding = await _embeddingService!.getEmbedding(content);
      if (embedding == null) return;

      // Find the item and update its embedding
      for (int i = 0; i < _shortTerm.length; i++) {
        if (_shortTerm[i].content == content && _shortTerm[i].embedding == null) {
          _shortTerm[i] = MemoryItem(
            id: _shortTerm[i].id,
            content: _shortTerm[i].content,
            source: _shortTerm[i].source,
            timestamp: _shortTerm[i].timestamp,
            metadata: _shortTerm[i].metadata,
            embedding: embedding,
          );
          await _saveShortTerm();
          return;
        }
      }
      for (int i = 0; i < _longTerm.length; i++) {
        if (_longTerm[i].content == content && _longTerm[i].embedding == null) {
          _longTerm[i] = MemoryItem(
            id: _longTerm[i].id,
            content: _longTerm[i].content,
            source: _longTerm[i].source,
            timestamp: _longTerm[i].timestamp,
            metadata: _longTerm[i].metadata,
            embedding: embedding,
          );
          await _saveLongTerm();
          return;
        }
      }
    } catch (e) {
      debugPrint('MemoryService: embedding generation failed: $e');
    }
  }

  // --- Similarity (simple token overlap) ---

  /// Visible for testing.
  @visibleForTesting
  double similarity(String a, String b) => _similarity(a, b);

  double _similarity(String a, String b) {
    final normalizedA = a.trim().toLowerCase();
    final normalizedB = b.trim().toLowerCase();
    if (normalizedA.isEmpty || normalizedB.isEmpty) return 0.0;

    final tokensA = normalizedA.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toSet();
    final tokensB = normalizedB.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toSet();
    if (tokensA.isEmpty || tokensB.isEmpty) return 0.0;

    final intersection = tokensA.intersection(tokensB).length;
    return intersection / (tokensA.length + tokensB.length - intersection);
  }

  // --- Persistence ---

  Future<Directory> _getDataDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/ai_buddy/memory');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<void> _loadShortTerm() async {
    final dir = _dataDir;
    if (dir == null) return; // In-memory mode (testing)
    final file = File('${dir.path}/short_term.json');
    if (!await file.exists()) return;
    try {
      final data = jsonDecode(await file.readAsString()) as List;
      _shortTerm = data
          .map((e) => MemoryItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _shortTerm = [];
    }
  }

  Future<void> _loadLongTerm() async {
    final dir = _dataDir;
    if (dir == null) return;
    final file = File('${dir.path}/long_term.json');
    if (!await file.exists()) return;
    try {
      final data = jsonDecode(await file.readAsString()) as List;
      _longTerm = data
          .map((e) => MemoryItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _longTerm = [];
    }
  }

  Future<void> _saveShortTerm() async {
    final dir = _dataDir;
    if (dir == null) return; // In-memory mode (testing)
    final file = File('${dir.path}/short_term.json');
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(_shortTerm.map((m) => m.toJson()).toList()));
  }

  Future<void> _saveLongTerm() async {
    final dir = _dataDir;
    if (dir == null) return;
    final file = File('${dir.path}/long_term.json');
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(_longTerm.map((m) => m.toJson()).toList()));
  }

  // --- Export for backup ---

  Map<String, dynamic> exportAll() => {
        'short_term': _shortTerm.map((m) => m.toJson()).toList(),
        'long_term': _longTerm.map((m) => m.toJson()).toList(),
      };

  Future<void> importAll(Map<String, dynamic> data) async {
    _shortTerm = (data['short_term'] as List?)
            ?.map((e) => MemoryItem.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    _longTerm = (data['long_term'] as List?)
            ?.map((e) => MemoryItem.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    notifyListeners();
    await _saveShortTerm();
    await _saveLongTerm();
  }
}