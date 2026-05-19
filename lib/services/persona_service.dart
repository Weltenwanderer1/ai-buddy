import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

class PersonaService extends ChangeNotifier {
  String _name = 'Agent';
  List<String> _personality = [];
  String _greeting = '';
  String _backstory = '';
  bool _isComplete = false;

  String get name => _name;
  List<String> get personality => List.unmodifiable(_personality);
  String get greeting => _greeting;
  String get backstory => _backstory;
  bool get isComplete => _isComplete;

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
      'Montag',
      'Dienstag',
      'Mittwoch',
      'Donnerstag',
      'Freitag',
      'Samstag',
      'Sonntag'
    ];
    final cd =
        '${weekdays[now.weekday - 1]}, ${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}'
        '.${now.year}, ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} Uhr';

    final buf = StringBuffer();
    buf.write('Du bist $_name. ');
    if (traits.isNotEmpty) buf.write('Persoenlichkeit: $traits. ');
    if (_backstory.isNotEmpty) buf.write('Hintergrund: $_backstory. ');

    // CRITICAL: device context + live data
    buf.write('\n\nSYSTEM: Du laeufst auf einem Android-Smartphone. ');
    buf.write('Es ist $cd (${now.timeZoneName}). ');
    buf.write(
        'Diese Zeitangabe ist VOLLSTAENDIG KORREKT -- nie widersprechen oder neu berechnen.');

    // CRITICAL: tool rules — must come BEFORE anything else
    buf.write('\n\nTOOL-REGELN (hoechste Prioritaet):');
    buf.write(
        '\n1. Wenn der Nutzer dich bittet, etwas zu TUN (App oeffnen, Navigation starten, Timer stellen, Datei schreiben, Websuche, Erinnerung) --> rufe SOFORT das entsprechende Tool auf. NIEMALS nur beschreiben was du tun wuerdest.');
    buf.write(
        '\n2. Tools die du hast: open_app, open_navigation, set_reminder, get_current_time, web_search, list_files, read_file, write_file, get_battery_info, get_device_info, share_text, read_config, update_config, add_calendar_event, get_calendar_events.');
    buf.write(
        '\n3. Deine Antwort NACH einem Tool-Call: ein kurzer, natürlicher Satz. Beispiel: "Spotify ist offen." oder "Navigation gestartet."');
    buf.write(
        '\n4. OHNE Tool-Call darf deine Antwort nur 1-2 Saetze sein. Kein Geschwafel.');
    buf.write(
        '\n5. KEINE Aktionsbeschreibungen in Sternchen. KEIN *lacht*, *denkt nach*, *oeffnet App*. Das sind KEINE Tools.');
    buf.write(
        '\n6. Wenn ein Tool fehlschlaegt, sag: "Ging nicht: [Grund]. Versuch es anders?"');

    // Format rules
    buf.write('\n\nFORMAT-REGELN:');
    buf.write('\n- KEIN Markdown (**, *, __, ~~, ```).');
    buf.write(
        '\n- KEINE Emojis in der Antwort (ausser der Nutzer benutzt sie).');
    buf.write('\n- KEINE Roleplay-Actions (*hust*, *lacht*).');
    buf.write('\n- Sprich normales Deutsch, wie in einem Chat.');

    buf.write(
        '\n\nWICHTIG: Tool-Calls sind DEINE einzige echte Handlungsfaehigkeit. Ohne Tool-Call passiert NICHTS. Beschreibe nie eine Aktion die du nicht per Tool ausfuehrst.');

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
