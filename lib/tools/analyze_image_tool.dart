import 'dart:io';
import 'tool_interface.dart';
import 'tool_definition.dart';
import 'tool_result.dart';
import 'sandbox_path.dart';

/// Takes a photo from camera or picks from gallery, then analyzes it with Vision LLM.
class AnalyzeImageTool implements ToolInterface {
  static const _definition = ToolDefinition(
    name: 'analyze_image',
    description:
        'Nimmt ein Foto auf oder wählt ein Bild aus der Galerie und analysiert es mit KI-Vision. '
        'Kann auch einen Screenshot des aktuellen Bildschirms analysieren.',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'source': {
          'type': 'string',
          'description':
              'Bildquelle: "camera" (Foto aufnehmen), "gallery" (aus Galerie), '
              '"screenshot" (Bildschirmfoto), "file" (Dateipfad angeben)',
          'enum': ['camera', 'gallery', 'screenshot', 'file'],
        },
        'file_path': {
          'type': 'string',
          'description':
              'Relativer Pfad zum Bild (nur bei source="file")',
        },
        'question': {
          'type': 'string',
          'description':
              'Frage oder Anweisung zur Bildanalyse (z.B. "Was ist auf dem Bild?")',
        },
      },
      'required': ['source'],
    },
  );

  @override
  ToolDefinition get definition => _definition;

  /// Callback to pick an image from camera. Returns file path or null.
  static Future<String?> Function()? pickFromCameraCallback;

  /// Callback to pick an image from gallery. Returns file path or null.
  static Future<String?> Function()? pickFromGalleryCallback;

  /// Callback to take a screenshot. Returns file path or null.
  static Future<String?> Function()? takeScreenshotCallback;

  /// Callback to analyze an image with Vision LLM. Returns analysis text.
  static Future<String?> Function({
    required String imagePath,
    String? question,
  })? analyzeCallback;

  final String? Function()? getRootPath;

  AnalyzeImageTool({this.getRootPath});

  @override
  Future<ToolResult> execute(Map<String, dynamic> parameters) async {
    final source = (parameters['source'] as String?) ?? 'gallery';
    final filePath = (parameters['file_path'] as String?)?.trim();
    final question = (parameters['question'] as String?)?.trim() ??
        'Was ist auf diesem Bild zu sehen? Beschreibe es detailliert.';

    String? imagePath;

    try {
      switch (source) {
        case 'camera':
          if (pickFromCameraCallback == null) {
            return ToolResult(
              toolName: definition.name,
              parameters: parameters,
              result: 'Fehler: Kamera-Zugriff nicht verfügbar.',
              isError: true,
              displayText: '❌ Kamera nicht verfügbar',
            );
          }
          imagePath = await pickFromCameraCallback!();
          break;

        case 'gallery':
          if (pickFromGalleryCallback == null) {
            return ToolResult(
              toolName: definition.name,
              parameters: parameters,
              result: 'Fehler: Galerie-Zugriff nicht verfügbar.',
              isError: true,
              displayText: '❌ Galerie nicht verfügbar',
            );
          }
          imagePath = await pickFromGalleryCallback!();
          break;

        case 'screenshot':
          if (takeScreenshotCallback == null) {
            return ToolResult(
              toolName: definition.name,
              parameters: parameters,
              result: 'Fehler: Screenshot nicht verfügbar.',
              isError: true,
              displayText: '❌ Screenshot nicht verfügbar',
            );
          }
          imagePath = await takeScreenshotCallback!();
          break;

        case 'file':
          if (filePath == null || filePath.isEmpty) {
            return ToolResult(
              toolName: definition.name,
              parameters: parameters,
              result: 'Fehler: file_path ist erforderlich bei source="file".',
              isError: true,
              displayText: '❌ Kein Dateipfad',
            );
          }
          final root = getRootPath?.call() ?? '/storage/emulated/0';
          final fullPath = resolveSandboxPath(root, filePath);
          if (fullPath == null) {
            return ToolResult(
              toolName: definition.name,
              parameters: parameters,
              result: 'Ungültiger Pfad: $filePath',
              isError: true,
              displayText: '❌ Ungültiger Pfad',
            );
          }
          if (await File(fullPath).exists()) {
            imagePath = fullPath;
          } else {
            return ToolResult(
              toolName: definition.name,
              parameters: parameters,
              result: 'Datei nicht gefunden: $filePath',
              isError: true,
              displayText: '❌ Datei nicht gefunden',
            );
          }
          break;

        default:
          return ToolResult(
            toolName: definition.name,
            parameters: parameters,
            result: 'Unbekannte Quelle: $source',
            isError: true,
          );
      }

      if (imagePath == null) {
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: 'Kein Bild ausgewählt/ausgenommen.',
          isError: true,
          displayText: '❌ Kein Bild',
        );
      }

      // Analyze with Vision LLM
      if (analyzeCallback == null) {
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result:
              'Bild gespeichert: $imagePath. Vision-Analyse nicht verfügbar (kein Callback registriert).',
          displayText: '📸 Bild gespeichert',
        );
      }

      final analysis = await analyzeCallback!(
        imagePath: imagePath,
        question: question,
      );

      if (analysis == null || analysis.isEmpty) {
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: 'Bildanalyse ergab kein Ergebnis.',
          isError: true,
          displayText: '❌ Analyse fehlgeschlagen',
        );
      }

      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Bildanalyse ($source):\n$analysis',
        displayText: '🔍 Bild analysiert',
      );
    } catch (e) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Fehler bei der Bildanalyse: $e',
        isError: true,
        displayText: '❌ Analyse-Fehler',
      );
    }
  }
}
