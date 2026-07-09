import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'open_file_tool.dart';
import 'tool_definition.dart';
import 'tool_interface.dart';
import 'tool_result.dart';

/// Searches the phone's photo library (MediaStore) by filename, album/folder
/// name and/or how recently the photo was taken, and can open a match in the
/// gallery. Needs the media-images permission (granted at first use).
class SearchPhotosTool implements ToolInterface {
  static const MethodChannel _channel = MethodChannel('com.aibuddy.app/media');

  static const _definition = ToolDefinition(
    name: 'search_photos',
    description:
        'Durchsucht die Fotos des Nutzers (nach Dateiname, Album/Ordner, '
        'Aufnahmezeit) und kann ein Foto in der Galerie oeffnen. '
        'Beispiele: "Urlaub", "Screenshot", letzte 7 Tage. '
        'Parameter open=true oeffnet das erste Ergebnis in der Galerie.',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'query': {
          'type': 'string',
          'description':
              'Suchbegriff fuer Dateiname oder Album/Ordner (z.B. "Urlaub", "Screenshot", "WhatsApp"). Optional.',
        },
        'days_back': {
          'type': 'integer',
          'description': 'Nur Fotos der letzten N Tage. 0 = keine Zeitgrenze. Optional.',
        },
        'limit': {
          'type': 'integer',
          'description': 'Maximale Anzahl Ergebnisse (Standard 30).',
        },
        'open': {
          'type': 'boolean',
          'description': 'true = das erste/neueste Ergebnis in der Galerie oeffnen.',
        },
      },
      'required': [],
    },
  );

  @override
  ToolDefinition get definition => _definition;

  @override
  Future<ToolResult> execute(Map<String, dynamic> parameters) async {
    final query = (parameters['query'] as String?)?.trim() ?? '';
    final daysBack = _readInt(parameters['days_back']) ?? 0;
    final limit = (_readInt(parameters['limit']) ?? 30).clamp(1, 200);
    final open = parameters['open'] as bool? ?? false;

    // Request the media permission up front (like the other tools do) so the
    // first use actually works instead of bouncing the user into settings.
    // Permission.photos maps to READ_MEDIA_IMAGES on Android 13+; on older
    // versions Permission.storage covers READ_EXTERNAL_STORAGE.
    if (!await Permission.photos.isGranted && !await Permission.storage.isGranted) {
      var status = await Permission.photos.request();
      if (!status.isGranted) {
        status = await Permission.storage.request();
      }
      if (!status.isGranted) {
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result:
              'Keine Foto-Berechtigung erhalten. Bitte in den App-Einstellungen den Zugriff auf Fotos/Medien fuer AI-Buddy erlauben.',
          isError: true,
          displayText: '❌ Keine Foto-Berechtigung',
        );
      }
    }

    try {
      final raw = await _channel.invokeMethod('searchPhotos', {
        'query': query,
        'limit': limit,
        'daysBack': daysBack,
      });
      final photos = (raw as List<dynamic>?)
              ?.map((e) => (e as Map).map((k, v) => MapEntry(k.toString(), v)))
              .toList() ??
          [];

      if (photos.isEmpty) {
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: query.isEmpty
              ? 'Keine Fotos gefunden.'
              : 'Keine Fotos gefunden fuer "$query".',
          displayText: '📷 Keine Treffer',
        );
      }

      final buffer = StringBuffer('Gefundene Fotos (${photos.length}):\n');
      for (final p in photos.take(40)) {
        final name = p['name']?.toString() ?? '?';
        final album = p['album']?.toString() ?? '';
        final date = _formatDate(p['dateTaken']);
        buffer.writeln('- $name${album.isNotEmpty ? ' [$album]' : ''}${date.isNotEmpty ? ' — $date' : ''}');
      }
      if (photos.length > 40) {
        buffer.writeln('... und ${photos.length - 40} weitere.');
      }

      // Optionally open the newest match in the gallery.
      if (open) {
        final path = photos.first['path']?.toString() ?? '';
        if (path.isNotEmpty) {
          final opened = await OpenFileTool().execute({
            'filePath': path,
            'mimeHint': 'image/*',
          });
          if (!opened.isError) {
            buffer.writeln('\nGeoeffnet: ${photos.first['name']}');
          }
        }
      }

      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: buffer.toString(),
        displayText: '📷 ${photos.length} Foto(s)',
      );
    } on PlatformException catch (e) {
      if (e.code == 'PERMISSION_DENIED') {
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result:
              'Keine Foto-Berechtigung. Bitte in den App-Einstellungen den Zugriff auf Fotos/Medien fuer AI-Buddy erlauben.',
          isError: true,
          displayText: '❌ Keine Foto-Berechtigung',
        );
      }
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Fehler: ${e.message}',
        isError: true,
        displayText: '❌ Foto-Suche fehlgeschlagen',
      );
    } catch (e) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Fehler: $e',
        isError: true,
        displayText: '❌ Foto-Suche fehlgeschlagen',
      );
    }
  }

  String _formatDate(dynamic millis) {
    final m = _readInt(millis);
    if (m == null || m <= 0) return '';
    final d = DateTime.fromMillisecondsSinceEpoch(m);
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  int? _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }
}
