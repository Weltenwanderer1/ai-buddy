import 'tool_interface.dart';
import 'tool_definition.dart';
import 'tool_result.dart';
import 'get_calendar_events_tool.dart';

/// Adds a calendar event.
class AddCalendarEventTool implements ToolInterface {
  static const _definition = ToolDefinition(
    name: 'add_calendar_event',
    description:
        'Termin zum Kalender hinzufuegen. Unterstuetzt Einzel- UND Serientermine.',
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
              'Startzeit im ISO-8601 Format oder "in X Minuten"',
        },
        'end': {
          'type': 'string',
          'description':
              'Endzeit im ISO-8601 Format oder Dauer in Minuten',
        },
        'recurrence': {
          'type': 'string',
          'description': 'Serie: "daily", "weekly", "biweekly", "weekday", "monthly", "yearly", oder "every_2nd_monday". Nur angeben wenn es wiederholt.',
        },
        'recurrence_count': {
          'type': 'integer',
          'description': 'Optional: Anzahl Wiederholungen z.B. 10. Anstatt von Enddatum.',
        },
        'recurrence_end': {
          'type': 'string',
          'description': 'Optional: Letztes Datum im ISO-8601 Format. Anstatt von count.',
        },
        'excluded_dates': {
          'type': 'array',
          'description': 'Optional: Feiertage/Ferien als ISO-Datum Strings, die uebersprungen werden.',
          'items': {'type': 'string'},
        },
        'description': {
          'type': 'string',
          'description': 'Optionale Beschreibung',
        },
        'location': {
          'type': 'string',
          'description': 'Optionaler Ort',
        },
        'ignore_conflict': {
          'type': 'boolean',
          'description': 'Falls true, wird ein doppelter Termin trotzdem erstellt.',
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
    String? recurrence,
    int? recurrenceCount,
    DateTime? recurrenceEnd,
    List<DateTime>? excludedDates,
  })? addEventCallback;

  @override
  Future<ToolResult> execute(Map<String, dynamic> parameters) async {
    final title = parameters['title'] as String? ?? '';
    final startStr = parameters['start'] as String? ?? '';
    final endStr = parameters['end'] as String? ?? '';
    final description = parameters['description'] as String?;
    final location = parameters['location'] as String?;
    final ignoreConflict = parameters['ignore_conflict'] as bool? ?? false;

    // Recurrence params
    final recurrence = parameters['recurrence'] as String?;
    final recurrenceEndParam = parameters['recurrence_end'];
    final recurrenceCount = (parameters['recurrence_count'] as int?) ?? 
        ((recurrence != null && recurrenceEndParam == null) ? 52 : null);
    final recurrenceEndStr = parameters['recurrence_end'] as String?;
    final recurrenceEnd = recurrenceEndStr != null ? DateTime.tryParse(recurrenceEndStr) : null;
    final excludedRaw = parameters['excluded_dates'] as List<dynamic>?;
    final excludedDates = excludedRaw
        ?.map((e) => DateTime.tryParse(e.toString()))
        .whereType<DateTime>()
        .toList();

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
    final startTime = _parseDateTime(startStr);
    if (startTime == null) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Fehler: Startzeit konnte nicht geparst werden: $startStr',
        isError: true,
        displayText: '❌ Startzeit ungültig',
      );
    }

    // Parse end time / duration
    DateTime? endTime;
    final endAsInt = int.tryParse(endStr);
    if (endAsInt != null && endAsInt > 0 && endAsInt <= 525600) {
      // Treat as duration in minutes
      endTime = startTime.add(Duration(minutes: endAsInt));
    } else {
      endTime = _parseDateTime(endStr);
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

    // ====== CONFLICT DETECTION ======
    if (!ignoreConflict) {
      final conflict = await _findConflict(startTime, endTime);
      if (conflict != null) {
        // Generate suggestions
        final suggestions = <Map<String, dynamic>>[];
        
        // Suggest 1: +1 hour
        var s1 = startTime.add(const Duration(hours: 1));
        var e1 = endTime.add(const Duration(hours: 1));
        if (await _isFree(s1, e1)) {
          suggestions.add({
            'label': '1 Stunde später',
            'start': s1,
            'end': e1,
          });
        }

        // Suggest 2: +2 hours
        var s2 = startTime.add(const Duration(hours: 2));
        var e2 = endTime.add(const Duration(hours: 2));
        if (await _isFree(s2, e2)) {
          suggestions.add({
            'label': '2 Stunden später',
            'start': s2,
            'end': e2,
          });
        }

        // Suggest 3: Next day same time
        var s3 = startTime.add(const Duration(days: 1));
        var e3 = endTime.add(const Duration(days: 1));
        if (await _isFree(s3, e3)) {
          suggestions.add({
            'label': 'Nächster Tag',
            'start': s3,
            'end': e3,
          });
        }

        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: _buildConflictMessage(
            title: title,
            conflict: conflict,
            suggestions: suggestions,
          ),
          isError: false, // Not an error, it's a blocking hint
          displayText: '⚠️ Termin kollidiert: ${conflict['title']}',
        );
      }
    }

    try {
      final success = await addEventCallback!(
        title: title,
        start: startTime,
        end: endTime,
        description: description,
        location: location,
        recurrence: recurrence,
        recurrenceCount: recurrenceCount,
        recurrenceEnd: recurrenceEnd,
        excludedDates: excludedDates,
      );

      if (success) {
        String extra = '';
        if (recurrence != null) {
          extra = ' (Serie: $recurrence';
          if (recurrenceCount != null) extra += ', ${recurrenceCount}x';
          if (recurrenceEnd != null) extra += ', bis ${_fmt(recurrenceEnd)}';
          if (excludedDates != null && excludedDates.isNotEmpty) {
            extra += ', ausgenommen ${excludedDates.length} Tage';
          }
          extra += ')';
        }
        final startFormatted =
            '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
        final endFormatted =
            '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result:
              'Termin "$title" hinzugefügt: $startFormatted - $endFormatted$extra',
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

  /// Find overlapping event between start-end range.
  /// Returns null if free.
  Future<Map<String, dynamic>?> _findConflict(DateTime start, DateTime end) async {
    if (GetCalendarEventsTool.getEventsCallback == null) return null;
    
    final events = await GetCalendarEventsTool.getEventsCallback!(daysAhead: 14);
    for (final event in events) {
      final eStart = _parseEventDate(event['start']);
      final eEnd = _parseEventDate(event['end']);
      if (eStart == null || eEnd == null) continue;
      
      // Check overlap: (start < eEnd) && (end > eStart)
      if (start.isBefore(eEnd) && end.isAfter(eStart)) {
        return event;
      }
    }
    return null;
  }

  /// Check if a time slot is free
  Future<bool> _isFree(DateTime start, DateTime end) async {
    return (await _findConflict(start, end)) == null;
  }

  /// Parse event date from string (ISO or whatever format calendar returns)
  DateTime? _parseEventDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) {
      final dt = DateTime.tryParse(value);
      if (dt != null) return dt;
      // Try common formats
      final patterns = [
        RegExp(r'\d{2}\.\d{2}\.\d{4} \d{2}:\d{2}'), // German format
        RegExp(r'\d{2}/\d{2}/\d{4} \d{2}:\d{2}'),   // US format
        RegExp(r'\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}'), // ISO-ish
      ];
      for (final p in patterns) {
        if (p.hasMatch(value)) {
          // Can't easily parse all with regex, default to tryParse
          break;
        }
      }
    }
    return null;
  }

  /// Build human-readable conflict message with suggestions
  String _buildConflictMessage({
    required String title,
    required Map<String, dynamic> conflict,
    required List<Map<String, dynamic>> suggestions,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('Termin-KONFLIKT erkannt!');
    buffer.writeln('Neuer Termin: "$title"');
    buffer.writeln('Überschneidung mit: "${conflict['title']}"');
    if (conflict['start'] != null) buffer.writeln('  (${conflict['start']} - ${conflict['end']})');
    
    if (suggestions.isNotEmpty) {
      buffer.writeln('\nAlternative Zeiten:');
      for (final s in suggestions) {
        final start = s['start'] as DateTime;
        final end = s['end'] as DateTime;
        final label = s['label'] as String;
        buffer.writeln('  • $label: ${_fmt(start)} - ${_fmt(end)}');
      }
    }
    
    buffer.writeln('\nZum Erzwingen: "ignore_conflict": true mitgeben.');
    return buffer.toString();
  }

  String _fmt(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}. ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

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
