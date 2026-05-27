import 'package:flutter_test/flutter_test.dart';
import 'package:ai_buddy/services/tool_call_parser.dart';

void main() {
  group('ToolCallParser', () {
    test('returns empty list in local-only mode', () {
      final calls = ToolCallParser.parseInline('anything', null);
      expect(calls, isEmpty);
    });

    test('stripFunctionCallTags returns input unchanged', () {
      final result = ToolCallParser.stripFunctionCallTags('hello world');
      expect(result, 'hello world');
    });
  });
}
