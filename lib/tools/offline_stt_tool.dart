import 'tool_interface.dart';
import 'tool_definition.dart';
import 'tool_result.dart';

/// Tool for offline speech recognition.
class OfflineSttTool implements ToolInterface {
  static const _definition = ToolDefinition(
    name: 'offline_speech_recognition',
    description:
        'Spracheingabe mit Offline-Unterstützung. '
        'Kann offline arbeiten wenn Sprachpakete heruntergeladen sind. '
        'Aktionen: "listen" (Sprache aufnehmen und erkennen), '
        '"check" (verfügbare Offline-Sprachen prüfen), '
        '"download" (Offline-Sprachpakete herunterladen).',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'action': {
          'type': 'string',
          'description': 'Aktion: "listen", "check", "download"',
          'enum': ['listen', 'check', 'download'],
        },
        'language': {
          'type': 'string',
          'description':
              'Sprachcode (z.B. "de_DE", "en_US"). Standard: de_DE',
        },
        'prefer_offline': {
          'type': 'boolean',
          'description': 'Offline bevorzugen (Standard: true)',
        },
      },
      'required': ['action'],
    },
  );

  @override
  ToolDefinition get definition => _definition;

  /// Callback to check offline availability.
  static Future<bool> Function()? checkOfflineCallback;

  /// Callback to start listening.
  static Future<String?> Function({
    bool preferOffline,
    String localeId,
  })? listenCallback;

  /// Callback to stop listening.
  static Future<void> Function()? stopListeningCallback;

  /// Callback to prompt offline language download.
  static Future<void> Function()? promptDownloadCallback;

  @override
  Future<ToolResult> execute(Map<String, dynamic> parameters) async {
    final action = (parameters['action'] as String?) ?? 'listen';

    switch (action) {
      case 'listen':
        return _listen(parameters);
      case 'check':
        return _checkOffline();
      case 'download':
        return _downloadLanguage();
      default:
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: 'Unbekannte Aktion: $action',
          isError: true,
        );
    }
  }

  Future<ToolResult> _listen(Map<String, dynamic> parameters) async {
    final language = (parameters['language'] as String?) ?? 'de_DE';
    final preferOffline = parameters['prefer_offline'] as bool? ?? true;

    if (listenCallback == null) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Fehler: Spracherkennung nicht verfügbar.',
        isError: true,
        displayText: '❌ STT nicht verfügbar',
      );
    }

    try {
      final text = await listenCallback!(
        preferOffline: preferOffline,
        localeId: language,
      );

      if (text != null && text.isNotEmpty) {
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: 'Erkannt: "$text"',
          displayText: '🎤 "$text"',
        );
      } else {
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: 'Keine Sprache erkannt. Bitte versuche es erneut.',
          isError: true,
          displayText: '❌ Nichts erkannt',
        );
      }
    } catch (e) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Fehler bei der Spracherkennung: $e',
        isError: true,
        displayText: '❌ STT-Fehler',
      );
    }
  }

  Future<ToolResult> _checkOffline() async {
    if (checkOfflineCallback == null) {
      return ToolResult(
        toolName: definition.name,
        parameters: {'action': 'check'},
        result: 'Fehler: Spracherkennung nicht verfügbar.',
        isError: true,
        displayText: '❌ STT nicht verfügbar',
      );
    }

    try {
      final available = await checkOfflineCallback!();
      if (available) {
        return ToolResult(
          toolName: definition.name,
          parameters: {'action': 'check'},
          result: 'Offline-Spracherkennung ist verfügbar.',
          displayText: '✅ Offline STT verfügbar',
        );
      } else {
        return ToolResult(
          toolName: definition.name,
          parameters: {'action': 'check'},
          result:
              'Offline-Spracherkennung nicht verfügbar. '
              'Bitte lade Offline-Sprachpakete in den Android-Einstellungen herunter.',
          displayText: '⚠️ Offline STT nicht verfügbar',
        );
      }
    } catch (e) {
      return ToolResult(
        toolName: definition.name,
        parameters: {'action': 'check'},
        result: 'Fehler: $e',
        isError: true,
        displayText: '❌ Fehler',
      );
    }
  }

  Future<ToolResult> _downloadLanguage() async {
    if (promptDownloadCallback == null) {
      return ToolResult(
        toolName: definition.name,
        parameters: {'action': 'download'},
        result: 'Fehler: Spracherkennung nicht verfügbar.',
        isError: true,
        displayText: '❌ STT nicht verfügbar',
      );
    }

    try {
      await promptDownloadCallback!();
      return ToolResult(
        toolName: definition.name,
        parameters: {'action': 'download'},
        result:
            'Offline-Sprachpaket-Einstellungen geöffnen. '
            'Bitte lade die gewünschte Sprache herunter.',
        displayText: '📥 Sprachpaket-Einstellungen',
      );
    } catch (e) {
      return ToolResult(
        toolName: definition.name,
        parameters: {'action': 'download'},
        result: 'Fehler: $e',
        isError: true,
        displayText: '❌ Fehler',
      );
    }
  }
}
