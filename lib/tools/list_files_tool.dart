import 'dart:io';
import 'tool_interface.dart';
import 'tool_definition.dart';
import 'tool_result.dart';

class ListFilesTool implements ToolInterface {
  final String? Function()? getRootPath;
  ListFilesTool({this.getRootPath});

  static const _definition = ToolDefinition(
    name: 'list_files',
    description: 'Listet Dateien und Ordner im angegebenen Pfad auf.',
    parametersSchema: {
      'type': 'object',
      'properties': {'path': {'type': 'string', 'description': 'Pfad (leer = Stammverzeichnis)'}},
      'required': [],
    },
  );

  @override
  ToolDefinition get definition => _definition;

  @override
  Future<ToolResult> execute(Map<String, dynamic> parameters) async {
    try {
      final root = getRootPath?.call() ?? '/storage/emulated/0';
      final subPath = (parameters['path'] as String?) ?? '';
      final fullPath = subPath.isEmpty ? root : '$root/${subPath.replaceFirst(RegExp(r'^/+'), '')}';
      final dir = Directory(fullPath);
      if (!await dir.exists()) {
        return ToolResult(toolName: definition.name, parameters: parameters, result: 'Pfad nicht gefunden: $fullPath', isError: true, displayText: 'Pfad nicht gefunden');
      }
      final entries = await dir.list().toList();
      final filtered = entries.where((e) => !e.path.contains('/.')).toList();
      filtered.sort((a, b) {
        final aIsDir = a is Directory; final bIsDir = b is Directory;
        if (aIsDir && !bIsDir) return -1; if (!aIsDir && bIsDir) return 1;
        return a.path.compareTo(b.path);
      });
      final lines = filtered.map((e) {
        final name = e.path.split('/').last;
        return '${e is Directory ? '[DIR]' : '[FILE]'} $name';
      }).join('\n');
      final resultText = lines.isEmpty ? '(leer)' : lines;
      return ToolResult(toolName: definition.name, parameters: parameters, result: 'Inhalt: $resultText (${filtered.length} Eintraege)', displayText: '${filtered.length} Eintraege');
    } catch (e) {
      return ToolResult(toolName: definition.name, parameters: parameters, result: 'Fehler: $e', isError: true, displayText: 'Fehler beim Auflisten');
    }
  }
}
