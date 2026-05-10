import 'tool_interface.dart';
import 'tool_definition.dart';
import 'tool_result.dart';

/// Returns the current time, date, weekday, and timezone.
class GetCurrentTimeTool implements ToolInterface {
  static const _definition = ToolDefinition(
    name: 'get_current_time',
    description:
        'Gibt die aktuelle Uhrzeit, das Datum, den Wochentag und die Zeitzone zurück. Nutze dies, wenn der Nutzer nach der Zeit fragt oder zeitbezogene Aufgaben hat.',
    parametersSchema: {
      'type': 'object',
      'properties': {},
      'required': [],
    },
  );

  @override
  ToolDefinition get definition => _definition;

  @override
  Future<ToolResult> execute(Map<String, dynamic> parameters) async {
    final now = DateTime.now();
    final weekdays = [
      'Montag', 'Dienstag', 'Mittwoch', 'Donnerstag',
      'Freitag', 'Samstag', 'Sonntag'
    ];
    final weekday = weekdays[now.weekday - 1];
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    final dateStr =
        '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year}';
    final tz = now.timeZoneName;

    final result =
        'Aktuelle Zeit: $timeStr\nDatum: $dateStr\nWochentag: $weekday\nZeitzone: $tz';

    return ToolResult(
      toolName: definition.name,
      parameters: parameters,
      result: result,
      displayText: '🕐 $timeStr, $weekday',
    );
  }
}