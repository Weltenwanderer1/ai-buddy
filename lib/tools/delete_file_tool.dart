import 'dart:io';
import 'tool_interface.dart';
import 'tool_definition.dart';
import 'tool_result.dart';
import 'sandbox_path.dart';

/// Deletes a file or empty directory.
class DeleteFileTool implements ToolInterface {
  final String? Function()? getRootPath;
  DeleteFileTool({this.getRootPath});

  static const _definition = ToolDefinition(
    name: 'delete_file',
    description: 'Löscht eine Datei oder leeren Ordner.',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'path': {
          'type': 'string',
          'description': 'Relativer Pfad zur Datei/dem Ordner',
        },
      },
      'required': ['path'],
    },
  );

  @override
  ToolDefinition get definition => _definition;

  @override
  Future<ToolResult> execute(Map<String, dynamic> parameters) async {
    final subPath = (parameters['path'] as String?)?.trim() ?? '';
    if (subPath.isEmpty) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Fehler: Kein Pfad angegeben.',
        isError: true,
        displayText: '❌ Kein Pfad',
      );
    }

    try {
      final root = getRootPath?.call() ?? '/storage/emulated/0';
      final fullPath = resolveFsPath(root, subPath);
      if (fullPath == null) {
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: 'Ungültiger Pfad: $subPath',
          isError: true,
          displayText: '❌ Ungültiger Pfad',
        );
      }
      final file = File(fullPath);
      final dir = Directory(fullPath);

      if (await file.exists()) {
        await file.delete();
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: 'Datei gelöscht: $subPath',
          displayText: '🗑️ Gelöscht: $subPath',
        );
      } else if (await dir.exists()) {
        final contents = await dir.list().toList();
        if (contents.isNotEmpty) {
          return ToolResult(
            toolName: definition.name,
            parameters: parameters,
            result:
                'Fehler: Ordner ist nicht leer (${contents.length} Einträge). Nur leere Ordner können gelöscht werden.',
            isError: true,
            displayText: '❌ Ordner nicht leer',
          );
        }
        await dir.delete();
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: 'Ordner gelöscht: $subPath',
          displayText: '🗑️ Ordner gelöscht: $subPath',
        );
      } else {
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: 'Nicht gefunden: $subPath',
          isError: true,
          displayText: '❌ Nicht gefunden',
        );
      }
    } catch (e) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Fehler beim Löschen: $e',
        isError: true,
        displayText: '❌ Löschfehler',
      );
    }
  }
}
