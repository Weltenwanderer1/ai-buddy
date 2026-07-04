import 'dart:io';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'tool_interface.dart';
import 'tool_definition.dart';
import 'tool_result.dart';

/// Open any file (PDF, Office, Image, etc.) using an external app.
/// Uses file_picker for browsing + FileProvider for secure URI sharing.
class OpenFileTool implements ToolInterface {
  static const _channel = MethodChannel('com.aibuddy.app/files');

  static const _definition = ToolDefinition(
    name: 'open_file',
    description:
        'Oeffnet eine Datei im passenden externen Programm. '
        'Unterstuetzt PDF, Word, Excel, PowerPoint, Bilder, Videos, Audio und mehr. '
        'Wenn kein Pfad angegeben, wird ein Dateiauswahldialog geoeffnet.',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'filePath': {
          'type': 'string',
          'description': 'Optional: voller Pfad zur Datei. Wenn leer, wird der Datei-Auswahl-Dialog gezeigt.',
        },
        'mimeHint': {
          'type': 'string',
          'description': 'MIME-Typ als Hinweis z.B. "application/pdf", "image/*", "application/*". Bei leer automatisch erkennt.',
        },
      },
    },
  );

  @override
  ToolDefinition get definition => _definition;

  @override
  Future<ToolResult> execute(Map<String, dynamic> parameters) async {
    String filePath = parameters['filePath'] as String? ?? '';
    String mimeHint = parameters['mimeHint'] as String? ?? '';

    // If no path given, open file picker
    if (filePath.isEmpty) {
      try {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: [
            'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx',
            'txt', 'csv', 'md', 'html', 'htm',
            'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'svg',
            'mp4', 'avi', 'mkv', 'mov',
            'mp3', 'wav', 'ogg', 'flac', 'aac',
          ],
          allowCompression: false,
        );
        if (result == null || result.files.isEmpty) {
          return ToolResult(
            toolName: definition.name,
            parameters: parameters,
            result: 'Keine Datei ausgewaehlt.',
            displayText: '📂 Keine Datei ausgewaehlt',
          );
        }
        filePath = result.files.first.path ?? '';
        mimeHint = _detectMime(filePath);
      } catch (e) {
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: 'Fehler beim Dateiauswahl-Dialog: $e',
          isError: true,
          displayText: '❌ Dateiauswahl-Fehler',
        );
      }
    }

    if (filePath.isEmpty) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Kein gueltiger Dateipfad.',
        isError: true,
      );
    }

    final file = File(filePath);
    if (!await file.exists()) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Datei existiert nicht: $filePath',
        isError: true,
        displayText: '❌ Datei nicht gefunden',
      );
    }

    // Deduplicate for Android — copy to app-specific cache dir for FileProvider
    if (Platform.isAndroid) {
      final mime = mimeHint.isNotEmpty ? mimeHint : _detectMime(filePath);
      try {
        final ok = await _channel.invokeMethod('openFileWithMime', {
          'filePath': filePath,
          'mimeType': mime,
        });
        if (ok == true) {
          final fileName = filePath.split('/').last;
          return ToolResult(
            toolName: definition.name,
            parameters: parameters,
            result: '"$fileName" geoeffnet.',
            displayText: '📄 $fileName geoeffnet',
          );
        } else {
          return ToolResult(
            toolName: definition.name,
            parameters: parameters,
            result: 'Keine App gefunden um diese Datei zu oeffnen. Installiere z.B. einen PDF-Reader fuer PDFs.',
            isError: true,
            displayText: '❌ Keine App gefunden',
          );
        }
      } on PlatformException catch (e) {
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: 'Fehler: ${e.message}',
          isError: true,
        );
      }
    }

    return ToolResult(
      toolName: definition.name,
      parameters: parameters,
      result: 'Oeffnen von Dateien ist nur auf Android unterstuetzt.',
      isError: true,
      displayText: '❌ Nur auf Android',
    );
  }

  String _detectMime(String path) {
    final ext = path.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'txt':
        return 'text/plain';
      case 'csv':
        return 'text/csv';
      case 'md':
        return 'text/markdown';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'svg':
        return 'image/svg+xml';
      case 'mp4':
        return 'video/mp4';
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      default:
        return '*/*';
    }
  }
}
