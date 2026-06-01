import 'tool_interface.dart';
import 'tool_definition.dart';
import 'tool_result.dart';

/// Deletes a calendar event.
class DeleteCalendarEventTool implements ToolInterface {
  static const _definition = ToolDefinition(
    name: 'delete_calendar_event',
    description: 'Löscht einen Kalendertermin anhand seiner ID.',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'event_id': {
          'type': 'string',
          'description': 'ID des zu löschenden Termins (aus get_calendar_events)',
        },
      },
      'required': ['event_id'],
    },
  );

  @override
  ToolDefinition get definition => _definition;

  /// Callback to delete a calendar event.
  static Future<bool> Function({required String eventId})? deleteEventCallback;

  @override
  Future<ToolResult> execute(Map<String, dynamic> parameters) async {
    final eventId = (parameters['event_id'] as String?)?.trim() ?? '';

    if (eventId.isEmpty) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Fehler: event_id ist erforderlich.',
        isError: true,
        displayText: '❌ Keine Event-ID',
      );
    }

    if (deleteEventCallback == null) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Fehler: Kalenderzugriff nicht verfügbar.',
        isError: true,
        displayText: '❌ Kalender nicht verfügbar',
      );
    }

    try {
      final success = await deleteEventCallback!(eventId: eventId);
      if (success) {
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: 'Termin $eventId gelöscht.',
          displayText: '🗑️ Termin gelöscht',
        );
      } else {
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: 'Fehler: Termin konnte nicht gelöscht werden.',
          isError: true,
          displayText: '❌ Löschen fehlgeschlagen',
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
