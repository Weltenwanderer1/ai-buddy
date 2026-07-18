import 'dart:async';
import 'package:flutter/foundation.dart';
import 'llm_provider.dart';
import 'anthropic_service.dart';
import 'ollama_cloud_service.dart' show ToolCall;

/// LLM Provider wrapper around [AnthropicService].
///
/// Handles the Anthropic Messages API tool-call loop internally.
/// Anthropic returns tool calls as content blocks (type: "tool_use"),
/// not as a separate `tool_calls` field like OpenAI.
class AnthropicProvider implements LlmProvider {
  final AnthropicService _service;

  AnthropicProvider(this._service);

  @override
  String get displayName => 'Anthropic (${_service.defaultModel})';

  @override
  bool get isAvailable =>
      _service.baseUrl.isNotEmpty && _service.apiKey.isNotEmpty;

  @override
  Future<String> chat({
    required String systemPrompt,
    required List<Map<String, dynamic>> messages,
    double temperature = 0.7,
    List<Map<String, dynamic>>? toolDefinitions,
    Future<String> Function(String toolName, Map<String, dynamic> args)?
        onToolCall,
    void Function(String toolName)? onToolActivity,
    int maxToolRounds = 3,
  }) async {
    if (toolDefinitions != null &&
        toolDefinitions.isNotEmpty &&
        onToolCall != null) {
      return await _executeToolLoop(
        systemPrompt: systemPrompt,
        messages: messages,
        tools: toolDefinitions,
        onToolCall: onToolCall,
        onToolActivity: onToolActivity,
        maxRounds: maxToolRounds,
        temperature: temperature,
      );
    }
    return await _service.chat(
      systemPrompt: systemPrompt,
      messages: messages,
      temperature: temperature,
    );
  }

  @override
  Stream<String> streamChat({
    required String systemPrompt,
    required List<Map<String, dynamic>> messages,
    double temperature = 0.7,
    List<Map<String, dynamic>>? toolDefinitions,
    Future<String> Function(String toolName, Map<String, dynamic> args)?
        onToolCall,
    void Function(String toolName)? onToolActivity,
    int maxToolRounds = 3,
  }) {
    // Streaming with tools not supported for Anthropic — fall back to
    // non-streaming chat which handles tools properly.
    if (toolDefinitions != null && toolDefinitions.isNotEmpty && onToolCall != null) {
      return _streamFromChat(
        systemPrompt, messages, temperature,
        toolDefinitions, onToolCall, onToolActivity, maxToolRounds);
    }
    return _service.chatStream(
      systemPrompt: systemPrompt,
      messages: messages,
      temperature: temperature,
    );
  }

  /// Emulate streaming by calling chat() and yielding the full result.
  Stream<String> _streamFromChat(
    String systemPrompt,
    List<Map<String, dynamic>> messages,
    double temperature,
    List<Map<String, dynamic>> tools,
    Future<String> Function(String, Map<String, dynamic>) onToolCall,
    void Function(String)? onToolActivity,
    int maxRounds,
  ) async* {
    final result = await _executeToolLoop(
      systemPrompt: systemPrompt,
      messages: messages,
      tools: tools,
      onToolCall: onToolCall,
      onToolActivity: onToolActivity,
      maxRounds: maxRounds,
      temperature: temperature,
    );
    yield result;
  }

  Future<String> _executeToolLoop({
    required String systemPrompt,
    required List<Map<String, dynamic>> messages,
    required List<Map<String, dynamic>> tools,
    required Future<String> Function(String, Map<String, dynamic>) onToolCall,
    void Function(String)? onToolActivity,
    required int maxRounds,
    required double temperature,
  }) async {
    var currentMessages = List<Map<String, dynamic>>.from(messages);
    final toolResults = <String>[];
    int rounds = 0;

    while (true) {
      final response = await _service.chatWithTools(
        systemPrompt: systemPrompt,
        messages: currentMessages,
        tools: tools,
        temperature: temperature,
      );

      if (!response.hasToolCalls || rounds >= maxRounds) {
        return resolveToolLoopText(
          modelContent: response.content,
          toolResults: toolResults,
        );
      }

      // Add assistant response with ALL tool calls to history (parallel calls)
      currentMessages.add(ToolCall.assistantMessageFor(response.toolCalls));

      for (final tc in response.toolCalls) {
        debugPrint('AnthropicProvider tool call: ${tc.name} args=${tc.arguments}');
        onToolActivity?.call(tc.name);

        String result;
        try {
          result = await onToolCall(tc.name, tc.arguments);
        } catch (e) {
          result = 'Fehler: $e';
        }
        final trimmed = result.length > 2000
            ? '${result.substring(0, 2000)}...'
            : result;
        toolResults.add(trimmed);
        currentMessages.add({
          'role': 'tool',
          'tool_call_id': tc.id,
          'content': trimmed,
        });
      }
      rounds++;
    }
  }
}