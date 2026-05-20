import 'tool_interface.dart';
import 'tool_definition.dart';
import 'tool_result.dart';

/// Gets upcoming calendar events.
class GetCalendarEventsTool implements ToolInterface {
  static const _definition = ToolDefinition(
    name: 'get_calendar_events',
    description:
        'Liest die nächsten Kalendertermine. Nutze dies, wenn der Nutzer wissen möchte, welche Termine anstehen.',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'days_ahead': {
          'type': 'integer',
          'description':
              'Wie viele Tage im Voraus gesucht werden soll (Standard 7)',
        },
      },
      'required': [],
    },
  );

  @override
  ToolDefinition get definition => _definition;

  /// Callback to get calendar events. Registered by the app at startup.
  static Future<List<Map<String, dynamic>>> Function({
    int daysAhead,
  })? getEventsCallback;

  @override
  Future<ToolResult> execute(Map<String, dynamic> parameters) async {
    final daysAhead = (parameters['days_ahead'] as int?) ?? 7;

    if (getEventsCallback == null) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Fehler: Kalenderzugriff nicht verfügbar.',
        isError: true,
        displayText: '❌ Kalender nicht verfügbar',
      );
    }

    try {
      final events = await getEventsCallback!(daysAhead: daysAhead);
      if (events.isEmpty) {
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: 'Keine Termine in den nächsten $daysAhead Tagen.',
          displayText: '📅 Keine Termine',
        );
      }

      final buffer = StringBuffer('Termine (nächste $daysAhead Tage):\n');
      for (final event in events) {
        buffer.writeln(
          '- ${event['title']} (${event['start']} - ${event['end']})',
        );
        if (event['location'] != null) {
          buffer.writeln('  Ort: ${event['location']}');
        }
      }

      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: buffer.toString(),
        displayText: '📅 ${events.length} Termin(e)',
      );
    } catch (e) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Fehler beim Lesen des Kalenders: $e',
        isError: true,
        displayText: '❌ Kalender-Fehler',
      );
    }
  }
}
