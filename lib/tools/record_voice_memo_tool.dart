import 'tool_interface.dart';
import 'tool_definition.dart';
import 'tool_result.dart';

/// Tool for recording voice memos/dictations.
class RecordVoiceMemoTool implements ToolInterface {
  static const _definition = ToolDefinition(
    name: 'record_voice_memo',
    description:
        'Sprachmemo/Diktat aufnehmen, stoppen oder auflisten. '
        'Aktionen: "start" (Aufnahme starten), "stop" (Aufnahme stoppen), '
        '"list" (gespeicherte Memos auflisten), "delete" (Memo löschen).',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'action': {
          'type': 'string',
          'description': 'Aktion: "start", "stop", "list", "delete"',
          'enum': ['start', 'stop', 'list', 'delete'],
        },
        'file_path': {
          'type': 'string',
          'description': 'Pfad zum Löschen (nur bei action="delete")',
        },
      },
      'required': ['action'],
    },
  );

  @override
  ToolDefinition get definition => _definition;

  /// Callback to start recording. Returns file path or null.
  static Future<String?> Function()? startRecordingCallback;

  /// Callback to stop recording. Returns file path or null.
  static Future<String?> Function()? stopRecordingCallback;

  /// Callback to list memos. Returns list of {path, name, sizeBytes}.
  static Future<List<Map<String, dynamic>>> Function()? listMemosCallback;

  /// Callback to delete a memo. Returns true on success.
  static Future<bool> Function({required String path})? deleteMemoCallback;

  @override
  Future<ToolResult> execute(Map<String, dynamic> parameters) async {
    final action = (parameters['action'] as String?) ?? 'list';

    switch (action) {
      case 'start':
        return _startRecording();
      case 'stop':
        return _stopRecording();
      case 'list':
        return _listMemos();
      case 'delete':
        return _deleteMemo(parameters);
      default:
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: 'Unbekannte Aktion: $action',
          isError: true,
        );
    }
  }

  Future<ToolResult> _startRecording() async {
    if (startRecordingCallback == null) {
      return ToolResult(
        toolName: definition.name,
        parameters: {'action': 'start'},
        result: 'Fehler: Aufnahmeservice nicht verfügbar.',
        isError: true,
        displayText: '❌ Aufnahme nicht verfügbar',
      );
    }

    try {
      final path = await startRecordingCallback!();
      if (path != null) {
        return ToolResult(
          toolName: definition.name,
          parameters: {'action': 'start'},
          result: 'Aufnahme gestartet. Sprich jetzt...',
          displayText: '🎙️ Aufnahme läuft',
        );
      } else {
        return ToolResult(
          toolName: definition.name,
          parameters: {'action': 'start'},
          result: 'Fehler: Aufnahme konnte nicht gestartet werden.',
          isError: true,
          displayText: '❌ Aufnahme-Fehler',
        );
      }
    } catch (e) {
      return ToolResult(
        toolName: definition.name,
        parameters: {'action': 'start'},
        result: 'Fehler: $e',
        isError: true,
        displayText: '❌ Fehler',
      );
    }
  }

  Future<ToolResult> _stopRecording() async {
    if (stopRecordingCallback == null) {
      return ToolResult(
        toolName: definition.name,
        parameters: {'action': 'stop'},
        result: 'Fehler: Aufnahmeservice nicht verfügbar.',
        isError: true,
        displayText: '❌ Service nicht verfügbar',
      );
    }

    try {
      final path = await stopRecordingCallback!();
      if (path != null) {
        return ToolResult(
          toolName: definition.name,
          parameters: {'action': 'stop'},
          result: 'Aufnahme gespeichert: $path',
          displayText: '🎙️ Aufnahme gespeichert',
        );
      } else {
        return ToolResult(
          toolName: definition.name,
          parameters: {'action': 'stop'},
          result: 'Keine aktive Aufnahme zum Stoppen.',
          isError: true,
          displayText: '❌ Keine Aufnahme',
        );
      }
    } catch (e) {
      return ToolResult(
        toolName: definition.name,
        parameters: {'action': 'stop'},
        result: 'Fehler: $e',
        isError: true,
        displayText: '❌ Fehler',
      );
    }
  }

  Future<ToolResult> _listMemos() async {
    if (listMemosCallback == null) {
      return ToolResult(
        toolName: definition.name,
        parameters: {'action': 'list'},
        result: 'Fehler: Aufnahmeservice nicht verfügbar.',
        isError: true,
        displayText: '❌ Service nicht verfügbar',
      );
    }

    try {
      final memos = await listMemosCallback!();
      if (memos.isEmpty) {
        return ToolResult(
          toolName: definition.name,
          parameters: {'action': 'list'},
          result: 'Keine Sprachmemos vorhanden.',
          displayText: '🎙️ Keine Memos',
        );
      }

      final buffer = StringBuffer('Sprachmemos:\n');
      for (final memo in memos) {
        final name = memo['name'] as String? ?? 'Unbekannt';
        final sizeKB = ((memo['sizeBytes'] as int? ?? 0) / 1024).round();
        buffer.writeln('- $name (${sizeKB}KB)');
      }
      return ToolResult(
        toolName: definition.name,
        parameters: {'action': 'list'},
        result: buffer.toString(),
        displayText: '🎙️ ${memos.length} Memo(s)',
      );
    } catch (e) {
      return ToolResult(
        toolName: definition.name,
        parameters: {'action': 'list'},
        result: 'Fehler: $e',
        isError: true,
        displayText: '❌ Fehler',
      );
    }
  }

  Future<ToolResult> _deleteMemo(Map<String, dynamic> parameters) async {
    final path = (parameters['file_path'] as String?)?.trim() ?? '';
    if (path.isEmpty) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Fehler: file_path zum Löschen erforderlich.',
        isError: true,
        displayText: '❌ Kein Pfad',
      );
    }

    if (deleteMemoCallback == null) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Fehler: Aufnahmeservice nicht verfügbar.',
        isError: true,
        displayText: '❌ Service nicht verfügbar',
      );
    }

    try {
      final success = await deleteMemoCallback!(path: path);
      if (success) {
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: 'Memo gelöscht: $path',
          displayText: '🗑️ Memo gelöscht',
        );
      } else {
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: 'Memo nicht gefunden: $path',
          isError: true,
          displayText: '❌ Nicht gefunden',
        );
      }
    } catch (e) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Fehler: $e',
        isError: true,
        displayText: '❌ Fehler',
      );
    }
  }
}
