import 'tool_interface.dart';
import 'tool_definition.dart';
import 'tool_result.dart';

/// Adds a calendar event.
class AddCalendarEventTool implements ToolInterface {
  static const _definition = ToolDefinition(
    name: 'add_calendar_event',
    description:
        'Fügt einen Termin zum Kalender hinzu. Gib Titel, Startzeit und Endzeit/Dauer an.',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'title': {
          'type': 'string',
          'description': 'Titel des Termins',
        },
        'start': {
          'type': 'string',
          'description':
              'Startzeit im ISO-8601 Format (z.B. "2026-04-29T15:00:00") oder "in X Minuten"',
        },
        'end': {
          'type': 'string',
          'description':
              'Endzeit im ISO-8601 Format oder Dauer in Minuten (z.B. "60")',
        },
        'description': {
          'type': 'string',
          'description': 'Optionale Beschreibung',
        },
        'location': {
          'type': 'string',
          'description': 'Optionaler Ort',
        },
      },
      'required': ['title', 'start', 'end'],
    },
  );

  @override
  ToolDefinition get definition => _definition;

  /// Callback to add a calendar event. Registered by the app at startup.
  static Future<bool> Function({
    required String title,
    required DateTime start,
    required DateTime end,
    String? description,
    String? location,
  })? addEventCallback;

  @override
  Future<ToolResult> execute(Map<String, dynamic> parameters) async {
    final title = parameters['title'] as String? ?? '';
    final startStr = parameters['start'] as String? ?? '';
    final endStr = parameters['end'] as String? ?? '';
    final description = parameters['description'] as String?;
    final location = parameters['location'] as String?;

    if (title.isEmpty || startStr.isEmpty || endStr.isEmpty) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Fehler: Titel, Start- und Endzeit sind erforderlich.',
        isError: true,
        displayText: '❌ Termin-Daten unvollständig',
      );
    }

    // Parse start time
    DateTime? startTime;
    startTime = _parseDateTime(startStr);

    // Parse end time / duration
    DateTime? endTime;
    final endAsInt = int.tryParse(endStr);
    if (endAsInt != null && endAsInt > 0 && endAsInt <= 525600) {
      // Treat as duration in minutes
      endTime = (startTime ?? DateTime.now()).add(Duration(minutes: endAsInt));
    } else {
      endTime = _parseDateTime(endStr);
    }

    if (startTime == null) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Fehler: Startzeit konnte nicht geparst werden: $startStr',
        isError: true,
        displayText: '❌ Startzeit ungültig',
      );
    }

    endTime ??= startTime.add(const Duration(hours: 1)); // Default 1h

    if (addEventCallback == null) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Kalenderzugriff nicht verfügbar.',
        isError: true,
        displayText: '❌ Kalender nicht verfügbar',
      );
    }

    try {
      final success = await addEventCallback!(
        title: title,
        start: startTime,
        end: endTime,
        description: description,
        location: location,
      );

      if (success) {
        final startFormatted =
            '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
        final endFormatted =
            '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result:
              'Termin "$title" hinzugefügt: $startFormatted - $endFormatted',
          displayText: '📅 Termin: $title',
        );
      } else {
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: 'Fehler: Termin konnte nicht hinzugefügt werden.',
          isError: true,
          displayText: '❌ Termin-Fehler',
        );
      }
    } catch (e) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Fehler beim Hinzufügen des Termins: $e',
        isError: true,
        displayText: '❌ Termin-Fehler',
      );
    }
  }

  DateTime? _parseDateTime(String input) {
    // Handle "in X Minuten" format
    final inMinutes = RegExp(r'^in\s+(\d+)\s+Minuten?$', caseSensitive: false);
    final inMinutesMatch = inMinutes.firstMatch(input);
    if (inMinutesMatch != null) {
      final minutes = int.parse(inMinutesMatch.group(1)!);
      return DateTime.now().add(Duration(minutes: minutes));
    }

    // Handle ISO-8601
    return DateTime.tryParse(input);
  }
}