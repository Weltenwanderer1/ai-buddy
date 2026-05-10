import 'tool_interface.dart';
import 'tool_definition.dart';
import 'tool_result.dart';

class GetClipboardTool implements ToolInterface {
  static Future<String?> Function()? readClipboardCallback;

  static const _definition = ToolDefinition(
    name: 'get_clipboard',
    description: 'Liest Text aus der Zwischenablage.',
    parametersSchema: {'type': 'object', 'properties': {}, 'required': []},
  );

  @override
  ToolDefinition get definition => _definition;

  @override
  Future<ToolResult> execute(Map<String, dynamic> parameters) async {
    try {
      if (readClipboardCallback == null) return ToolResult(toolName: definition.name, parameters: parameters, result: 'Nicht verfuegbar', isError: true, displayText: 'Zwischenablage nicht verfuegbar');
      final text = await readClipboardCallback!();
      if (text == null || text.isEmpty) return ToolResult(toolName: definition.name, parameters: parameters, result: 'Leer', displayText: 'Zwischenablage leer');
      final truncated = text.length > 2000 ? '${text.substring(0, 2000)}...' : text;
      return ToolResult(toolName: definition.name, parameters: parameters, result: 'Zwischenablage: $truncated', displayText: 'Zwischenablage: ${text.length} Zeichen');
    } catch (e) {
      return ToolResult(toolName: definition.name, parameters: parameters, result: 'Fehler: $e', isError: true, displayText: 'Fehler');
    }
  }
}
