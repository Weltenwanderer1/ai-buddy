import 'package:flutter_test/flutter_test.dart';
import 'package:ai_buddy/services/tool_call_parser.dart';
import 'package:ai_buddy/tools/tool_registry.dart';

void main() {
  group('ToolCallParser', () {
    final registry = ToolRegistry.createDefault();

    test('parses inline XML tool calls', () {
      final calls = ToolCallParser.parseInline(
        '<function_calls><invoke name="open_app"><parameter name="app">Spotify</parameter></invoke></function_calls>',
        registry,
      );
      expect(calls, hasLength(1));
      expect(calls.single.name, 'open_app');
      expect(calls.single.arguments['app'], 'Spotify');
    });

    test('parses fenced JSON tool calls', () {
      final calls = ToolCallParser.parseInline(
        '```json\n{"name":"open_navigation","arguments":{"destination":"Berlin Hauptbahnhof","mode":"auto"}}\n```',
        registry,
      );
      expect(calls, hasLength(1));
      expect(calls.single.name, 'open_navigation');
      expect(calls.single.arguments['destination'], 'Berlin Hauptbahnhof');
    });

    test('ignores unknown tools', () {
      final calls = ToolCallParser.parseInline(
        '{"name":"delete_everything","arguments":{}}',
        registry,
      );
      expect(calls, isEmpty);
    });
  });
}
