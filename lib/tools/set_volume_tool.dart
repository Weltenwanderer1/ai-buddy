import 'tool_interface.dart';
import 'tool_definition.dart';
import 'tool_result.dart';

/// Controls device volume for different audio streams.
class SetVolumeTool implements ToolInterface {
  static const _definition = ToolDefinition(
    name: 'set_volume',
    description:
        'Stellt die Lautstärke des Geräts ein. '
        'Verschiedene Streams können getrennt gesteuert werden: '
        '"media" (Musik/Video), "alarm" (Wecker), "notification" (Benachrichtigungen), '
        '"system" (Systemtöne), "ring" (Klingelton).',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'stream': {
          'type': 'string',
          'description': 'Audio-Stream: "media", "alarm", "notification", "system", "ring"',
          'enum': ['media', 'alarm', 'notification', 'system', 'ring'],
        },
        'level': {
          'type': 'integer',
          'description':
              'Lautstärke-Level (0-100). 0 = stumm, 100 = maximum.',
        },
        'action': {
          'type': 'string',
          'description':
              'Aktion: "set" (Lautstärke setzen), "get" (aktuelle Lautstärke abfragen), '
              '"mute" (stumm schalten), "unmute" (Stummschaltung aufheben)',
          'enum': ['set', 'get', 'mute', 'unmute'],
        },
      },
      'required': ['stream'],
    },
  );

  @override
  ToolDefinition get definition => _definition;

  /// Callback to set volume (0.0 - 1.0).
  static Future<bool> Function({
    required String stream,
    required double level,
  })? setVolumeCallback;

  /// Callback to get current volume (0.0 - 1.0).
  static Future<double?> Function({required String stream})? getVolumeCallback;

  /// Callback to mute/unmute.
  static Future<bool> Function({required bool mute})? muteCallback;

  @override
  Future<ToolResult> execute(Map<String, dynamic> parameters) async {
    final stream = (parameters['stream'] as String?) ?? 'media';
    final action = (parameters['action'] as String?) ?? 'set';
    final levelRaw = parameters['level'];

    switch (action) {
      case 'set':
        return _setVolume(stream, levelRaw);
      case 'get':
        return _getVolume(stream);
      case 'mute':
        return _mute(true);
      case 'unmute':
        return _mute(false);
      default:
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: 'Unbekannte Aktion: $action',
          isError: true,
        );
    }
  }

  Future<ToolResult> _setVolume(String stream, dynamic levelRaw) async {
    final level = _readInt(levelRaw);
    if (level == null || level < 0 || level > 100) {
      return ToolResult(
        toolName: definition.name,
        parameters: {'stream': stream, 'level': levelRaw},
        result: 'Fehler: Level muss zwischen 0 und 100 sein.',
        isError: true,
        displayText: '❌ Ungültiges Level',
      );
    }

    if (setVolumeCallback == null) {
      return ToolResult(
        toolName: definition.name,
        parameters: {'stream': stream, 'level': level},
        result: 'Fehler: Lautstärke-Service nicht verfügbar.',
        isError: true,
        displayText: '❌ Service nicht verfügbar',
      );
    }

    try {
      final success = await setVolumeCallback!(
        stream: stream,
        level: level / 100.0,
      );
      if (success) {
        return ToolResult(
          toolName: definition.name,
          parameters: {'stream': stream, 'level': level},
          result: 'Lautstärke ($stream) auf $level% gesetzt.',
          displayText: '🔊 $stream: $level%',
        );
      } else {
        return ToolResult(
          toolName: definition.name,
          parameters: {'stream': stream, 'level': level},
          result: 'Fehler: Lautstärke konnte nicht gesetzt werden.',
          isError: true,
          displayText: '❌ Lautstärke-Fehler',
        );
      }
    } catch (e) {
      return ToolResult(
        toolName: definition.name,
        parameters: {'stream': stream, 'level': level},
        result: 'Fehler: $e',
        isError: true,
        displayText: '❌ Fehler',
      );
    }
  }

  Future<ToolResult> _getVolume(String stream) async {
    if (getVolumeCallback == null) {
      return ToolResult(
        toolName: definition.name,
        parameters: {'stream': stream},
        result: 'Fehler: Lautstärke-Service nicht verfügbar.',
        isError: true,
        displayText: '❌ Service nicht verfügbar',
      );
    }

    try {
      final volume = await getVolumeCallback!(stream: stream);
      if (volume != null) {
        final percent = (volume * 100).round();
        return ToolResult(
          toolName: definition.name,
          parameters: {'stream': stream},
          result: 'Aktuelle Lautstärke ($stream): $percent%',
          displayText: '🔊 $stream: $percent%',
        );
      } else {
        return ToolResult(
          toolName: definition.name,
          parameters: {'stream': stream},
          result: 'Lautstärke konnte nicht abgefragt werden.',
          isError: true,
          displayText: '❌ Abfrage fehlgeschlagen',
        );
      }
    } catch (e) {
      return ToolResult(
        toolName: definition.name,
        parameters: {'stream': stream},
        result: 'Fehler: $e',
        isError: true,
        displayText: '❌ Fehler',
      );
    }
  }

  Future<ToolResult> _mute(bool mute) async {
    if (muteCallback == null) {
      return ToolResult(
        toolName: definition.name,
        parameters: {'mute': mute},
        result: 'Fehler: Lautstärke-Service nicht verfügbar.',
        isError: true,
        displayText: '❌ Service nicht verfügbar',
      );
    }

    try {
      final success = await muteCallback!(mute: mute);
      if (success) {
        return ToolResult(
          toolName: definition.name,
          parameters: {'mute': mute},
          result: mute ? 'Gerät stummgeschaltet.' : 'Stummschaltung aufgehoben.',
          displayText: mute ? '🔇 Stumm' : '🔊 Ton an',
        );
      } else {
        return ToolResult(
          toolName: definition.name,
          parameters: {'mute': mute},
          result: 'Fehler: Stummschaltung fehlgeschlagen.',
          isError: true,
          displayText: '❌ Fehler',
        );
      }
    } catch (e) {
      return ToolResult(
        toolName: definition.name,
        parameters: {'mute': mute},
        result: 'Fehler: $e',
        isError: true,
        displayText: '❌ Fehler',
      );
    }
  }

  static int? _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }
}
