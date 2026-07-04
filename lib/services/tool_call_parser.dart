import 'dart:convert';

/// Reaktiviert: Tool Call Parser als Fallback für Function Calling.
///
/// flutter_gemma 0.12.8 hat native Function Calling via `FunctionCallResponse`,
/// aber wenn das Modell Text-Antworten mit Inline-Tool-Calls zurückgibt,
/// kann dieser Parser sie extrahieren.
///
/// Unterstützt:
/// - XML-Tags: `<tool_call name="...">{"arg": "val"}</tool_call>`
/// - JSON-Blocks: `{"tool": "name", "arguments": {...}}`
/// - Markdown-Code-Blocks mit JSON
class ToolCallParser {
  /// Parse all inline tool calls from a text response.
  /// Avoids double-parsing when a single tool call is matched by multiple patterns.
  static List<Map<String, dynamic>> parseInline(
      String content, dynamic registry) {
    final calls = <Map<String, dynamic>>[];
    if (content.isEmpty) return calls;

    final matchedSpans = <({int start, int end})>[];

    bool overlaps(int s, int e) =>
        matchedSpans.any((ms) => (ms.start < e && s < ms.end));

    // 1. Parse XML-style tool calls: <tool_call>call:open_app{app_name: "..."}</tool_call>
    final xmlCallPattern = RegExp(
      r'<tool_call>\s*call:([^\{]+)\{([^}]+)\}\s*</tool_call>',
      caseSensitive: false,
      dotAll: true,
    );
    for (final match in xmlCallPattern.allMatches(content)) {
      if (overlaps(match.start, match.end)) continue;
      matchedSpans.add((start: match.start, end: match.end));
      final name = match.group(1)?.trim();
      final argsStr = match.group(2);
      if (name == null || name.isEmpty) continue;
      final args = _parseArgs(argsStr ?? '');
      calls.add({'name': name, 'arguments': args});
    }

    // 1b. Parse XML-style with name attribute: <tool_call name="weather">{"city": "Wien"}</tool_call>
    final xmlPattern = RegExp(
      r'<tool_call\s+name="([^"]+)"\u003e\s*(.*?)\s*</tool_call>',
      caseSensitive: false,
      dotAll: true,
    );
    for (final match in xmlPattern.allMatches(content)) {
      if (overlaps(match.start, match.end)) continue;
      matchedSpans.add((start: match.start, end: match.end));
      final name = match.group(1)?.trim();
      final jsonStr = match.group(2)?.trim();
      if (name == null || name.isEmpty) continue;
      Map<String, dynamic> args = {};
      if (jsonStr != null && jsonStr.isNotEmpty) {
        try {
          args = jsonDecode(jsonStr) as Map<String, dynamic>;
        } catch (_) {
          args = {'input': jsonStr};
        }
      }
      calls.add({'name': name, 'arguments': args});
    }

    // 1c. Parse plain call: syntax without XML tags: call:open_app{app_name: "..."}
    final plainCallPattern = RegExp(
      r'call:([^\{<\n]+)\{([^}]*)\}',
      caseSensitive: false,
      dotAll: true,
    );
    for (final match in plainCallPattern.allMatches(content)) {
      if (overlaps(match.start, match.end)) continue;
      matchedSpans.add((start: match.start, end: match.end));
      final name = match.group(1)?.trim();
      final argsStr = match.group(2);
      if (name == null || name.isEmpty) continue;
      final args = _parseArgs(argsStr ?? '');
      calls.add({'name': name, 'arguments': args});
    }

    // 2. Parse JSON-style tool calls in code blocks
    final jsonBlockPattern = RegExp(
      r'```(?:json)?\s*\n?\s*(\{[\s\S]*?\})\s*\n?```',
      caseSensitive: false,
    );
    for (final match in jsonBlockPattern.allMatches(content)) {
      if (overlaps(match.start, match.end)) continue;
      matchedSpans.add((start: match.start, end: match.end));
      final jsonStr = match.group(1);
      if (jsonStr == null) continue;
      try {
        final obj = jsonDecode(jsonStr) as Map<String, dynamic>;
        final tool = obj['tool'] as String? ?? obj['name'] as String? ?? obj['function'] as String?;
        final args = obj['arguments'] as Map<String, dynamic>? ?? obj['params'] as Map<String, dynamic>? ?? {};
        if (tool != null && tool.isNotEmpty) {
          calls.add({'name': tool, 'arguments': args});
        }
      } catch (_) {
        // Not valid JSON — skip
      }
    }

    // 3. Parse raw JSON tool calls: {"name": "tool_name", "arguments": {...}}
    //    Some LLMs output this format directly instead of using the API's structured tool_calls.
    // Arguments may contain one level of nested objects, e.g.
    // {"name": "x", "arguments": {"params": {"a": 1}}}.
    final rawJsonToolPattern = RegExp(
      r'\{\s*"name"\s*:\s*"([^"]+)"\s*,\s*"arguments"\s*:\s*(\{(?:[^{}]|\{[^{}]*\})*\})\s*\}',
      dotAll: true,
    );
    for (final match in rawJsonToolPattern.allMatches(content)) {
      if (overlaps(match.start, match.end)) continue;
      final name = match.group(1)?.trim();
      final argsStr = match.group(2);
      if (name == null || name.isEmpty) continue;
      Map<String, dynamic> args = {};
      if (argsStr != null && argsStr.isNotEmpty) {
        try {
          args = jsonDecode(argsStr) as Map<String, dynamic>;
        } catch (_) {
          args = _parseArgs(argsStr);
        }
      }
      calls.add({'name': name, 'arguments': args});
      matchedSpans.add((start: match.start, end: match.end));
    }

    // 4. Parse generic loose JSON objects that look like tool calls
    //    Catches {"tool": "...", "arguments": {...}} etc.
    final looseJsonPattern = RegExp(
      r'\{[\s\S]*?(?:"tool"|"name"|"function")[\s\S]*?\}',
    );
    for (final match in looseJsonPattern.allMatches(content)) {
      if (overlaps(match.start, match.end)) continue;
      // Only try if no other patterns matched yet
      if (calls.isNotEmpty) continue;

      try {
        final obj = jsonDecode(match.group(0)!) as Map<String, dynamic>;
        final tool = obj['tool'] as String? ?? obj['name'] as String? ?? obj['function'] as String?;
        final args = obj['arguments'] as Map<String, dynamic>? ?? obj['params'] as Map<String, dynamic>? ?? {};
        if (tool != null && tool.isNotEmpty) {
          calls.add({'name': tool, 'arguments': args});
        }
      } catch (_) {
        // Skip invalid JSON
      }
    }

    return calls;
  }

