import 'dart:convert';

import 'ollama_cloud_service.dart';
import '../tools/tool_registry.dart';

/// Robust parser for model-emitted fallback tool calls.
///
/// Primary path is native OpenAI/Ollama `tool_calls`. Some local/proxy models
/// instead emit inline XML/JSON. We accept those as a compatibility layer, but
/// ChatService still asks the model to choose a tool semantically first.
class ToolCallParser {
  static List<ToolCall> parseInline(String content, ToolRegistry? registry) {
    final calls = <ToolCall>[];
    var index = 0;

    calls.addAll(_parseXml(content, registry, () => 'inline_tool_${index++}'));
    calls.addAll(
        _parseJsonBlocks(content, registry, () => 'inline_tool_${index++}'));

    final seen = <String>{};
    return calls.where((call) {
      final key = '${call.name}:${jsonEncode(call.arguments)}';
      return seen.add(key);
    }).toList(growable: false);
  }

  static List<ToolCall> _parseXml(
    String content,
    ToolRegistry? registry,
    String Function() nextId,
  ) {
    if (!content.contains('<function_calls') && !content.contains('<invoke')) {
      return const [];
    }
    final calls = <ToolCall>[];
    final invokeRegex = RegExp(
      r'<invoke\s+name=["\x27]([^"\x27]+)["\x27]\s*>([\s\S]*?)</invoke>',
      caseSensitive: false,
    );
    final parameterRegex = RegExp(
      r'<parameter\s+name=["\x27]([^"\x27]+)["\x27]\s*>([\s\S]*?)</parameter>',
      caseSensitive: false,
    );

    for (final invoke in invokeRegex.allMatches(content)) {
      final name = invoke.group(1)?.trim() ?? '';
      if (name.isEmpty || registry?.hasTool(name) != true) continue;
      final args = <String, dynamic>{};
      for (final parameter
          in parameterRegex.allMatches(invoke.group(2) ?? '')) {
        final key = parameter.group(1)?.trim() ?? '';
        final value = _stripInlineToolMarkup(parameter.group(2) ?? '');
        if (key.isNotEmpty) args[key] = value;
      }
      calls.add(ToolCall(
          id: nextId(), type: 'function', name: name, arguments: args));
    }
    return calls;
  }

  static List<ToolCall> _parseJsonBlocks(
    String content,
    ToolRegistry? registry,
    String Function() nextId,
  ) {
    final snippets = <String>[];

    final fenced =
        RegExp(r'```(?:json)?\s*([\s\S]*?)```', caseSensitive: false);
    for (final match in fenced.allMatches(content)) {
      snippets.add(match.group(1) ?? '');
    }

    final tagged = RegExp(r'<![CDATA[\s*([\s\S]*?)\s*]]>',
        caseSensitive: false);
    for (final match in tagged.allMatches(content)) {
      snippets.add(match.group(1) ?? '');
    }

    snippets.add(content.trim());

    final calls = <ToolCall>[];
    for (final snippet in snippets) {
      final decoded = _decodeJsonObjectOrArray(snippet);
      if (decoded == null) continue;
      final rawCalls = decoded is List ? decoded : [decoded];
      for (final raw in rawCalls) {
        if (raw is! Map) continue;
        final normalized = raw.cast<String, dynamic>();
        final name = (normalized['name'] ??
                    normalized['tool'] ??
                    normalized['tool_name'] ??
                    normalized['function'])
                ?.toString()
                .trim() ??
            '';
        if (name.isEmpty || registry?.hasTool(name) != true) continue;
        final rawArgs = normalized['arguments'] ??
            normalized['parameters'] ??
            normalized['args'] ??
            <String, dynamic>{};
        final args = _normalizeArgs(rawArgs);
        calls.add(ToolCall(
            id: nextId(), type: 'function', name: name, arguments: args));
      }
    }
    return calls;
  }

  static dynamic _decodeJsonObjectOrArray(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    final candidates = <String>[trimmed];
    final objectStart = trimmed.indexOf('{');
    final objectEnd = trimmed.lastIndexOf('}');
    if (objectStart >= 0 && objectEnd > objectStart) {
      candidates.add(trimmed.substring(objectStart, objectEnd + 1));
    }
    final arrayStart = trimmed.indexOf('[');
    final arrayEnd = trimmed.lastIndexOf(']');
    if (arrayStart >= 0 && arrayEnd > arrayStart) {
      candidates.add(trimmed.substring(arrayStart, arrayEnd + 1));
    }
    for (final candidate in candidates) {
      try {
        return jsonDecode(candidate);
      } catch (_) {
        // try next candidate
      }
    }
    return null;
  }

  static Map<String, dynamic> _normalizeArgs(dynamic rawArgs) {
    if (rawArgs is Map<String, dynamic>) return rawArgs;
    if (rawArgs is Map) return rawArgs.cast<String, dynamic>();
    if (rawArgs is String) {
      try {
        final decoded = jsonDecode(rawArgs);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) return decoded.cast<String, dynamic>();
      } catch (_) {}
    }
    return <String, dynamic>{};
  }

  static String _stripInlineToolMarkup(String value) {
    return value
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .trim();
  }

  /// Strip all <function_calls>...</function_calls> blocks from text so
  /// they don't appear as raw XML in the chat UI.
  static String stripFunctionCallTags(String content) {
    var cleaned = content.replaceAll(
      RegExp(r'<function_calls>[\s\S]*?</function_calls>', caseSensitive: false),
      '',
    );
    cleaned = cleaned.replaceAll(
      RegExp(r'<invoke\s+name=["\x27][^"\x27]+["\x27]\s*>[\s\S]*?</invoke>', caseSensitive: false),
      '',
    );
    return cleaned.trim();
  }
}