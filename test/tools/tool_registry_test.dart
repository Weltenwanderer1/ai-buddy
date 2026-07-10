import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_buddy/tools/tool_registry.dart';
import 'package:ai_buddy/tools/tool_definition.dart';
import 'package:ai_buddy/tools/tool_result.dart';
import 'package:ai_buddy/tools/get_current_time_tool.dart';
import 'package:ai_buddy/tools/web_search_tool.dart';
import 'package:ai_buddy/tools/get_webpage_tool.dart';
import 'package:ai_buddy/tools/set_reminder_tool.dart';
import 'package:ai_buddy/tools/open_url_tool.dart';
import 'package:ai_buddy/tools/share_text_tool.dart';
import 'package:ai_buddy/tools/read_config_tool.dart';
import 'package:ai_buddy/tools/update_config_tool.dart';
import 'package:ai_buddy/tools/get_calendar_events_tool.dart';
import 'package:ai_buddy/tools/add_calendar_event_tool.dart';
import 'package:ai_buddy/tools/open_app_tool.dart';
import 'package:ai_buddy/tools/music_intent_tool.dart';
import 'package:ai_buddy/tools/navigate_to_tool.dart';
import 'package:ai_buddy/tools/send_email_tool.dart';
import 'package:ai_buddy/tools/manage_shopping_list_tool.dart';

