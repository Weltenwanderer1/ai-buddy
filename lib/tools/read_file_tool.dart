import 'dart:io';
import 'tool_interface.dart';
import 'tool_definition.dart';
import 'tool_result.dart';
import 'sandbox_path.dart';

class ReadFileTool implements ToolInterface {
  final String? Function()? getRootPath;
  ReadFileTool({this.getRootPath});

  static const _definition = ToolDefinition(
    name: 'read_file',
    description:
        'Liest den Inhalt einer Textdatei (max 5000 Zeichen). '
        'Pfad relativ zum Buddy-Ordner ODER absolut (z.B. /storage/emulated/0/Download/notiz.txt) '
        'wenn Dateizugriff erlaubt ist.',
    parametersSchema: {
      'type': 'object',
      'properties': {'path': {'type': 'string', 'description': 'Relativer oder absoluter Pfad zur Datei'}},
      'required': ['path'],
    },
  );

  @override
  ToolDefinition get definition => _definition;

  @override
  Future<ToolResult> execute(Map<String, dynamic> parameters) async {
    try {
      final root = getRootPath?.call() ?? '/storage/emulated/0';
      final subPath = parameters['path'] as String? ?? '';
      final fullPath = resolveFsPath(root, subPath);
      if (fullPath == null) {
        return ToolResult(toolName: definition.name, parameters: parameters, result: 'Ungültiger Pfad: $subPath', isError: true, displayText: 'Ungültiger Pfad');
      }
      final file = File(fullPath);
      if (!await file.exists()) {
        return ToolResult(toolName: definition.name, parameters: parameters, result: 'Nicht gefunden: $subPath', isError: true, displayText: 'Datei nicht gefunden');
      }
      final content = await file.readAsString();
      final truncated = content.length > 5000 ? '${content.substring(0, 5000)}\n... (${content.length} Zeichen)' : content;
      return ToolResult(toolName: definition.name, parameters: parameters, result: '$subPath (${content.length} Zeichen):\n$truncated', displayText: 'Gelesen: $subPath');
    } catch (e) {
      return ToolResult(toolName: definition.name, parameters: parameters, result: 'Fehler: $e', isError: true, displayText: 'Lesefehler');
    }
  }
}
