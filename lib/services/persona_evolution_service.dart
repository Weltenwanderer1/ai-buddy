import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

/// Persona Evolution Service — learns user style and adapts persona over time.
///
/// After each conversation, the LLM extracts:
/// - New traits to add to the persona
/// - Things the user prefers or avoids
/// - Communication style observations
///
/// These evolve the persona's system prompt gradually.
class PersonaEvolutionService extends ChangeNotifier {

  // Learned style data
  Map<String, dynamic> _learnedStyle = {};
  List<String> _learnedTraits = [];
  List<String> _avoidTopics = [];
  List<String> _preferredStyle = [];

  File? _file;

  PersonaEvolutionService();

  Map<String, dynamic> get learnedStyle => Map.unmodifiable(_learnedStyle);
  List<String> get learnedTraits => List.unmodifiable(_learnedTraits);
  List<String> get avoidTopics => List.unmodifiable(_avoidTopics);

  /// @visibleForTesting — direct access to internal lists for testing.
  @visibleForTesting
  List<String> get testLearnedTraits => _learnedTraits;
  @visibleForTesting
  set testLearnedTraits(List<String> v) => _learnedTraits = v;
  @visibleForTesting
  List<String> get testAvoidTopics => _avoidTopics;
  @visibleForTesting
  set testAvoidTopics(List<String> v) => _avoidTopics = v;
  @visibleForTesting
  List<String> get testPreferredStyle => _preferredStyle;
  @visibleForTesting
  set testPreferredStyle(List<String> v) => _preferredStyle = v;
  @visibleForTesting
  Map<String, dynamic> get testLearnedStyle => _learnedStyle;
  @visibleForTesting
  set testLearnedStyle(Map<String, dynamic> v) => _learnedStyle = v;

  Future<void> clear() async {
    _learnedStyle = {};
    _learnedTraits = [];
    _avoidTopics = [];
    _preferredStyle = [];
    notifyListeners();
    await _save();
  }

  Map<String, dynamic> exportData() => {
    'learnedStyle': _learnedStyle,
    'learnedTraits': _learnedTraits,
    'avoidTopics': _avoidTopics,
    'preferredStyle': _preferredStyle,
  };

  Future<void> importData(Map<String, dynamic> data) async {
    _learnedStyle = Map<String, dynamic>.from(data['learnedStyle'] ?? {});
    _learnedTraits = List<String>.from(data['learnedTraits'] ?? []);
    _avoidTopics = List<String>.from(data['avoidTopics'] ?? []);
    _preferredStyle = List<String>.from(data['preferredStyle'] ?? []);
    notifyListeners();
  }

  void parseEvolutionResponse(String response) => _parseEvolutionResponse(response);

  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    _file = File('${dir.path}/ai_buddy/persona_evolution.json');
    await _load();
  }

  /// Analyze recent conversation and evolve persona.
  /// Call this after a batch of messages (not every single message).
  Future<void> evolve(dynamic history) async {
    // Local-only: evolution uses local model in ChatService._triggerEvolutionAndIntrospection
  }

  Future<void> analyzeConversation(String userMessage, String assistantReply) async {
    // Local-only: analysis uses local model in ChatService._triggerEvolutionAndIntrospection
  }

  String buildEvolutionContext() {
    if (_learnedTraits.isEmpty && _avoidTopics.isEmpty && _preferredStyle.isEmpty) {
      return '';
    }
    final buf = StringBuffer();
    if (_learnedTraits.isNotEmpty) {
      buf.writeln('Gelernte Eigenschaften: ${_learnedTraits.join(", ")}');
    }
    if (_avoidTopics.isNotEmpty) {
      buf.writeln('Vermeiden: ${_avoidTopics.join(", ")}');
    }
    if (_preferredStyle.isNotEmpty) {
      buf.writeln('Bevorzugter Stil: ${_preferredStyle.join(", ")}');
    }
    return buf.toString().trim();
  }

  void _parseEvolutionResponse(String response) {
    final lines = response.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('- ') && trimmed.length > 2) {
        final item = trimmed.substring(2).trim();
        if (item.isNotEmpty && !_learnedTraits.contains(item)) {
          _learnedTraits.add(item);
        }
      }
    }
    notifyListeners();
    _save();
  }

  Future<void> _load() async {
    final file = _file;
    if (file == null || !await file.exists()) return;
    try {
      final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      _learnedStyle = Map<String, dynamic>.from(data['learnedStyle'] ?? {});
      _learnedTraits = List<String>.from(data['learnedTraits'] ?? []);
      _avoidTopics = List<String>.from(data['avoidTopics'] ?? []);
      _preferredStyle = List<String>.from(data['preferredStyle'] ?? []);
    } catch (e) {
      debugPrint('PersonaEvolution load error: $e');
    }
  }

  Future<void> _save() async {
    final file = _file;
    if (file == null) return;
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode({
      'learnedStyle': _learnedStyle,
      'learnedTraits': _learnedTraits,
      'avoidTopics': _avoidTopics,
      'preferredStyle': _preferredStyle,
    }));
  }
}
