import 'dart:io';
import 'tool_interface.dart';
import 'tool_definition.dart';
import 'tool_result.dart';
import 'sandbox_path.dart';

/// Renames or moves a file or directory.
class RenameFileTool implements ToolInterface {
  final String? Function()? getRootPath;
  RenameFileTool({this.getRootPath});

  static const _definition = ToolDefinition(
    name: 'rename_file',
    description: 'Benennt eine Datei oder einen Ordner um oder verschiebt sie.',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'path': {
          'type': 'string',
          'description': 'Aktueller relativer Pfad',
        },
        'new_name': {
          'type': 'string',
          'description':
              'Neuer Name (nur Dateiname) oder neuer relativer Pfad zum Verschieben',
        },
      },
      'required': ['path', 'new_name'],
    },
  );

  @override
  ToolDefinition get definition => _definition;

  @override
  Future<ToolResult> execute(Map<String, dynamic> parameters) async {
    final subPath = (parameters['path'] as String?)?.trim() ?? '';
    final newName = (parameters['new_name'] as String?)?.trim() ?? '';

    if (subPath.isEmpty || newName.isEmpty) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Fehler: Pfad und neuer Name sind erforderlich.',
        isError: true,
        displayText: '❌ Parameter fehlen',
      );
    }

    try {
      final root = getRootPath?.call() ?? '/storage/emulated/0';
      final oldPath = resolveFsPath(root, subPath);

      // Determine new path: if newName contains /, treat as full relative path
      String? newPath;
      if (newName.contains('/')) {
        newPath = resolveFsPath(root, newName);
      } else if (oldPath != null && newName != '..') {
        final parent = File(oldPath).parent.path;
        newPath = '$parent/$newName';
      }
      if (oldPath == null || newPath == null) {
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: 'Ungültiger Pfad: $subPath → $newName',
          isError: true,
          displayText: '❌ Ungültiger Pfad',
        );
      }

      final file = File(oldPath);
      final dir = Directory(oldPath);

      if (await file.exists()) {
        await file.rename(newPath);
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: 'Umbenannt: $subPath → $newName',
          displayText: '✏️ Umbenannt: $newName',
        );
      } else if (await dir.exists()) {
        await dir.rename(newPath);
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: 'Ordner umbenannt: $subPath → $newName',
          displayText: '✏️ Ordner umbenannt: $newName',
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
        result: 'Fehler beim Umbenennen: $e',
        isError: true,
        displayText: '❌ Umbenenn-Fehler',
      );
    }
  }
}
