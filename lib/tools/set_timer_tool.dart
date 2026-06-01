import 'tool_interface.dart';
import 'tool_definition.dart';
import 'tool_result.dart';

/// Timer management tool — set, list, cancel timers with audible alarm.
class SetTimerTool implements ToolInterface {
  static const _definition = ToolDefinition(
    name: 'set_timer',
    description:
        'Timer starten, auflisten oder abbrechen. '
        'Aktionen: "set" (neuen Timer starten), "list" (aktive Timer anzeigen), '
        '"cancel" (Timer abbrechen).',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'action': {
          'type': 'string',
          'description':
              'Aktion: "set" (neuen Timer), "list" (alle anzeigen), "cancel" (abbrechen)',
          'enum': ['set', 'list', 'cancel'],
        },
        'label': {
          'type': 'string',
          'description': 'Name/Label des Timers (z.B. "Eier kochen")',
        },
        'duration_seconds': {
          'type': 'integer',
          'description':
              'Dauer in Sekunden (z.B. 300 für 5 Minuten). Bei action=set erforderlich.',
        },
        'timer_id': {
          'type': 'string',
          'description':
              'ID des Timers zum Abbrechen (aus action=list). Bei action=cancel erforderlich.',
        },
      },
      'required': ['action'],
    },
  );

  @override
  ToolDefinition get definition => _definition;

  /// Callback to set a timer. Returns the timer ID on success.
  static Future<String?> Function({
    required String label,
    required int durationSeconds,
  })? setTimerCallback;

  /// Callback to list active timers. Returns list of {id, label, remainingSeconds, totalSeconds}.
  static Future<List<Map<String, dynamic>>> Function()? listTimersCallback;

  /// Callback to cancel a timer by ID. Returns true on success.
  static Future<bool> Function({required String timerId})? cancelTimerCallback;

  @override
  Future<ToolResult> execute(Map<String, dynamic> parameters) async {
    final action = (parameters['action'] as String?)?.trim() ?? 'set';

    switch (action) {
      case 'set':
        return _setTimer(parameters);
      case 'list':
        return _listTimers();
      case 'cancel':
        return _cancelTimer(parameters);
      default:
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: 'Unbekannte Aktion: $action. Nutze "set", "list" oder "cancel".',
          isError: true,
        );
    }
  }

  Future<ToolResult> _setTimer(Map<String, dynamic> parameters) async {
    final label = (parameters['label'] as String?)?.trim() ?? 'Timer';
    final durationRaw = parameters['duration_seconds'];
    final duration = _readInt(durationRaw) ?? 0;

    if (duration <= 0) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Fehler: duration_seconds muss > 0 sein.',
        isError: true,
        displayText: '❌ Ungültige Dauer',
      );
    }

    if (setTimerCallback == null) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Fehler: Timer-Service nicht verfügbar.',
        isError: true,
        displayText: '❌ Timer nicht verfügbar',
      );
    }

    try {
      final timerId = await setTimerCallback!(
        label: label,
        durationSeconds: duration,
      );
      if (timerId != null) {
        final mins = duration ~/ 60;
        final secs = duration % 60;
        final durationStr = mins > 0
            ? '${mins}m ${secs > 0 ? "${secs}s" : ""}'
            : '${secs}s';
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: 'Timer "$label" gestartet: $durationStr (ID: $timerId)',
          displayText: '⏱️ Timer: $label ($durationStr)',
        );
      } else {
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: 'Fehler: Timer konnte nicht erstellt werden.',
          isError: true,
          displayText: '❌ Timer-Fehler',
        );
      }
    } catch (e) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Fehler beim Timer erstellen: $e',
        isError: true,
        displayText: '❌ Timer-Fehler',
      );
    }
  }

  Future<ToolResult> _listTimers() async {
    if (listTimersCallback == null) {
      return ToolResult(
        toolName: definition.name,
        parameters: {},
        result: 'Fehler: Timer-Service nicht verfügbar.',
        isError: true,
        displayText: '❌ Timer nicht verfügbar',
      );
    }

    try {
      final timers = await listTimersCallback!();
      if (timers.isEmpty) {
        return ToolResult(
          toolName: definition.name,
          parameters: {},
          result: 'Keine aktiven Timer.',
          displayText: '⏱️ Keine Timer',
        );
      }

      final buffer = StringBuffer('Aktive Timer:\n');
      for (final t in timers) {
        final remaining = t['remainingSeconds'] as int? ?? 0;
        final mins = remaining ~/ 60;
        final secs = remaining % 60;
        buffer.writeln(
          '- [${t['id']}] ${t['label']}: ${mins}m ${secs}s verbleibend',
        );
      }
      return ToolResult(
        toolName: definition.name,
        parameters: {},
        result: buffer.toString(),
        displayText: '⏱️ ${timers.length} Timer aktiv',
      );
    } catch (e) {
      return ToolResult(
        toolName: definition.name,
        parameters: {},
        result: 'Fehler beim Auflisten: $e',
        isError: true,
        displayText: '❌ Timer-Fehler',
      );
    }
  }

  Future<ToolResult> _cancelTimer(Map<String, dynamic> parameters) async {
    final timerId = (parameters['timer_id'] as String?)?.trim() ?? '';
    if (timerId.isEmpty) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Fehler: timer_id zum Abbrechen erforderlich.',
        isError: true,
        displayText: '❌ Keine Timer-ID',
      );
    }

    if (cancelTimerCallback == null) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Fehler: Timer-Service nicht verfügbar.',
        isError: true,
        displayText: '❌ Timer nicht verfügbar',
      );
    }

    try {
      final success = await cancelTimerCallback!(timerId: timerId);
      if (success) {
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: 'Timer $timerId abgebrochen.',
          displayText: '⏱️ Timer abgebrochen',
        );
      } else {
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: 'Timer $timerId nicht gefunden.',
          isError: true,
          displayText: '❌ Timer nicht gefunden',
        );
      }
    } catch (e) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Fehler beim Abbrechen: $e',
        isError: true,
        displayText: '❌ Timer-Fehler',
      );
    }
  }

  static int? _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }
}
