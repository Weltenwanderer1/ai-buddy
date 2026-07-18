import 'dart:async';
import 'package:flutter/foundation.dart';
import 'llm_provider.dart';
import 'ollama_cloud_service.dart';

/// LLM Provider wrapper around [OllamaCloudService].
///
/// Handles Ollama native, OpenAI-compatible, and OpenRouter endpoints.
/// Tool-call loops are managed internally using the cloud API's tool support.
class OllamaCloudProvider implements LlmProvider {
  final OllamaCloudService _cloud;

  OllamaCloudProvider(this._cloud);

  @override
  String get displayName {
    final base = _cloud.baseUrl.toLowerCase();
    if (base.contains('openrouter')) {
      return 'OpenRouter (${_cloud.defaultModel})';
    } else if (base.contains('openai.com')) {
      return 'OpenAI (${_cloud.defaultModel})';
    }
    return 'Ollama Cloud (${_cloud.defaultModel})';
  }

  @override
  bool get isAvailable => _cloud.baseUrl.isNotEmpty && _cloud.apiKey.isNotEmpty;

  @override
  Future<String> chat({
    required String systemPrompt,
    required List<Map<String, dynamic>> messages,
    double temperature = 0.7,
    List<Map<String, dynamic>>? toolDefinitions,
    Future<String> Function(String toolName, Map<String, dynamic> args)? onToolCall,
    void Function(String toolName)? onToolActivity,
    int maxToolRounds = 3,
  }) async {
    // Build cloud messages — preserve String OR List content (vision multi-content)
    final cloudMessages = messages.map((m) => {
      'role': m['role'] as String,
      'content': m['content'],
    }).toList();

    if (toolDefinitions != null &&
        toolDefinitions.isNotEmpty &&
        onToolCall != null) {
      // Tool-enabled path
      final chatResponse = await _cloud.chatWithTools(
        systemPrompt: systemPrompt,
        messages: cloudMessages.cast<Map<String, dynamic>>(),
        tools: toolDefinitions,
        temperature: temperature,
      );

      if (chatResponse.hasToolCalls) {
        return await _executeToolLoop(
          systemPrompt: systemPrompt,
          messages: cloudMessages.cast<Map<String, dynamic>>(),
          chatResponse: chatResponse,
          tools: toolDefinitions,
          onToolCall: onToolCall,
          onToolActivity: onToolActivity,
          maxRounds: maxToolRounds,
          temperature: temperature,
        );
      } else {
        return chatResponse.content;
      }
    } else {
      // Simple chat without tools
      return await _cloud.chat(
        systemPrompt: systemPrompt,
        messages: cloudMessages.cast<Map<String, dynamic>>(),
        temperature: temperature,
      );
    }
  }

  @override
  Stream<String> streamChat({
    required String systemPrompt,
    required List<Map<String, dynamic>> messages,
    double temperature = 0.7,
    List<Map<String, dynamic>>? toolDefinitions,
    Future<String> Function(String toolName, Map<String, dynamic> args)? onToolCall,
    void Function(String toolName)? onToolActivity,
    int maxToolRounds = 3,
  }) {
    // Build cloud messages — preserve String OR List content (vision multi-content)
    final cloudMessages = messages.map((m) => {
      'role': m['role'] as String,
      'content': m['content'],
    }).toList();

    if (toolDefinitions != null &&
        toolDefinitions.isNotEmpty &&
        onToolCall != null) {
      return _cloud.chatStreamWithTools(
        systemPrompt: systemPrompt,
        messages: cloudMessages.cast<Map<String, dynamic>>(),
        tools: toolDefinitions,
        onToolCall: onToolCall,
        onToolActivity: onToolActivity,
        maxToolRounds: maxToolRounds,
        temperature: temperature,
      );
    }

    return _cloud.chatStream(
      systemPrompt: systemPrompt,
      // Values are dynamic (content can be a list for vision), so casting to
      // Map<String,String> would throw a TypeError the moment the stream
      // iterates the messages.
      messages: cloudMessages.cast<Map<String, dynamic>>(),
      temperature: temperature,
    );
  }

  /// Execute a tool-call loop for cloud LLM responses.
  Future<String> _executeToolLoop({
    required String systemPrompt,
    required List<Map<String, dynamic>> messages,
    required ChatResponse chatResponse,
    required List<Map<String, dynamic>> tools,
    required Future<String> Function(String, Map<String, dynamic>) onToolCall,
    void Function(String toolName)? onToolActivity,
    required int maxRounds,
    required double temperature,
  }) async {
    var currentMessages = List<Map<String, dynamic>>.from(messages);
    var currentResponse = chatResponse;
    final toolResults = <String>[];
    int rounds = 0;

    while (currentResponse.hasToolCalls && rounds < maxRounds) {
      // Add assistant message with ALL tool calls to history (parallel calls)
      currentMessages.add(ToolCall.assistantMessageFor(currentResponse.toolCalls));

      for (final tc in currentResponse.toolCalls) {
        debugPrint('OllamaCloudProvider tool call: ${tc.name} args=${tc.arguments}');
        if (onToolActivity != null) onToolActivity(tc.name);

        String result;
        try {
          result = await onToolCall(tc.name, tc.arguments);
        } catch (e) {
          result = 'Fehler: $e';
        }
        // Trim result to reasonable length
        final trimmedResult = result.length > 2000
            ? '${result.substring(0, 2000)}...'
            : result;
        toolResults.add(trimmedResult);
        // Add tool result message
        currentMessages.add({
          'role': 'tool',
          'tool_call_id': tc.id,
          'content': trimmedResult,
        });
      }

      // Get next response from the model
      currentResponse = await _cloud.chatWithTools(
        systemPrompt: systemPrompt,
        messages: currentMessages,
        tools: tools,
        temperature: temperature,
      );
      rounds++;
    }

    return resolveToolLoopText(
      modelContent: currentResponse.content,
      toolResults: toolResults,
    );
  }
}
