import 'dart:io';
import 'tool_interface.dart';
import 'tool_definition.dart';
import 'tool_result.dart';
import 'sandbox_path.dart';

class WriteFileTool implements ToolInterface {
  final String? Function()? getRootPath;
  WriteFileTool({this.getRootPath});

  static const _definition = ToolDefinition(
    name: 'write_file',
    description: 'Erstellt/ueberschreibt eine Textdatei.',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'path': {'type': 'string', 'description': 'Relativer Pfad'},
        'content': {'type': 'string', 'description': 'Inhalt'},
      },
      'required': ['path', 'content'],
    },
  );

  @override
  ToolDefinition get definition => _definition;

  @override
  Future<ToolResult> execute(Map<String, dynamic> parameters) async {
    try {
      final root = getRootPath?.call() ?? '/storage/emulated/0';
      final subPath = parameters['path'] as String? ?? '';
      final content = parameters['content'] as String? ?? '';
      final fullPath = resolveSandboxPath(root, subPath);
      if (fullPath == null) {
        return ToolResult(toolName: definition.name, parameters: parameters, result: 'Ungültiger Pfad: $subPath', isError: true, displayText: 'Ungültiger Pfad');
      }
      final file = File(fullPath);
      await file.parent.create(recursive: true);
      await file.writeAsString(content);
      return ToolResult(toolName: definition.name, parameters: parameters, result: 'Gespeichert: $subPath', displayText: 'Gespeichert: $subPath');
    } catch (e) {
      return ToolResult(toolName: definition.name, parameters: parameters, result: 'Fehler: $e', isError: true, displayText: 'Schreibfehler');
    }
  }
}
