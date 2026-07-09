import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';

import 'tool_definition.dart';
import 'tool_interface.dart';
import 'tool_result.dart';

/// Sets a real system alarm/timer in the phone's clock app via the standard
/// AlarmClock intents. Unlike set_reminder (a local notification) this creates
/// an actual alarm that rings even when AI-Buddy is closed.
class SetAlarmTool implements ToolInterface {
  static const _definition = ToolDefinition(
    name: 'set_alarm',
    description:
        'Stellt einen echten Wecker oder Countdown-Timer in der Uhr-App des '
        'Telefons. Der Wecker klingelt auch, wenn AI-Buddy geschlossen ist. '
        'Aktionen: "alarm" (Wecker zu Uhrzeit, hour+minute), '
        '"timer" (Countdown, seconds), "show" (Wecker-Uebersicht oeffnen). '
        'Fuer eine reine App-interne Erinnerung nutze stattdessen set_reminder.',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'action': {
          'type': 'string',
          'enum': ['alarm', 'timer', 'show'],
          'description': 'alarm=Wecker, timer=Countdown, show=Wecker-Liste',
        },
        'hour': {
          'type': 'integer',
          'description': 'Bei alarm: Stunde 0-23.',
        },
        'minute': {
          'type': 'integer',
          'description': 'Bei alarm: Minute 0-59 (Standard 0).',
        },
        'seconds': {
          'type': 'integer',
          'description': 'Bei timer: Dauer in Sekunden (z.B. 300 = 5 Minuten).',
        },
        'message': {
          'type': 'string',
          'description': 'Beschriftung des Weckers/Timers, optional.',
        },
        'days': {
          'type': 'array',
          'items': {'type': 'string'},
          'description':
              'Bei alarm: Wochentage fuer Wiederholung, z.B. ["monday","friday"]. Optional.',
        },
      },
      'required': ['action'],
    },
  );

  @override
  ToolDefinition get definition => _definition;

  static const _weekdays = <String, int>{
    'sunday': 1, 'sonntag': 1, 'so': 1,
    'monday': 2, 'montag': 2, 'mo': 2,
    'tuesday': 3, 'dienstag': 3, 'di': 3,
    'wednesday': 4, 'mittwoch': 4, 'mi': 4,
    'thursday': 5, 'donnerstag': 5, 'do': 5,
    'friday': 6, 'freitag': 6, 'fr': 6,
    'saturday': 7, 'samstag': 7, 'sa': 7,
  };

  @override
  Future<ToolResult> execute(Map<String, dynamic> parameters) async {
    final action = (parameters['action'] as String?)?.trim() ?? 'alarm';
    try {
      switch (action) {
        case 'timer':
          return await _setTimer(parameters);
        case 'show':
          return await _showAlarms(parameters);
        case 'alarm':
        default:
          return await _setAlarm(parameters);
      }
    } catch (e) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Wecker/Timer fehlgeschlagen: $e',
        isError: true,
        displayText: '❌ Wecker fehlgeschlagen',
      );
    }
  }

  Future<ToolResult> _setAlarm(Map<String, dynamic> parameters) async {
    final hour = _readInt(parameters['hour']);
    final minute = _readInt(parameters['minute']) ?? 0;
    if (hour == null || hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Fehler: Gueltige Uhrzeit noetig (hour 0-23, minute 0-59).',
        isError: true,
        displayText: '❌ Ungueltige Zeit',
      );
    }
    final message = (parameters['message'] as String?)?.trim() ?? 'AI-Buddy Wecker';
    final days = _parseDays(parameters['days']);

    final arguments = <String, dynamic>{
      'android.intent.extra.alarm.HOUR': hour,
      'android.intent.extra.alarm.MINUTES': minute,
      'android.intent.extra.alarm.MESSAGE': message,
      // SKIP_UI would try to create silently; keep UI so the user sees/confirms
      // the alarm the assistant created (safer + works across clock apps).
      'android.intent.extra.alarm.SKIP_UI': false,
    };
    if (days.isNotEmpty) {
      arguments['android.intent.extra.alarm.DAYS'] = days;
    }

    final intent = AndroidIntent(
      action: 'android.intent.action.SET_ALARM',
      arguments: arguments,
      flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
    );
    await intent.launch();

    final hh = hour.toString().padLeft(2, '0');
    final mm = minute.toString().padLeft(2, '0');
    final repeat = days.isEmpty ? '' : ' (wiederkehrend)';
    return ToolResult(
      toolName: definition.name,
      parameters: parameters,
      result: 'Wecker gestellt fuer $hh:$mm$repeat — "$message".',
      displayText: '⏰ Wecker $hh:$mm',
    );
  }

  Future<ToolResult> _setTimer(Map<String, dynamic> parameters) async {
    final seconds = _readInt(parameters['seconds']);
    if (seconds == null || seconds <= 0) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Fehler: Timer-Dauer in Sekunden (seconds) noetig.',
        isError: true,
        displayText: '❌ Keine Dauer',
      );
    }
    final message = (parameters['message'] as String?)?.trim() ?? 'AI-Buddy Timer';

    final intent = AndroidIntent(
      action: 'android.intent.action.SET_TIMER',
      arguments: <String, dynamic>{
        'android.intent.extra.alarm.LENGTH': seconds,
        'android.intent.extra.alarm.MESSAGE': message,
        'android.intent.extra.alarm.SKIP_UI': true,
      },
      flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
    );
    await intent.launch();

    final mins = (seconds / 60).floor();
    final secs = seconds % 60;
    final label = mins > 0
        ? '$mins Min${secs > 0 ? ' $secs Sek' : ''}'
        : '$secs Sek';
    return ToolResult(
      toolName: definition.name,
      parameters: parameters,
      result: 'Timer gestartet: $label — "$message".',
      displayText: '⏲️ Timer $label',
    );
  }

  Future<ToolResult> _showAlarms(Map<String, dynamic> parameters) async {
    final intent = AndroidIntent(
      action: 'android.intent.action.SHOW_ALARMS',
      flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
    );
    await intent.launch();
    return ToolResult(
      toolName: definition.name,
      parameters: parameters,
      result: 'Wecker-Uebersicht geoeffnet.',
      displayText: '⏰ Wecker-Liste',
    );
  }

  List<int> _parseDays(dynamic raw) {
    if (raw is! List) return const [];
    final days = <int>[];
    for (final d in raw) {
      final key = d.toString().trim().toLowerCase();
      final v = _weekdays[key];
      if (v != null && !days.contains(v)) days.add(v);
    }
    return days;
  }

  int? _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }
}
