import 'package:flutter_test/flutter_test.dart';
import 'package:ai_buddy/services/tool_call_parser.dart';

void main() {
  group('ToolCallParser', () {
    test('parses XML call: syntax', () {
      final text = '<tool_call>call:open_app{app_name: "Spotify"}</tool_call>';
      final calls = ToolCallParser.parseInline(text, null);
      // XML call: pattern should take precedence over plain call: inside tags
      expect(calls.length, 1);
      expect(calls.first['name'], 'open_app');
      expect(calls.first['arguments'], {'app_name': 'Spotify'});
    });

    test('parses XML with name attribute', () {
      final text = '<tool_call name="weather">{"city": "Wien"}</tool_call>';
      final calls = ToolCallParser.parseInline(text, null);
      expect(calls.length, 1);
      expect(calls.first['name'], 'weather');
      expect(calls.first['arguments'], {'city': 'Wien'});
    });

    test('parses plain call: syntax without XML', () {
      final text = 'call:search_memories{query: "Arzttermin"}';
      final calls = ToolCallParser.parseInline(text, null);
      expect(calls.length, 1);
      expect(calls.first['name'], 'search_memories');
      expect(calls.first['arguments'], {'query': 'Arzttermin'});
    });

    test('parses JSON code block', () {
      final text = '```json\n{"tool": "open_app", "arguments": {"app_name": "Maps"}}\n```';
      final calls = ToolCallParser.parseInline(text, null);
      expect(calls.length, 1);
      expect(calls.first['name'], 'open_app');
      expect(calls.first['arguments'], {'app_name': 'Maps'});
    });

    test('handles mixed content and strips tags leaving natural text', () {
      final text = 'Ich öffne die App. <tool_call>call:open_app{app_name: "YouTube"}</tool_call> Viel Spaß!';
      final stripped = ToolCallParser.stripFunctionCallTags(text);
      // Normalize whitespace for assertion — exact spacing between tags isn't important
      final normalized = stripped.replaceAll(RegExp(r' +'), ' ').trim();
      expect(normalized, 'Ich öffne die App. Viel Spaß!');
    });

    test('returns empty list for plain text without tool calls', () {
      final calls = ToolCallParser.parseInline('Hallo, wie geht es dir?', null);
      expect(calls, isEmpty);
    });

    test('handles multiple tool calls in same text without double-parsing', () {
      final text = '<tool_call>call:open_app{app_name: "Spotify"}</tool_call>'
          ' und dann <tool_call name="navigation">{"destination": "Wien"}</tool_call>';
      final calls = ToolCallParser.parseInline(text, null);
      expect(calls.length, 2);
      expect(calls[0]['name'], 'open_app');
      expect(calls[1]['name'], 'navigation');
    });

    test('handles malformed args gracefully', () {
      final text = '<tool_call>call:broken{garbage here}</tool_call>';
      final calls = ToolCallParser.parseInline(text, null);
      // Should find exactly one call (malformed args = empty map, but not a crash)
      expect(calls.length, 1);
      expect(calls.first['name'], 'broken');
      expect(calls.first['arguments'], isA<Map<String, dynamic>>());
    });

    test('stripFunctionCallTags removes all known formats', () {
      final text = 'Hallo. call:open_app{app_name: "Spotify"} '
          '<tool_call name="x">{"y": 1}</tool_call> '
          '```json\n{"tool": "z", "arguments": {}}\n``` '
          'Ende.';
      final stripped = ToolCallParser.stripFunctionCallTags(text);
      // Normalize whitespace — exact count between remains isn't behavior-critical
      final normalized = stripped.replaceAll(RegExp(r' +'), ' ').trim();
      expect(normalized, 'Hallo. Ende.');
    });

    test('empty string returns empty list', () {
      final calls = ToolCallParser.parseInline('', null);
      expect(calls, isEmpty);
    });
  });
}
