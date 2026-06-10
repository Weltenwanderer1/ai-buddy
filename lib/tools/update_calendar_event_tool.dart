import 'tool_interface.dart';
import 'tool_definition.dart';
import 'tool_result.dart';

/// Updates an existing calendar event.
class UpdateCalendarEventTool implements ToolInterface {
  static const _definition = ToolDefinition(
    name: 'update_calendar_event',
    description:
        'Bestehenden Kalendertermin bearbeiten. '
        'Mindestens event_id und ein zu änderndes Feld sind erforderlich.',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'event_id': {
          'type': 'string',
          'description': 'ID des zu bearbeitenden Termins (aus get_calendar_events)',
        },
        'title': {
          'type': 'string',
          'description': 'Neuer Titel',
        },
        'start': {
          'type': 'string',
          'description': 'Neue Startzeit (ISO-8601)',
        },
        'end': {
          'type': 'string',
          'description': 'Neue Endzeit (ISO-8601)',
        },
        'description': {
          'type': 'string',
          'description': 'Neue Beschreibung',
        },
        'location': {
          'type': 'string',
          'description': 'Neuer Ort',
        },
      },
      'required': ['event_id'],
    },
  );

  @override
  ToolDefinition get definition => _definition;

  /// Callback to update a calendar event.
  static Future<bool> Function({
    required String eventId,
    String? title,
    DateTime? start,
    DateTime? end,
    String? description,
    String? location,
  })? updateEventCallback;

  @override
  Future<ToolResult> execute(Map<String, dynamic> parameters) async {
    final eventId = (parameters['event_id'] as String?)?.trim() ?? '';
    final title = parameters['title'] as String?;
    final startStr = parameters['start'] as String?;
    final endStr = parameters['end'] as String?;
    final description = parameters['description'] as String?;
    final location = parameters['location'] as String?;

    if (eventId.isEmpty) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Fehler: event_id ist erforderlich.',
        isError: true,
        displayText: '❌ Keine Event-ID',
      );
    }

    if (title == null && startStr == null && endStr == null && description == null && location == null) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Fehler: Mindestens ein Feld (title, start, end, description, location) muss angegeben werden.',
        isError: true,
        displayText: '❌ Keine Änderungen angegeben',
      );
    }

    if (updateEventCallback == null) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Fehler: Kalenderzugriff nicht verfügbar.',
        isError: true,
        displayText: '❌ Kalender nicht verfügbar',
      );
    }

    try {
      final start = startStr != null ? DateTime.tryParse(startStr) : null;
      final end = endStr != null ? DateTime.tryParse(endStr) : null;

      final success = await updateEventCallback!(
        eventId: eventId,
        title: title,
        start: start,
        end: end,
        description: description,
        location: location,
      );

      if (success) {
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: 'Termin $eventId aktualisiert.',
          displayText: '📅 Termin aktualisiert',
        );
      } else {
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: 'Fehler: Termin konnte nicht aktualisiert werden.',
          isError: true,
          displayText: '❌ Update fehlgeschlagen',
        );
      }
    } catch (e) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Fehler: $e',
        isError: true,
        displayText: '❌ Fehler',
      );
    }
  }
}
