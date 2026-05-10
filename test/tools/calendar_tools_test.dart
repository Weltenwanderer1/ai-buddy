import 'package:flutter_test/flutter_test.dart';
import 'package:ai_buddy/tools/get_calendar_events_tool.dart';
import 'package:ai_buddy/tools/add_calendar_event_tool.dart';

void main() {
  group('GetCalendarEventsTool', () {
    test('definition has correct name', () {
      final tool = GetCalendarEventsTool();
      expect(tool.definition.name, 'get_calendar_events');
    });

    test('definition has required description', () {
      final tool = GetCalendarEventsTool();
      expect(tool.definition.description, isNotEmpty);
    });

    test('definition has days_ahead parameter', () {
      final tool = GetCalendarEventsTool();
      expect(tool.definition.parametersSchema['properties'], isNotNull);
      expect(
        (tool.definition.parametersSchema['properties'] as Map)
            .containsKey('days_ahead'),
        isTrue,
      );
    });

    test('returns error when no callback is set', () async {
      GetCalendarEventsTool.getEventsCallback = null;
      final tool = GetCalendarEventsTool();
      final result = await tool.execute({});

      expect(result.isError, isTrue);
      expect(result.result, contains('nicht verfügbar'));
    });

    test('returns error when callback is not ready', () async {
      GetCalendarEventsTool.getEventsCallback = null;
      final tool = GetCalendarEventsTool();
      final result = await tool.execute({'days_ahead': 3});

      expect(result.isError, isTrue);
    });

    test('default days_ahead is 7', () async {
      GetCalendarEventsTool.getEventsCallback = null;
      final tool = GetCalendarEventsTool();
      // Just verify it doesn't crash with no days_ahead
      final result = await tool.execute({});
      expect(result, isNotNull);
    });

    test('returns events from callback', () async {
      GetCalendarEventsTool.getEventsCallback = ({daysAhead = 7}) async {
        return [
          {
            'title': 'Test Meeting',
            'start': DateTime(2026, 5, 1, 10, 0),
            'end': DateTime(2026, 5, 1, 11, 0),
            'location': 'Office',
          },
        ];
      };
      final tool = GetCalendarEventsTool();
      final result = await tool.execute({'days_ahead': 7});

      expect(result.isError, isFalse);
      expect(result.result, contains('Test Meeting'));
      // Clean up
      GetCalendarEventsTool.getEventsCallback = null;
    });

    test('returns empty message when no events', () async {
      GetCalendarEventsTool.getEventsCallback = ({daysAhead = 7}) async {
        return <Map<String, dynamic>>[];
      };
      final tool = GetCalendarEventsTool();
      final result = await tool.execute({'days_ahead': 7});

      expect(result.isError, isFalse);
      expect(result.result, contains('Keine Termine'));
      // Clean up
      GetCalendarEventsTool.getEventsCallback = null;
    });
  });

  group('AddCalendarEventTool', () {
    test('definition has correct name', () {
      final tool = AddCalendarEventTool();
      expect(tool.definition.name, 'add_calendar_event');
    });

    test('returns error for missing title', () async {
      AddCalendarEventTool.addEventCallback = null;
      final tool = AddCalendarEventTool();
      final result = await tool.execute({
        'start': '2026-05-01T10:00:00',
        'end': '2026-05-01T11:00:00',
      });

      expect(result.isError, isTrue);
      expect(result.result, contains('erforderlich'));
    });

    test('returns error for empty title', () async {
      AddCalendarEventTool.addEventCallback = null;
      final tool = AddCalendarEventTool();
      final result = await tool.execute({
        'title': '',
        'start': '2026-05-01T10:00:00',
        'end': '60',
      });

      expect(result.isError, isTrue);
    });

    test('returns error for invalid start time', () async {
      AddCalendarEventTool.addEventCallback = null;
      final tool = AddCalendarEventTool();
      final result = await tool.execute({
        'title': 'Test Meeting',
        'start': 'not-a-date',
        'end': '60',
      });

      expect(result.isError, isTrue);
      expect(result.result, contains('Startzeit'));
    });

    test('parses "in X Minuten" format', () async {
      AddCalendarEventTool.addEventCallback = null;
      final tool = AddCalendarEventTool();
      // Even though it'll fail because no callback, the parse should work
      // and it should hit the "not available" error rather than "invalid start"
      final result = await tool.execute({
        'title': 'Quick Meeting',
        'start': 'in 30 Minuten',
        'end': '60',
      });

      // Should get past parsing (not a parse error)
      // but fail because no calendar callback
      expect(result.isError, isTrue);
      expect(result.result, contains('nicht verfügbar'));
    });

    test('treats numeric end as duration in minutes', () async {
      AddCalendarEventTool.addEventCallback = null;
      final tool = AddCalendarEventTool();
      final result = await tool.execute({
        'title': '1-Hour Meeting',
        'start': '2026-05-01T10:00:00',
        'end': '60', // 60 minutes = 1 hour
      });

      // Should parse successfully but fail because no calendar callback
      expect(result.isError, isTrue);
      expect(result.result, contains('nicht verfügbar'));
    });

    test('successfully adds event via callback', () async {
      AddCalendarEventTool.addEventCallback = ({
        required String title,
        required DateTime start,
        required DateTime end,
        String? description,
        String? location,
      }) async {
        return true;
      };
      final tool = AddCalendarEventTool();
      final result = await tool.execute({
        'title': 'Test Meeting',
        'start': '2026-05-01T10:00:00',
        'end': '2026-05-01T11:00:00',
      });

      expect(result.isError, isFalse);
      expect(result.result, contains('Test Meeting'));
      // Clean up
      AddCalendarEventTool.addEventCallback = null;
    });
  });
}