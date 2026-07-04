import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

class PersonaService extends ChangeNotifier {
  String _name = 'Buddy';
  List<String> _personality = [];
  String _greeting = '';
  String _backstory = '';
  bool _isComplete = false;

  String get name => _name;
  List<String> get personality => List.unmodifiable(_personality);
  String get greeting => _greeting;
  String get backstory => _backstory;
  bool get isComplete => _isComplete;

  /// Public setter for the persona name. Used by bootstrap and settings.
  set name(String v) {
    if (_name == v) return;
    _name = v;
    notifyListeners();
  }

  @visibleForTesting
  set testName(String v) => _name = v;
  @visibleForTesting
  set testPersonality(List<String> v) => _personality = v;
  @visibleForTesting
  set testGreeting(String v) => _greeting = v;
  @visibleForTesting
  set testBackstory(String v) => _backstory = v;
  @visibleForTesting
  set testIsComplete(bool v) => _isComplete = v;

  late File _file;

  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    _file = File('${dir.path}/ai_buddy/persona.json');
    if (await _file.exists()) {
      try {
        final data =
            jsonDecode(await _file.readAsString()) as Map<String, dynamic>;
        _name = data['name'] as String? ?? '';
        _personality = safeStringList(data['personality']);
        _greeting = data['greeting'] as String? ?? '';
        _backstory = data['backstory'] as String? ?? '';
        _isComplete = data['isComplete'] as bool? ?? false;
      } catch (e) {
        debugPrint('PersonaService init: could not read persona file: $e');
      }
    }
    notifyListeners();
  }

  @visibleForTesting
  static List<String> safeStringList(dynamic raw) {
    if (raw is! List) return [];
    return raw
        .map((e) => e?.toString() ?? '')
        .where((e) => e.isNotEmpty)
        .toList();
  }

  Future<void> save({
    required String name,
    required List<String> personality,
    required String greeting,
    String backstory = '',
  }) async {
    _name = name;
    _personality = personality;
    _greeting = greeting;
    _backstory = backstory;
    _isComplete = true;
    await _write();
    notifyListeners();
  }

  String buildSystemPrompt({String? evolutionContext}) {
    final traits = _personality.join(', ');
    final now = DateTime.now();
    final weekdays = [
      'Montag', 'Dienstag', 'Mittwoch', 'Donnerstag',
      'Freitag', 'Samstag', 'Sonntag'
    ];

    final buf = StringBuffer();
    buf.write('Du bist $_name. ');
    if (traits.isNotEmpty) buf.write('$traits. ');
    if (_backstory.isNotEmpty) buf.write('$_backstory. ');

    buf.write('\n${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}, ${weekdays[now.weekday - 1]} ${now.day}.${now.month}.${now.year} (${now.timeZoneName}). Zeit korrekt.');

    buf.write('\n\nREGELN:');
    buf.write('\n1. Tool-Call SOFORT nutzen wenn User etwas tun will. NIEMALS nur beschreiben.');
    buf.write('\n2. Nach Tool-Call: 1 kurzer Satz.');
    buf.write('\n3. Ohne Tool: max 2 Saetze.');
    buf.write('\n4. KEIN Markdown, KEINE Emojis (ausser User nutzt sie), KEIN *Roleplay*.');
    buf.write('\n5. Tool-Fehler: "Ging nicht: [Grund]."');

    if (evolutionContext != null && evolutionContext.isNotEmpty) {
      buf.write('\n\n$evolutionContext');
    }
    return buf.toString();
  }

  Map<String, dynamic> exportData() => {
        'name': _name,
        'personality': _personality,
        'greeting': _greeting,
        'backstory': _backstory,
        'isComplete': _isComplete,
      };

  Future<void> importData(Map<String, dynamic> data) async {
    _name = data['name'] as String? ?? '';
    _personality = safeStringList(data['personality']);
    _greeting = data['greeting'] as String? ?? '';
    _backstory = data['backstory'] as String? ?? '';
    _isComplete = data['isComplete'] as bool? ?? false;
    await _write();
    notifyListeners();
  }

  Future<void> _write() async {
    await _file.parent.create(recursive: true);
    await _file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(exportData()));
  }

  Future<void> clear() async {
    _name = '';
    _personality = [];
    _greeting = '';
    _backstory = '';
    _isComplete = false;
    await _write();
    notifyListeners();
  }
}
