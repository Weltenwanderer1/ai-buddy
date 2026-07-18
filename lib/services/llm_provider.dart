import 'dart:async';

/// Never hide real tool output behind a generic success sentence. Some models
/// emit no final text after a successful tool call; in that case the actual
/// tool results are the only grounded answer we have.
String resolveToolLoopText({
  required String modelContent,
  required List<String> toolResults,
}) {
  if (modelContent.trim().isNotEmpty) return modelContent;
  final groundedResults = toolResults
      .map((result) => result.trim())
      .where((result) => result.isNotEmpty)
      .toList();
  if (groundedResults.isNotEmpty) return groundedResults.join('\n\n');
  return 'Tool-Aufruf ausgeführt.';
}

/// Unified interface for all LLM providers (local, cloud, OpenRouter).
///
/// Implementations encapsulate their own model lifecycle, API details,
/// and tool-call loops. ChatService only sees this interface.
abstract class LlmProvider {
  /// Human-readable provider name (e.g. "Gemma 4 E4B", "Ollama Cloud").
  String get displayName;

  /// Whether this provider is ready to accept requests.
  bool get isAvailable;

  /// Send a chat message and get back a complete text response.
  /// If [toolDefinitions] and [onToolCall] are provided, the provider
  /// handles the tool-call loop internally.
  Future<String> chat({
    required String systemPrompt,
    required List<Map<String, dynamic>> messages,
    double temperature = 0.7,
    List<Map<String, dynamic>>? toolDefinitions,
    Future<String> Function(String toolName, Map<String, dynamic> args)? onToolCall,
    void Function(String toolName)? onToolActivity,
    int maxToolRounds = 3,
  });

  /// Stream a chat response token-by-token.
  /// If [toolDefinitions] and [onToolCall] are provided, the provider
  /// executes tool rounds between streamed answers (where supported).
  Stream<String> streamChat({
    required String systemPrompt,
    required List<Map<String, dynamic>> messages,
    double temperature = 0.7,
    List<Map<String, dynamic>>? toolDefinitions,
    Future<String> Function(String toolName, Map<String, dynamic> args)? onToolCall,
    void Function(String toolName)? onToolActivity,
    int maxToolRounds = 3,
  });
}
