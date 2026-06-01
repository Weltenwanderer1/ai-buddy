import 'tool_interface.dart';
import 'tool_definition.dart';
import 'tool_result.dart';

/// Clipboard tool — reads current content or shows history.
class GetClipboardTool implements ToolInterface {
  static Future<String?> Function()? readClipboardCallback;
  static String Function({int limit})? getHistoryCallback;

  static const _definition = ToolDefinition(
    name: 'get_clipboard',
    description: 'Zeigt den aktuellen Inhalt der Zwischenablage oder den Verlauf (letzte 30 Eintraege).',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'action': {
          'type': 'string',
          'enum': ['current', 'history', 'clear'],
          'description': 'current=aktueller Inhalt, history=Verlauf, clear=Verlauf loeschen',
        },
        'limit': {
          'type': 'integer',
          'description': 'Max Anzahl Eintraege fuer history (Standard: 10)',
        },
      },
    },
  );

  @override
  ToolDefinition get definition => _definition;

  @override
  Future<ToolResult> execute(Map<String, dynamic> parameters) async {
    final action = parameters['action'] as String? ?? 'current';
    final limit = parameters['limit'] as int? ?? 10;

    switch (action) {
      case 'current':
        return _getCurrent(parameters);
      case 'history':
        return _getHistory(parameters, limit);
      case 'clear':
        return _clearHistory(parameters);
      default:
        return _getCurrent(parameters);
    }
  }

  Future<ToolResult> _getCurrent(Map<String, dynamic> parameters) async {
    try {
      if (readClipboardCallback == null) {
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: 'Nicht verfuegbar',
          isError: true,
          displayText: 'Zwischenablage nicht verfuegbar',
        );
      }
      final text = await readClipboardCallback!();
      if (text == null || text.isEmpty) {
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: 'Leer',
          displayText: '📋 Zwischenablage leer',
        );
      }
      final truncated = text.length > 2000 ? '${text.substring(0, 2000)}...' : text;
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Aktuell: $truncated',
        displayText: '📋 ${text.length} Zeichen',
      );
    } catch (e) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Fehler: $e',
        isError: true,
        displayText: 'Fehler',
      );
    }
  }

  ToolResult _getHistory(Map<String, dynamic> parameters, int limit) {
    if (getHistoryCallback == null) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Verlauf nicht verfuegbar',
        isError: true,
      );
    }

    final history = getHistoryCallback!(limit: limit);
    return ToolResult(
      toolName: definition.name,
      parameters: parameters,
      result: history,
      displayText: '📋 Zwischenablage-Verlauf',
    );
  }

  ToolResult _clearHistory(Map<String, dynamic> parameters) {
    // Not implemented — service handles clearing externally
    return ToolResult(
      toolName: definition.name,
      parameters: parameters,
      result: 'Verlauf kann nicht via Tool geloescht werden.',
      isError: true,
      displayText: 'Löschen nicht verfuegbar',
    );
  }
}
