import 'package:flutter/services.dart';
import 'tool_interface.dart';
import 'tool_definition.dart';
import 'tool_result.dart';

/// Cross-app automation: lets the buddy operate ANY other app on the user's
/// behalf via Android's AccessibilityService — read the current screen, tap
/// buttons/labels, type text, scroll, and navigate (back/home/recents).
///
/// This is what turns "open Spotify and play my Discover Weekly" or "reply to
/// the last WhatsApp from Anna" into real, multi-step device operation.
///
/// Typical loop the LLM runs:
///   1. read_screen  → see what is currently visible
///   2. tap / input_text / scroll → act on it
///   3. read_screen  → verify and continue
class ControlScreenTool implements ToolInterface {
  static const MethodChannel _channel =
      MethodChannel('com.aibuddy.app/accessibility');

  static const _definition = ToolDefinition(
    name: 'control_screen',
    description:
        'Bedient JEDE andere App fuer den Nutzer per Android-Bedienungshilfe: '
        'liest den aktuellen Bildschirm und tippt/schreibt/scrollt darin. '
        'Damit lassen sich Apps steuern, die keine eigene API haben '
        '(z.B. in Spotify Play druecken, in WhatsApp antworten, Formulare ausfuellen). '
        'Ablauf: erst "read_screen", dann handeln (tap/input_text/scroll), dann '
        'zur Kontrolle erneut "read_screen". '
        'Aktionen: read_screen (sichtbare Elemente auflisten), tap (Element per '
        'Text antippen), tap_at (Koordinaten), input_text (Text ins fokussierte '
        'Feld), scroll (up/down), back, home, recents, notifications, '
        'is_enabled (prueft ob Bedienungshilfe aktiv), enable (oeffnet die '
        'Einstellung zum Aktivieren).',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'action': {
          'type': 'string',
          'enum': [
            'read_screen',
            'tap',
            'tap_at',
            'input_text',
            'scroll',
            'back',
            'home',
            'recents',
            'notifications',
            'is_enabled',
            'enable',
          ],
          'description': 'Welche Aktion ausgefuehrt werden soll.',
        },
        'text': {
          'type': 'string',
          'description':
              'Bei tap: der sichtbare Text/Beschriftung des Ziel-Elements. '
                  'Bei input_text: der einzugebende Text.',
        },
        'x': {'type': 'integer', 'description': 'Bei tap_at: X-Koordinate (Pixel).'},
        'y': {'type': 'integer', 'description': 'Bei tap_at: Y-Koordinate (Pixel).'},
        'direction': {
          'type': 'string',
          'enum': ['up', 'down'],
          'description': 'Bei scroll: Richtung. up = zurueck, down = weiter.',
        },
      },
      'required': ['action'],
    },
  );

  @override
  ToolDefinition get definition => _definition;

  @override
  Future<ToolResult> execute(Map<String, dynamic> parameters) async {
    final action = (parameters['action'] as String?)?.trim() ?? '';

    try {
      switch (action) {
        case 'is_enabled':
          final enabled = await _channel.invokeMethod('isEnabled') as bool? ?? false;
          return _ok(parameters,
              enabled
                  ? 'Bedienungshilfe ist aktiv — ich kann andere Apps bedienen.'
                  : 'Bedienungshilfe ist NICHT aktiv. Der Nutzer muss sie einmalig aktivieren: Aktion "enable" oeffnet die Einstellung, dort "AI-Buddy" antippen und einschalten.',
              enabled ? '♿ Bedienungshilfe aktiv' : '♿ Bedienungshilfe aus');

        case 'enable':
          await _channel.invokeMethod('openSettings');
          return _ok(parameters,
              'Einstellung fuer Bedienungshilfen geoeffnet. Bitte "AI-Buddy" antippen und aktivieren, dann zurueckkehren.',
              '♿ Aktivierung geoeffnet');

        case 'read_screen':
          return await _readScreen(parameters);

        case 'tap':
          final text = (parameters['text'] as String?)?.trim() ?? '';
          if (text.isEmpty) {
            return _err(parameters, 'Fuer tap wird "text" (Ziel-Beschriftung) benoetigt.');
          }
          final ok = await _channel.invokeMethod('tapText', {'text': text}) as bool? ?? false;
          return ok
              ? _ok(parameters, 'Angetippt: "$text".', '👆 $text')
              : _err(parameters,
                  'Element "$text" nicht gefunden/antippbar. Rufe zuerst read_screen auf und nutze exakt eine dort sichtbare Beschriftung.');

        case 'tap_at':
          final x = (parameters['x'] as num?)?.toInt() ?? 0;
          final y = (parameters['y'] as num?)?.toInt() ?? 0;
          final ok = await _channel.invokeMethod('tapAt', {'x': x, 'y': y}) as bool? ?? false;
          return ok
              ? _ok(parameters, 'Getippt bei ($x, $y).', '👆 ($x, $y)')
              : _err(parameters, 'Tippen bei ($x, $y) fehlgeschlagen.');

        case 'input_text':
          final text = (parameters['text'] as String?) ?? '';
          if (text.isEmpty) {
            return _err(parameters, 'Fuer input_text wird "text" benoetigt.');
          }
          final ok = await _channel.invokeMethod('inputText', {'text': text}) as bool? ?? false;
          return ok
              ? _ok(parameters, 'Text eingegeben: "$text".', '⌨️ Text eingegeben')
              : _err(parameters,
                  'Kein Eingabefeld gefunden. Tippe zuerst ein Textfeld an (tap) und versuche es erneut.');

        case 'scroll':
          final direction = (parameters['direction'] as String?)?.trim() ?? 'down';
          final forward = direction != 'up';
          final ok = await _channel.invokeMethod('scroll', {'forward': forward}) as bool? ?? false;
          return ok
              ? _ok(parameters, 'Gescrollt ($direction).', '📜 $direction')
              : _err(parameters, 'Nichts Scrollbares auf dem Bildschirm.');

        case 'back':
        case 'home':
        case 'recents':
        case 'notifications':
          final ok = await _channel.invokeMethod('globalAction', {'action': action}) as bool? ?? false;
          return ok
              ? _ok(parameters, 'Aktion "$action" ausgefuehrt.', '↩️ $action')
              : _err(parameters, 'Aktion "$action" fehlgeschlagen.');

        default:
          return _err(parameters, 'Unbekannte Aktion: $action');
      }
    } on PlatformException catch (e) {
      if (e.code == 'NOT_ENABLED') {
        return _err(parameters,
            'Bedienungshilfe ist nicht aktiv. Rufe control_screen mit action "enable" auf, damit der Nutzer sie einschalten kann.');
      }
      return _err(parameters, 'Fehler: ${e.message}');
    } catch (e) {
      return _err(parameters, 'Fehler: $e');
    }
  }

  Future<ToolResult> _readScreen(Map<String, dynamic> parameters) async {
    final raw = await _channel.invokeMethod('readScreen');
    final nodes = (raw as List<dynamic>?)
            ?.map((e) => (e as Map).map((k, v) => MapEntry(k.toString(), v)))
            .toList() ??
        [];
    String pkg = '';
    try {
      pkg = await _channel.invokeMethod('currentPackage') as String? ?? '';
    } catch (_) {}

    if (nodes.isEmpty) {
      return _ok(parameters,
          'Bildschirm enthaelt keine lesbaren Elemente${pkg.isNotEmpty ? ' (App: $pkg)' : ''}.',
          '👁️ Bildschirm leer');
    }

    final buffer = StringBuffer();
    if (pkg.isNotEmpty) buffer.writeln('Aktive App: $pkg');
    buffer.writeln('Sichtbare Elemente (${nodes.length}):');
    for (final n in nodes.take(80)) {
      final text = n['text']?.toString() ?? '';
      final flags = <String>[];
      if (n['clickable'] == true) flags.add('klickbar');
      if (n['editable'] == true) flags.add('eingebbar');
      if (n['scrollable'] == true) flags.add('scrollbar');
      final tag = flags.isEmpty ? '' : ' [${flags.join(', ')}]';
      buffer.writeln('- "$text"$tag @(${n['x']},${n['y']})');
    }
    if (nodes.length > 80) {
      buffer.writeln('... und ${nodes.length - 80} weitere.');
    }
    return _ok(parameters, buffer.toString(), '👁️ ${nodes.length} Elemente gelesen');
  }

  ToolResult _ok(Map<String, dynamic> p, String result, String display) =>
      ToolResult(toolName: definition.name, parameters: p, result: result, displayText: display);

  ToolResult _err(Map<String, dynamic> p, String result) => ToolResult(
      toolName: definition.name, parameters: p, result: result, isError: true, displayText: '❌ $result');
}
