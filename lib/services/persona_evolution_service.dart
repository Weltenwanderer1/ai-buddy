import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'ollama_cloud_service.dart';

/// Persona Evolution Service — learns user style and adapts persona over time.
///
/// After each conversation, the LLM extracts:
/// - New traits to add to the persona
/// - Things the user prefers or avoids
/// - Communication style observations
///
/// These evolve the persona's system prompt gradually.
class PersonaEvolutionService extends ChangeNotifier {
  final OllamaCloudService _llm;

  // Learned style data
  Map<String, dynamic> _learnedStyle = {};
  List<String> _learnedTraits = [];
  List<String> _avoidTopics = [];
  List<String> _preferredStyle = [];

  static const int _maxEvolutionCalls = 3; // don't evolve every single message

  File? _file;

  PersonaEvolutionService(this._llm);

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

  @visibleForTesting
  void parseEvolutionResponse(String response) => _parseEvolutionResponse(response);

  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    _file = File('${dir.path}/ai_buddy/persona_evolution.json');
    await _load();
  }

  /// Analyze recent conversation and evolve persona.
  /// Call this after a batch of messages (not every single message).
  Future<void> evolve(
    String userName,
    List<String> recentUserMessages,
    String currentPersonality,
  ) async {
    if (recentUserMessages.isEmpty) return;
    if (recentUserMessages.length < _maxEvolutionCalls) return;

    final userText = recentUserMessages.last;
    final prompt = '''Du bist ein Beobachter. Analysiere die folgende Nachricht von $userName.
Derzeitige Persönlichkeit des Buddys: $currentPersonality

Antworte AUSSCHLIEßLICH als JSON mit folgenden Feldern:
- "new_traits": array von strings — neue Persönlichkeitsmerkmale die zum Buddy passen würden
- "avoid": array von strings — Themen die der User nicht mag  
- "style": array von strings — Beschreibung des User-Schreibstils (kurz, direkt, humorvoll, etc.)

Nachricht von $userName: "$userText"

JSON:''';

    try {
      final response = await _llm.chat(
        systemPrompt: 'Du bist ein JSON-Generator. Antworte nur mit gültigem JSON.',
        messages: [{'role': 'user', 'content': prompt}],
        temperature: 0.3,
      );

      _parseEvolutionResponse(response);
      await _save();
      notifyListeners();
    } catch (e) {
      // Evolution failure is non-critical — just skip
    }
  }

  /// Lightweight evolution analysis triggered from ChatService.
  /// Uses the latest conversation snippet to evolve persona gradually.
  Future<void> analyzeConversation(String conversationSnippet) async {
    if (conversationSnippet.trim().isEmpty) return;

    final prompt = '''Analysiere den folgenden Conversation-Auszug und lerne daraus.
Antworte AUSSCHLIESSLICH als JSON:
- "new_traits": array von strings — Persönlichkeitsmerkmale die zum Buddy passen
- "avoid": array von strings — Themen die der User nicht mag
- "style": array von strings — Beschreibung des User-Schreibstils

$conversationSnippet

JSON:''';

    try {
      final response = await _llm.chat(
        systemPrompt: 'Du bist ein JSON-Generator. Antworte nur mit gültigem JSON.',
        messages: [{'role': 'user', 'content': prompt}],
        temperature: 0.3,
      );

      _parseEvolutionResponse(response);
      await _save();
      notifyListeners();
    } catch (e) {
      // Non-critical
    }
  }

  void _parseEvolutionResponse(String response) {
    try {
      // Try to extract JSON from the response
      final jsonStart = response.indexOf('{');
      final jsonEnd = response.lastIndexOf('}');
      if (jsonStart == -1 || jsonEnd == -1) return;

      final jsonStr = response.substring(jsonStart, jsonEnd + 1);
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;

      final newTraits = (data['new_traits'] as List?)?.map((e) => e.toString()).toList() ?? [];
      final avoid = (data['avoid'] as List?)?.map((e) => e.toString()).toList() ?? [];
      final style = (data['style'] as List?)?.map((e) => e.toString()).toList() ?? [];

      // Add new traits (no duplicates)
      for (final t in newTraits) {
        if (!_learnedTraits.contains(t)) _learnedTraits.add(t);
      }
      // Keep max 20 traits
      if (_learnedTraits.length > 20) {
        _learnedTraits = _learnedTraits.sublist(_learnedTraits.length - 20);
      }

      for (final a in avoid) {
        if (!_avoidTopics.contains(a)) _avoidTopics.add(a);
      }
      if (_avoidTopics.length > 10) {
        _avoidTopics = _avoidTopics.sublist(_avoidTopics.length - 10);
      }

      for (final s in style) {
        if (!_preferredStyle.contains(s)) _preferredStyle.add(s);
      }
      if (_preferredStyle.length > 10) {
        _preferredStyle = _preferredStyle.sublist(_preferredStyle.length - 10);
      }

      _learnedStyle = {
        'traits': _learnedTraits,
        'avoid': _avoidTopics,
        'style': _preferredStyle,
      };
    } catch (e) {
      // JSON parse failure — skip
    }
  }

  /// Build evolution context to inject into system prompt.
  String buildEvolutionContext() {
    if (_learnedTraits.isEmpty && _avoidTopics.isEmpty && _preferredStyle.isEmpty) {
      return '';
    }

    final parts = <String>[];
    if (_preferredStyle.isNotEmpty) {
      parts.add('User-Schreibstil: ${_preferredStyle.join(", ")}');
    }
    if (_avoidTopics.isNotEmpty) {
      parts.add('Themen vermeiden: ${_avoidTopics.join(", ")}');
    }
    return parts.join('. ');
  }

  Future<void> _load() async {
    final file = _file;
    if (file == null || !await file.exists()) return;
    try {
      final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      _learnedStyle = (data['style'] as Map?)?.cast<String, dynamic>() ?? {};
      _learnedTraits = (data['traits'] as List?)?.map((e) => e.toString()).toList() ?? [];
      _avoidTopics = (data['avoid'] as List?)?.map((e) => e.toString()).toList() ?? [];
      _preferredStyle = (data['user_style'] as List?)?.map((e) => e.toString()).toList() ?? [];
    } catch (e) {
      // Corrupted — start fresh
    }
  }

  Future<void> _save() async {
    final file = _file;
    if (file == null) return; // In-memory/test mode before init()
    await file.parent.create(recursive: true);
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert({
      'traits': _learnedTraits,
      'avoid': _avoidTopics,
      'user_style': _preferredStyle,
      'style': _learnedStyle,
    }));
  }

  Map<String, dynamic> exportData() => {
        'traits': _learnedTraits,
        'avoid': _avoidTopics,
        'user_style': _preferredStyle,
        'style': _learnedStyle,
      };

  Future<void> importData(Map<String, dynamic> data) async {
    _learnedTraits = (data['traits'] as List?)?.map((e) => e.toString()).toList() ?? [];
    _avoidTopics = (data['avoid'] as List?)?.map((e) => e.toString()).toList() ?? [];
    _preferredStyle = (data['user_style'] as List?)?.map((e) => e.toString()).toList() ?? [];
    _learnedStyle = (data['style'] as Map?)?.cast<String, dynamic>() ?? {};
    notifyListeners();
    await _save();
  }
}