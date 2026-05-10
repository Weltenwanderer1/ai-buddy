import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'embedding_service.dart';

const _uuid = Uuid();

/// Memory-Tiers:
/// - Core: Das Wesen des Assistenten (Identität, Beziehung, Verhalten).
///         Wird in JEDEN System-Prompt geladen.
/// - LongTerm: Wichtige Fakten über den User (Familie, Vorlieben, Gewohnheiten).
///             Relevanz-scored, wird bei passenden Queries geladen.
/// - ShortTerm: Aktueller Gesprächskontext. TTL-basiert, nicht persistent.
///
/// Promotion-Pipeline:
///   User sagt etwas Wichtiges → ShortTerm → (LLM bewertet) → Core oder LongTerm
class MemoryItem {
  final String id;
  final String content;
  final String source; // 'user', 'assistant', 'system', 'extracted'
  final DateTime timestamp;
  final Map<String, dynamic> metadata;
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

  static Map<String, dynamic> _safeMetadataCast(dynamic raw) {
    if (raw is! Map) return {};
    return raw.map((k, v) => MapEntry(k.toString(), v));
  }

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

/// 3-Tier Memory Service
class MemoryService extends ChangeNotifier {
  final int promotionThreshold;
  final Duration ttl;

  // ── Tier 1: Core (Identity) ──
  List<MemoryItem> _core = [];

  // ── Tier 2: Long-Term (User Facts) ──
  List<MemoryItem> _longTerm = [];

  // ── Tier 3: Short-Term (Conversation Context) ──
  List<MemoryItem> _shortTerm = [];

  Directory? _dataDir;
  final Directory? _dataDirOverride;
  EmbeddingService? _embeddingService;
  final Map<String, List<double>> _embeddingCache = {};

  MemoryService({
    this.promotionThreshold = 2,
    this.ttl = const Duration(minutes: 30),
    Directory? dataDirOverride,
    EmbeddingService? embeddingService,
  }) : _dataDirOverride = dataDirOverride,
       _embeddingService = embeddingService;

  // Getters
  List<MemoryItem> get coreMemories => List.unmodifiable(_core);
  List<MemoryItem> get longTermMemories => List.unmodifiable(_longTerm);
  List<MemoryItem> get shortTermMemories => List.unmodifiable(_shortTerm);

  void setEmbeddingService(EmbeddingService service) {
    _embeddingService = service;
  }

  EmbeddingService? get embeddingService => _embeddingService;

  Future<void> init() async {
    _dataDir = _dataDirOverride ?? await _getDataDir();
    await _loadCore();
    await _loadLongTerm();
    await _loadShortTerm();
  }

  // ── Core Tier ──

  Future<void> addCore(String content, {String source = 'system', Map<String, dynamic>? metadata}) async {
    _core.add(MemoryItem(
      id: _uuid.v4(),
      content: content,
      source: source,
      metadata: metadata ?? {},
    ));
    notifyListeners();
    await _saveCore();
  }

  Future<void> removeCore(String id) async {
    _core.removeWhere((m) => m.id == id);
    notifyListeners();
    await _saveCore();
  }

  /// Build the core context string for system prompt injection.
  String buildCoreContext() {
    if (_core.isEmpty) return '';
    final parts = _core.map((m) => m.content).toList();
    return '=== DEIN KERN-SELBST ===\n${parts.join("\n")}\n';
  }

  // ── Long-Term Tier ──

  Future<void> addLongTerm(String content, {String source = 'system', Map<String, dynamic>? metadata}) async {
    _longTerm.add(MemoryItem(
      id: _uuid.v4(),
      content: content,
      source: source,
      metadata: metadata ?? {},
    ));
    notifyListeners();
    await _saveLongTerm();
    _generateEmbeddingForLatest(content);
  }

  Future<void> removeLongTerm(String id) async {
    _longTerm.removeWhere((m) => m.id == id);
    notifyListeners();
    await _saveLongTerm();
  }

  // ── Short-Term Tier ──

