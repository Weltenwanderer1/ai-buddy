import 'tool_interface.dart';
import 'tool_definition.dart';
import 'tool_result.dart';

/// Sets a local reminder/notification.
/// Uses flutter_local_notifications under the hood.
class SetReminderTool implements ToolInterface {
  static const _definition = ToolDefinition(
    name: 'set_reminder',
    description: 'Setzt eine lokale Erinnerung/Benachrichtigung.',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'title': {
          'type': 'string',
          'description': 'Titel der Erinnerung (kurz, z.B. "Meeting")',
        },
        'body': {
          'type': 'string',
          'description': 'Beschreibung der Erinnerung',
        },
        'minutes_from_now': {
          'type': 'integer',
          'description':
              'Wie viele Minuten von jetzt an bis zur Erinnerung (Standard 5). Alias: delay_minutes.',
        },
        'datetime': {
          'type': 'string',
          'description':
              'Optionaler ISO-8601 Zeitpunkt, z.B. 2026-05-04T14:30:00. Wenn gesetzt, hat dieser Vorrang vor minutes_from_now.',
        },
      },
      'required': ['title'],
    },
  );

  @override
  ToolDefinition get definition => _definition;

  /// Callback to schedule a notification via the app's notification service.
  /// The app registers this at startup.
  static Future<bool> Function({
    required String title,
    required String body,
    required DateTime scheduledTime,
  })? scheduleCallback;

  @override
  Future<ToolResult> execute(Map<String, dynamic> parameters) async {
    final title = (parameters['title'] as String? ?? '').trim();
    final body = parameters['body'] as String? ?? '';
    final minutesFromNow = _readInt(parameters['minutes_from_now']) ??
        _readInt(parameters['delay_minutes']) ??
        _parseRelativeMinutes(parameters['relative_time'] as String?) ??
        5;

    if (title.isEmpty) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Fehler: Kein Titel für die Erinnerung angegeben.',
        isError: true,
        displayText: '❌ Kein Titel',
      );
    }

    final dateTimeParam = parameters['datetime'] as String? ??
        parameters['scheduled_time'] as String? ??
        parameters['time'] as String?;
    final parsedDateTime = dateTimeParam == null || dateTimeParam.trim().isEmpty
        ? null
        : DateTime.tryParse(dateTimeParam.trim());
    if (dateTimeParam != null &&
        dateTimeParam.trim().isNotEmpty &&
        parsedDateTime == null) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result:
            'Fehler: Zeitpunkt konnte nicht verstanden werden: $dateTimeParam. Nutze ISO-8601 oder minutes_from_now.',
        isError: true,
        displayText: '❌ Zeitpunkt unklar',
      );
    }

    final scheduledTime =
        parsedDateTime ?? DateTime.now().add(Duration(minutes: minutesFromNow));

    // If callback is registered, schedule via notification service
    if (scheduleCallback != null) {
      final success = await scheduleCallback!(
        title: title,
        body: body.isNotEmpty ? body : 'Erinnerung von AI-Buddy',
        scheduledTime: scheduledTime,
      );
      if (success) {
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result:
              'Erinnerung "$title" gesetzt für ${parsedDateTime != null ? scheduledTime.toIso8601String() : 'in $minutesFromNow Minuten'}.',
          displayText: '⏰ Erinnerung: $title',
        );
      } else {
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: 'Fehler: Erinnerung konnte nicht gesetzt werden.',
          isError: true,
          displayText: '❌ Erinnerung fehlgeschlagen',
        );
      }
    }

    // No callback — return acknowledgment (debug mode)
    return ToolResult(
      toolName: definition.name,
      parameters: parameters,
      result:
          'Erinnerung "$title" ${parsedDateTime != null ? 'für ${scheduledTime.toIso8601String()}' : 'in $minutesFromNow Minuten'} (Debug-Modus, kein Benachrichtigungsdienst).',
      displayText: '⏰ Erinnerung (Debug): $title',
    );
  }

  static int? _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  static int? _parseRelativeMinutes(String? input) {
    if (input == null || input.trim().isEmpty) return null;
    final match = RegExp(
            r'in\s+(\d+)\s*(sekunden|sec|minuten|min|stunden|std|h)',
            caseSensitive: false)
        .firstMatch(input.trim());
    if (match == null) return null;
    final amount = int.tryParse(match.group(1)!) ?? 0;
    final unit = match.group(2)!.toLowerCase();
    if (unit.startsWith('sek') || unit == 'sec') return (amount / 60).ceil();
    if (unit.startsWith('st') || unit == 'h') return amount * 60;
    return amount;
  }
}