  /// Strip function call tags from a response, keeping only the human-readable text.
  static String stripFunctionCallTags(String content) {
    if (content.isEmpty) return content;

    var cleaned = content;

    // Remove XML tool calls with call: syntax
    cleaned = cleaned.replaceAllMapped(
      RegExp(
        r'<tool_call>\s*call:[^\{]+\{[^}]*\}\s*</tool_call>',
        caseSensitive: false,
        dotAll: true,
      ),
      (_) => '',
    );

    // Remove XML tool calls with name attribute
    cleaned = cleaned.replaceAllMapped(
      RegExp(
        r'<tool_call\s+name="[^"]+"\u003e\s*.*?\s*</tool_call>',
        caseSensitive: false,
        dotAll: true,
      ),
      (_) => '',
    );

    // Remove plain call: syntax
    cleaned = cleaned.replaceAllMapped(
      RegExp(
        r'call:[^\{<\n]+\{[^}]*\}',
        caseSensitive: false,
        dotAll: true,
      ),
      (_) => '',
    );

    // Remove JSON code blocks that contain tool calls
    cleaned = cleaned.replaceAllMapped(
      RegExp(
        r'```(?:json)?\s*\n?\s*\{[\s\S]*?(?:"tool"|"name"|"function")[\s\S]*?\}\s*\n?```',
        caseSensitive: false,
      ),
      (_) => '',
    );

    // Remove raw JSON tool calls: {"name": "tool_name", "arguments": {...}}
    cleaned = cleaned.replaceAllMapped(
      RegExp(
        r'\{\s*"name"\s*:\s*"[^"]+"\s*,\s*"arguments"\s*:\s*\{(?:[^{}]|\{[^{}]*\})*\}\s*\}',
        dotAll: true,
      ),
      (_) => '',
    );

    return cleaned.trim();
  }

  /// Parse key:value arguments from Gemma-style call syntax.
  /// Example: `app_name: "Spotify"` → {app_name: Spotify}
  static Map<String, dynamic> _parseArgs(String argsStr) {
    final args = <String, dynamic>{};
    if (argsStr.isEmpty) return args;

    // Pattern: key: value (value runs until comma or closing brace)
    final pattern = RegExp(r'(\w+):\s*([^,}]+)');
    for (final match in pattern.allMatches(argsStr)) {
      final key = match.group(1);
      var value = match.group(2)?.trim() ?? '';
      // Strip surrounding quotes
      if (value.startsWith('"') && value.endsWith('"')) {
        value = value.substring(1, value.length - 1);
      } else if (value.startsWith("'") && value.endsWith("'")) {
        value = value.substring(1, value.length - 1);
      }
      if (key != null && value.isNotEmpty) {
        args[key] = value;
      }
    }
    return args;
  }
}