  Future<void> addShortTerm(String content, {String source = 'user', Map<String, dynamic>? metadata}) async {
    final now = DateTime.now();

    // Deduplication: similar content within TTL gets repeat-counted
    MemoryItem? similar;
    for (final item in _shortTerm) {
      if (now.difference(item.timestamp) <= ttl && _similarity(content, item.content) > 0.7) {
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
      _shortTerm.add(updated);
    } else {
      _shortTerm.add(MemoryItem(
        id: _uuid.v4(),
        content: content,
        source: source,
        metadata: {'repeatCount': 1, ...?metadata},
      ));
    }

    // Purge expired
    _shortTerm.removeWhere((m) => now.difference(m.timestamp) > ttl);
    notifyListeners();
    await _saveShortTerm();
  }

  // ── Promotion Pipeline ──

  /// Promote a short-term memory to long-term or core based on LLM assessment.
  /// Called by ChatService after tool loop / response.
  Future<void> promoteIfImportant(String content, String assessment) async {
    final lower = assessment.toLowerCase().trim();
    if (lower.contains('core') || lower.contains('essential') || lower.contains('identity')) {
      await addCore(content, source: 'extracted', metadata: {'promotedFrom': 'short_term', 'reason': assessment});
    } else if (lower.contains('long') || lower.contains('important') || lower.contains('fact')) {
      await addLongTerm(content, source: 'extracted', metadata: {'promotedFrom': 'short_term', 'reason': assessment});
    }
  }

  // ── Retrieval ──

  /// Get memories relevant to a query, searching all tiers.
  /// Returns: { 'core': [...], 'longTerm': [...], 'shortTerm': [...] }
  Future<Map<String, List<MemoryItem>>> retrieveRelevant(String query, {int limitPerTier = 5}) async {
    final result = <String, List<MemoryItem>>{
      'core': [],
      'longTerm': [],
      'shortTerm': [],
    };

    if (query.trim().isEmpty) return result;

    // Core: always return all (it's small by design)
    result['core'] = List.unmodifiable(_core);

    // Long-term: semantic or token search
    result['longTerm'] = await _searchTier(_longTerm, query, limit: limitPerTier);

    // Short-term: recency-biased search
    result['shortTerm'] = _searchShortTerm(query, limit: limitPerTier);

    return result;
  }

  Future<List<MemoryItem>> _searchTier(List<MemoryItem> tier, String query, {int limit = 5}) async {
    if (tier.isEmpty) return [];

    if (_embeddingService != null) {
      final queryEmbedding = await _getOrComputeEmbedding(query);
      if (queryEmbedding != null) {
        return _searchWithEmbeddings(tier, queryEmbedding, limit: limit);
      }
    }

    return _searchWithTokenOverlap(tier, query, limit: limit);
  }

  List<MemoryItem> _searchShortTerm(String query, {int limit = 5}) {
    final now = DateTime.now();
    final scored = <({MemoryItem item, double score})>[];
    for (final mem in _shortTerm) {
      final sim = _similarity(query, mem.content);
      final ageMinutes = now.difference(mem.timestamp).inMinutes;
      final recency = 1.0 / (1.0 + ageMinutes / 10.0);
      scored.add((item: mem, score: sim * 0.5 + recency * 0.5));
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(limit).map((s) => s.item).toList();
  }

  // ── Embedding Search ──

  Future<List<double>?> _getOrComputeEmbedding(String text) async {
    final normalized = text.trim();
    if (_embeddingCache.containsKey(normalized)) {
      return _embeddingCache[normalized];
    }
    for (final mem in [..._longTerm, ..._shortTerm]) {
      if (mem.embedding != null && mem.content.trim() == normalized) {
        _embeddingCache[normalized] = mem.embedding!;
        return mem.embedding;
      }
    }
    final embedding = await _embeddingService?.getEmbedding(normalized);
    if (embedding != null) {
      _embeddingCache[normalized] = embedding;
    }
    return embedding;
  }

  List<MemoryItem> _searchWithEmbeddings(List<MemoryItem> tier, List<double> queryEmbedding, {int limit = 5}) {
    final scored = <({MemoryItem item, double score})>[];
    for (final mem in tier) {
      double sim;
      if (mem.embedding != null && mem.embedding!.isNotEmpty) {
        sim = EmbeddingService.cosineSimilarity(queryEmbedding, mem.embedding!);
      } else {
        sim = _similarity('', mem.content) * 0.2;
      }
      final ageHours = DateTime.now().difference(mem.timestamp).inHours;
      final recency = 1.0 / (1.0 + ageHours / 24.0);
      scored.add((item: mem, score: sim * 0.7 + recency * 0.3));
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(limit).map((s) => s.item).toList();
  }

  List<MemoryItem> _searchWithTokenOverlap(List<MemoryItem> tier, String query, {int limit = 5}) {
    final scored = <({MemoryItem item, double score})>[];
    for (final mem in tier) {
      final sim = _similarity(query, mem.content);
      final ageHours = DateTime.now().difference(mem.timestamp).inHours;
      final recency = 1.0 / (1.0 + ageHours / 24.0);
      scored.add((item: mem, score: sim * 0.7 + recency * 0.3));
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(limit).map((s) => s.item).toList();
  }

  // ── Similarity ──

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

  // ── Persistence ──

  Future<Directory> _getDataDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/ai_buddy/memory');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<void> _loadCore() async {
    final dir = _dataDir;
    if (dir == null) return;
    final file = File('${dir.path}/core.json');
    if (!await file.exists()) return;
    try {
      final data = jsonDecode(await file.readAsString()) as List;
      _core = data.map((e) => MemoryItem.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      _core = [];
    }
  }

  Future<void> _loadLongTerm() async {
    final dir = _dataDir;
    if (dir == null) return;
    final file = File('${dir.path}/long_term.json');
    if (!await file.exists()) return;
    try {
      final data = jsonDecode(await file.readAsString()) as List;
      _longTerm = data.map((e) => MemoryItem.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      _longTerm = [];
    }
  }

  Future<void> _loadShortTerm() async {
    final dir = _dataDir;
    if (dir == null) return;
    final file = File('${dir.path}/short_term.json');
    if (!await file.exists()) return;
    try {
      final data = jsonDecode(await file.readAsString()) as List;
      _shortTerm = data.map((e) => MemoryItem.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      _shortTerm = [];
    }
  }

  Future<void> _saveCore() async {
    final dir = _dataDir;
    if (dir == null) return;
    final file = File('${dir.path}/core.json');
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(_core.map((m) => m.toJson()).toList()));
  }

  Future<void> _saveLongTerm() async {
    final dir = _dataDir;
    if (dir == null) return;
    final file = File('${dir.path}/long_term.json');
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(_longTerm.map((m) => m.toJson()).toList()));
  }

  Future<void> _saveShortTerm() async {
    final dir = _dataDir;
    if (dir == null) return;
    final file = File('${dir.path}/short_term.json');
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(_shortTerm.map((m) => m.toJson()).toList()));
  }

  Future<void> _generateEmbeddingForLatest(String content) async {
    if (_embeddingService == null) return;
    try {
      final embedding = await _embeddingService!.getEmbedding(content);
      if (embedding == null) return;
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

  // ── Clear ──

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

  Future<void> clearCore() async {
    _core.clear();
    notifyListeners();
    await _saveCore();
  }

  Future<void> clearAll() async {
    _shortTerm.clear();
    _longTerm.clear();
    _core.clear();
    notifyListeners();
    await Future.wait([_saveShortTerm(), _saveLongTerm(), _saveCore()]);
  }

  Future<void> deleteById(String id) async {
    _shortTerm.removeWhere((m) => m.id == id);
    _longTerm.removeWhere((m) => m.id == id);
    _core.removeWhere((m) => m.id == id);
    notifyListeners();
    await Future.wait([_saveShortTerm(), _saveLongTerm(), _saveCore()]);
  }

  // ── Export / Import ──

  Map<String, dynamic> exportAll() => {
    'core': _core.map((m) => m.toJson()).toList(),
    'long_term': _longTerm.map((m) => m.toJson()).toList(),
    'short_term': _shortTerm.map((m) => m.toJson()).toList(),
  };

  Future<void> importAll(Map<String, dynamic> data) async {
    _core = (data['core'] as List?)
      ?.map((e) => MemoryItem.fromJson(e as Map<String, dynamic>))
      .toList() ?? [];
    _longTerm = (data['long_term'] as List?)
      ?.map((e) => MemoryItem.fromJson(e as Map<String, dynamic>))
      .toList() ?? [];
    _shortTerm = (data['short_term'] as List?)
      ?.map((e) => MemoryItem.fromJson(e as Map<String, dynamic>))
      .toList() ?? [];
    notifyListeners();
    await Future.wait([_saveCore(), _saveLongTerm(), _saveShortTerm()]);
  }
}
