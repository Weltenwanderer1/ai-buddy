import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

/// Learns from tool execution failures and suggests corrections.
///
/// Tracks per-tool: failure count, last error message, detected pattern,
/// and a learned tip. Used to enrich prompts before tool calls so the
/// LLM avoids repeating the same mistake.
///
/// Pattern: after a tool call returns isError=true → recordFailure(tool, error).
/// Before sending a prompt that likely calls a tool → appendToolHints(prompt, tools)
/// adds learned tips to the system prompt.
class ToolLearningService extends ChangeNotifier {
  final _minFailuresToHint = 2; // don't spam hints after 1 failure

  // toolName -> learned data
  Map<String, _ToolFailureProfile> _profiles = {};
  File? _file;

  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    _file = File('${dir.path}/ai_buddy/tool_learning.json');
    await _load();
  }

  /// Call this when a tool returns isError=true.
  void recordFailure(String toolName, String errorMessage, {Map<String, dynamic>? usedParameters}) {
    toolName = toolName.trim();
    if (toolName.isEmpty) return;

    final profile = _profiles.putIfAbsent(toolName, () => _ToolFailureProfile(toolName));
    profile.record(errorMessage, parameters: usedParameters);
    _profileChanged(profile);
    debugPrint('ToolLearning: recorded failure for $toolName (${profile.failureCount}x)');
  }

  /// Call this when a tool succeeds after previous failures.
  void recordSuccess(String toolName) {
    toolName = toolName.trim();
    if (toolName.isEmpty) return;

    final profile = _profiles[toolName];
    if (profile == null) return;
    profile.recordSuccess();
    _profileChanged(profile);
  }

  /// Should we give a hint for this tool?
  bool shouldHint(String toolName) {
    final profile = _profiles[toolName.trim()];
    if (profile == null) return false;
    return profile.shouldHint(minFailures: _minFailuresToHint);
  }

  /// Get a compact hint line for a tool, or empty if none exists.
  String getHint(String toolName) {
    final profile = _profiles[toolName.trim()];
    if (profile == null || !profile.shouldHint(minFailures: _minFailuresToHint)) {
      return '';
    }
    return profile.buildHint();
  }

  /// Build a system-prompt extension that gives the LLM hints about
  /// tools it should avoid misusing. Returns empty string if nothing to say.
  String buildHintSection(List<String> toolNames) {
    final hints = <String>[];
    for (final t in toolNames) {
      final hint = getHint(t);
      if (hint.isNotEmpty) hints.add('- $t: $hint');
    }
    if (hints.isEmpty) return '';
    return '\n📚 Gelernte Tipps (aus Fehlern):\n${hints.join("\n")}\n';
  }

  /// Erase all learned data (user can reset).
  Future<void> clear() async {
    _profiles.clear();
    notifyListeners();
    await _save();
  }

  // ── Private ──

  void _profileChanged(_ToolFailureProfile profile) {
    notifyListeners();
    _save();
  }

  Future<void> _load() async {
    final file = _file;
    if (file == null || !await file.exists()) return;
    try {
      final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      _profiles = data.map((k, v) {
        return MapEntry(k, _ToolFailureProfile.fromJson(k, v as Map<String, dynamic>));
      });
    } catch (e) {
      debugPrint('ToolLearning load error: $e');
      _profiles = {};
    }
  }

  Future<void> _save() async {
    final file = _file;
    if (file == null) return;
    await file.parent.create(recursive: true);
    final data = _profiles.map((k, v) => MapEntry(k, v.toJson()));
    await file.writeAsString(jsonEncode(data));
  }
}

/// Per-tool failure profile.
class _ToolFailureProfile {
  final String toolName;
  int failureCount = 0;
  int successCount = 0;
  final List<String> _recentErrors = []; // newest first
  String? _detectedPattern; // e.g. "missing location before navigate_to"

  _ToolFailureProfile(this.toolName);

  bool get hasPattern => _detectedPattern != null && _detectedPattern!.isNotEmpty;
  double get successRate =>
      successCount + failureCount == 0
          ? 1.0
          : successCount / (successCount + failureCount);

  bool shouldHint({int minFailures = 2}) =>
      failureCount >= minFailures && successRate < 0.5;

  void record(String errorMessage, {Map<String, dynamic>? parameters}) {
    failureCount++;
    _recentErrors.insert(0, errorMessage);
    if (_recentErrors.length > 5) _recentErrors.removeLast();
    _updatePattern();
  }

  void recordSuccess() {
    successCount++;
    // Don't clear pattern immediately; persist until multiple successes
  }

  void _updatePattern() {
    // Simple heuristic pattern detection
    final combined = _recentErrors.join(' ').toLowerCase();
    if (combined.contains('permission')) {
      _detectedPattern = 'wahrscheinlich fehlende Berechtigung — vorher prüfen';
    } else if (combined.contains('location') || combined.contains('standort') || combined.contains('gps')) {
      _detectedPattern = 'Standort-Daten prüfen/anfordern bevor Aufruf';
    } else if (combined.contains('not found') || combined.contains('nicht gefunden')) {
      _detectedPattern = 'Daten/Gerät zuerst prüfen — existiert?';
    } else if (combined.contains('timeout') || combined.contains('verbindung') || combined.contains('network')) {
      _detectedPattern = 'Netzwerk-Fehler — Offline-Modus oder Retry erwägen';
    } else if (combined.contains('invalid') || combined.contains('ungültig')) {
      _detectedPattern = 'Eingabe-Format überprüfen — Param-Typ prüfen';
    } else if (_recentErrors.length >= 3 && failureCount >= 3) {
      _detectedPattern = 'wiederholte Fehler — Voraussetzungen prüfen';
    }
  }

  String buildHint() {
    if (hasPattern) {
      return _detectedPattern!;
    }
    return 'letzter Fehler: ${_recentErrors.firstOrNull ?? "unbekannt"}';
  }

  Map<String, dynamic> toJson() => {
    'failureCount': failureCount,
    'successCount': successCount,
    'recentErrors': _recentErrors,
    'detectedPattern': _detectedPattern,
  };

  factory _ToolFailureProfile.fromJson(String name, Map<String, dynamic> json) {
    final p = _ToolFailureProfile(name);
    p.failureCount = (json['failureCount'] as num?)?.toInt() ?? 0;
    p.successCount = (json['successCount'] as num?)?.toInt() ?? 0;
    final errors = json['recentErrors'];
    if (errors is List) {
      p._recentErrors.addAll(errors.map((e) => e.toString()));
    }
    p._detectedPattern = json['detectedPattern'] as String?;
    return p;
  }
}