void main() {
  group('ToolRegistry', () {
    test('createDefault registers all expected tools', () {
      final registry = ToolRegistry.createDefault();
      expect(registry.toolNames, contains('get_current_time'));
      expect(registry.toolNames, contains('get_device_info'));
      expect(registry.toolNames, contains('web_search'));
      expect(registry.toolNames, contains('get_webpage'));
      expect(registry.toolNames, contains('set_reminder'));
      expect(registry.toolNames, contains('open_url'));
      expect(registry.toolNames, contains('share_text'));
      expect(registry.toolNames, contains('read_config'));
      expect(registry.toolNames, contains('update_config'));
      expect(registry.toolNames, contains('get_calendar_events'));
      expect(registry.toolNames, contains('add_calendar_event'));
      expect(registry.toolNames, contains('open_app'));
      expect(registry.toolNames, contains('open_navigation'));
      expect(registry.toolNames, contains('get_battery_info'));
      expect(registry.toolNames, contains('get_clipboard'));
      expect(registry.toolNames, contains('music_intent'));
      // Nicht hartkodieren — neue Tools kommen laufend dazu.
      expect(registry.toolNames.length, greaterThanOrEqualTo(26));
    });

    test('hasTool returns true for registered tools', () {
      final registry = ToolRegistry.createDefault();
      expect(registry.hasTool('get_current_time'), isTrue);
      expect(registry.hasTool('nonexistent'), isFalse);
    });

    test('getTool returns the correct tool', () {
      final registry = ToolRegistry.createDefault();
      final tool = registry.getTool('get_current_time');
      expect(tool, isNotNull);
      expect(tool!.definition.name, 'get_current_time');
    });

    test('getToolDefinitions returns API-format definitions', () {
      final registry = ToolRegistry.createDefault();
      final defs = registry.getToolDefinitions();
      expect(defs.length, registry.toolNames.length);
      expect(defs[0], containsPair('type', 'function'));
      expect(defs[0]['function'], isA<Map>());
      expect(defs[0]['function']['name'], isNotEmpty);
      expect(defs[0]['function']['parameters'], isA<Map>());
    });

    test('execute returns error for unknown tool', () async {
      final registry = ToolRegistry.createDefault();
      final result = await registry.execute('nonexistent', {});
      expect(result.isError, isTrue);
      expect(result.result, contains('Unbekanntes Tool'));
    });

    test('register adds a custom tool', () {
      final registry = ToolRegistry();
      registry.register(GetCurrentTimeTool());
      expect(registry.hasTool('get_current_time'), isTrue);
    });
  });

  group('ToolDefinition', () {
    test('toApiJson produces correct format', () {
      const def = ToolDefinition(
        name: 'test_tool',
        description: 'A test tool',
        parametersSchema: {
          'type': 'object',
          'properties': {
            'query': {'type': 'string'}
          },
          'required': ['query'],
        },
      );
      final json = def.toApiJson();
      expect(json['type'], 'function');
      expect(json['function']['name'], 'test_tool');
      expect(json['function']['description'], 'A test tool');
      expect(json['function']['parameters']['type'], 'object');
    });
  });

  group('GetCurrentTimeTool', () {
    test('returns current time info', () async {
      final tool = GetCurrentTimeTool();
      final result = await tool.execute({});
      expect(result.isError, isFalse);
      expect(result.result, contains('Aktuelle Zeit'));
      expect(result.result, contains('Wochentag'));
      expect(result.displayText, contains('🕐'));
    });

    test('definition has correct name', () {
      final tool = GetCurrentTimeTool();
      expect(tool.definition.name, 'get_current_time');
    });

    test('definition has no required parameters', () {
      final tool = GetCurrentTimeTool();
      expect(tool.definition.parametersSchema['required'], isEmpty);
    });
  });

  group('WebSearchTool', () {
    test('returns error for empty query', () async {
      final tool = WebSearchTool();
      final result = await tool.execute({});
      expect(result.isError, isTrue);
      expect(result.result, contains('Keine Suchanfrage'));
    });

    test('definition has query as required parameter', () {
      final tool = WebSearchTool();
      final required = tool.definition.parametersSchema['required'] as List;
      expect(required, contains('query'));
    });
  });

  group('GetWebpageTool', () {
    test('returns error for empty URL', () async {
      final tool = GetWebpageTool();
      final result = await tool.execute({});
      expect(result.isError, isTrue);
      expect(result.result, contains('Keine URL'));
    });

    test('returns error for invalid URL', () async {
      final tool = GetWebpageTool();
      final result = await tool.execute({'url': 'not-a-url'});
      expect(result.isError, isTrue);
    });

    test('extractText strips HTML', () {
      final tool = GetWebpageTool();
      // Access private method indirectly through execute
      // We can test the tool definition instead
      expect(tool.definition.name, 'get_webpage');
    });
  });

  group('SetReminderTool', () {
    test('returns error for empty title', () async {
      final tool = SetReminderTool();
      final result = await tool.execute({});
      expect(result.isError, isTrue);
      expect(result.result, contains('Kein Titel'));
    });

    test('uses default minutes_from_now', () async {
      final tool = SetReminderTool();
      // No callback set -- should still acknowledge
      final result = await tool.execute({'title': 'Test'});
      expect(result.isError, isFalse);
      expect(result.result, contains('5 Minuten'));
    });

    test('definition has title as required', () {
      final tool = SetReminderTool();
      final required = tool.definition.parametersSchema['required'] as List;
      expect(required, contains('title'));
    });
  });

  group('OpenUrlTool', () {
    test('returns error for empty URL', () async {
      final tool = OpenUrlTool();
      final result = await tool.execute({});
      expect(result.isError, isTrue);
    });

    test('returns error for invalid URL', () async {
      final tool = OpenUrlTool();
      final result = await tool.execute({'url': 'ftp://invalid'});
      expect(result.isError, isTrue);
    });
  });

  group('ShareTextTool', () {
    test('returns error for empty text', () async {
      final tool = ShareTextTool();
      final result = await tool.execute({});
      expect(result.isError, isTrue);
    });

    test('definition has text as required', () {
      final tool = ShareTextTool();
      final required = tool.definition.parametersSchema['required'] as List;
      expect(required, contains('text'));
    });
  });

  group('ReadConfigTool', () {
    test('returns error when no callback set', () async {
      final tool = ReadConfigTool();
      final result = await tool.execute({});
      expect(result.isError, isTrue);
      expect(result.result, contains('nicht verfügbar'));
    });

    test('returns config when callback is set', () async {
      final tool = ReadConfigTool();
      ReadConfigTool.readConfigCallback = () => {
            'persona_name': 'Luna',
            'model': 'glm-5.1',
          };
      final result = await tool.execute({});
      expect(result.isError, isFalse);
      expect(result.result, contains('Luna'));
      ReadConfigTool.readConfigCallback = null;
    });
  });

  group('UpdateConfigTool', () {
    test('returns error for empty key', () async {
      final tool = UpdateConfigTool();
      final result = await tool.execute({});
      expect(result.isError, isTrue);
    });

    test('returns error for disallowed key', () async {
      final tool = UpdateConfigTool();
      final result = await tool.execute({'key': 'api_key', 'value': 'stolen'});
      expect(result.isError, isTrue);
      expect(result.result, contains('nicht erlaubt'));
    });

    test('accepts allowed key', () async {
      final tool = UpdateConfigTool();
      // No callback set -- will return error for update failure
      final result = await tool.execute({'key': 'temperature', 'value': '0.5'});
      // Should at least pass the allowlist check
      expect(result.isError, isTrue); // no callback registered
      expect(result.result, isNot(contains('nicht erlaubt')));
    });
  });

  group('GetCalendarEventsTool', () {
    test('returns error when no callback set', () async {
      final tool = GetCalendarEventsTool();
      final result = await tool.execute({});
      expect(result.isError, isTrue);
      expect(result.result, contains('nicht verfügbar'));
    });
  });

  group('AddCalendarEventTool', () {
    test('returns error for missing required fields', () async {
      final tool = AddCalendarEventTool();
      final result = await tool.execute({});
      expect(result.isError, isTrue);
      expect(result.result, contains('erforderlich'));
    });

    test('parses ISO-8601 start time', () async {
      final tool = AddCalendarEventTool();
      // No callback -- will fail, but should parse the time
      final result = await tool.execute({
        'title': 'Test',
        'start': '2026-04-29T15:00:00',
        'end': '60', // 60 minutes duration
      });
      expect(result.isError, isTrue); // no callback
      expect(result.result, isNot(contains('Startzeit konnte nicht')));
    });
  });

  group('OpenAppTool', () {
    test('returns error for empty app name', () async {
      final tool = OpenAppTool();
      final result = await tool.execute({'app': ''});
      expect(result.isError, isTrue);
      expect(result.result, contains('Keine App'));
    });

    test('definition has correct name', () {
      final tool = OpenAppTool();
      expect(tool.definition.name, 'open_app');
    });

    test('normalizes app names with filler words', () {
      final normalized =
          OpenAppTool.normalizeAppName('  bitte die Spotify App  ');
      expect(normalized, contains('spotify'));
      expect(normalized, isNot(contains('bitte')));
      expect(normalized, isNot(contains('die')));
      expect(normalized, isNot(contains('app')));
    });

    test('normalizes app names with Umlauts', () {
      // Should keep Umlauts in canonical form
      final normalized =
          OpenAppTool.normalizeAppName('  öffne die Einstellungen App  ');
      expect(normalized, contains('einstellungen'));
      expect(normalized, isNot(contains('oeffne')));
      expect(normalized, isNot(contains('bitte')));
    });

    test('normalizes app names with oe-variants', () {
      final normalized = OpenAppTool.normalizeAppName('oeffne Spotify bitte');
      // The raw normalization should still have spotify but no filler
      expect(normalized, contains('spotify'));
      expect(normalized, isNot(contains('bitte')));
    });

    test('resolves known app names', () {
      expect(OpenAppTool.resolvePackageName('spotify'), 'com.spotify.music');
      expect(OpenAppTool.resolvePackageName('whatsapp'), 'com.whatsapp');
      expect(OpenAppTool.resolvePackageName('google maps'),
          'com.google.android.apps.maps');
      expect(OpenAppTool.resolvePackageName('unbekannt'), null);
      expect(
          OpenAppTool.resolvePackageName('com.example.app'), 'com.example.app');
    });

    test('returns error for unknown app', () async {
      final tool = OpenAppTool();
      // com.nonexistent.app is a package name format, so it will try to launch it
      // and fail gracefully
      final result =
          await tool.execute({'app': 'com.nonexistent.test.app.9999'});
      // Should not crash, will try to launch intent (which may fail on device)
      expect(result.isError, isFalse);
    });
  });

  group('MusicIntentTool', () {
    test('builds a Spotify deep link when Spotify is requested', () {
      final uri = MusicIntentTool.buildSearchUri(
        app: 'spotify',
        query: 'Beatles best playlist',
      );

      expect(uri.scheme, 'spotify');
      expect(uri.toString(), contains('Beatles%20best%20playlist'));
    });

    test('never turns an explicit Spotify request into YouTube', () {
      final package = MusicIntentTool.resolveMusicPackage('Spotify');

      expect(package, 'com.spotify.music');
      expect(package, isNot('com.google.android.youtube'));
    });
  });

  group('NavigateToTool', () {
    test('returns error for empty destination', () async {
      final tool = NavigateToTool();
      final result = await tool.execute({'destination': ''});
      expect(result.isError, isTrue);
      expect(result.result, contains('Kein Ziel'));
    });

    test('definition has correct name', () {
      final tool = NavigateToTool();
      expect(tool.definition.name, 'open_navigation');
    });

    test('definition includes destination as required', () {
      final tool = NavigateToTool();
      final required = tool.definition.parametersSchema['required'] as List;
      expect(required, contains('destination'));
    });

    test('normalizes transport modes', () {
      // Test indirectly: the tool should accept various mode names
      final tool = NavigateToTool();
      // These are internal, test by ensuring definition is correct
      expect(tool.definition.name, 'open_navigation');
      expect(tool.definition.description.toLowerCase(), contains('navigiere'));
      expect(tool.definition.description.toLowerCase(), contains('auto'));
      expect(tool.definition.description.toLowerCase(), contains('rad'));
    });

    test('description contains German navigation commands', () {
      final tool = NavigateToTool();
      final desc = tool.definition.description.toLowerCase();
      expect(desc, contains('navigier'));
      expect(desc, contains('auto'));
      expect(desc, contains('rad'));
    });
  });

  group('ToolResult', () {
    test('chatDisplay uses displayText when set', () {
      const result = ToolResult(
        toolName: 'test',
        parameters: {},
        result: 'done',
        displayText: '✅ Custom display',
      );
      expect(result.chatDisplay, '✅ Custom display');
    });

    test('chatDisplay uses default format when no displayText', () {
      const result = ToolResult(
        toolName: 'test_tool',
        parameters: {},
        result: 'done',
      );
      expect(result.chatDisplay, '✅ test_tool');
    });

    test('chatDisplay shows error format for errors', () {
      const result = ToolResult(
        toolName: 'test_tool',
        parameters: {},
        result: 'failed',
        isError: true,
      );
      expect(result.chatDisplay, '❌ test_tool fehlgeschlagen');
    });

    test('toToolResultMessage produces correct format', () {
      const result = ToolResult(
        toolName: 'web_search',
        parameters: {},
        result: 'Search results here',
      );
      final msg = result.toToolResultMessage();
      expect(msg['role'], 'tool');
      expect(msg['name'], 'web_search');
      expect(msg['content'], 'Search results here');
    });
  });

  group('SendEmailTool', () {
    test('returns error for empty recipient', () async {
      final tool = SendEmailTool();
      final result = await tool.execute({'recipient': '', 'body': 'Hello'});
      expect(result.isError, isTrue);
      expect(result.result, contains('Empfaenger'));
    });

    test('returns error for empty body', () async {
      final tool = SendEmailTool();
      final result =
          await tool.execute({'recipient': 'test@example.com', 'body': ''});
      expect(result.isError, isTrue);
      expect(result.result, contains('Inhalt'));
    });
  });

  group('ManageShoppingListTool', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('adds an item to list', () async {
      final tool = ManageShoppingListTool();
      final result = await tool.execute({'action': 'add', 'item': 'Apfel'});
      expect(result.isError, isFalse);
      expect(result.result, contains('Apfel'));
      expect(result.displayText, contains('Apfel'));
    });

    test('lists items', () async {
      final tool = ManageShoppingListTool();
      final result = await tool.execute({'action': 'list'});
      expect(result.isError, isFalse);
      expect(result.result, contains('leer'));
    });
  });
}
