/// Result of executing a tool call.
class ToolResult {
  final String toolName;
  final Map<String, dynamic> parameters;
  final String result;
  final bool isError;
  final String? displayText;

  const ToolResult({
    required this.toolName,
    required this.parameters,
    required this.result,
    this.isError = false,
    this.displayText,
  });

  /// Short text to display in the chat as a system bubble.
  String get chatDisplay => displayText ?? (isError ? '❌ $toolName fehlgeschlagen' : '✅ $toolName');

  /// Convert to the tool-result message format for the LLM.
  Map<String, dynamic> toToolResultMessage({String? toolCallId}) {
    final message = <String, dynamic>{
      'role': 'tool',
      'name': toolName,
      'content': result,
    };
    if (toolCallId != null && toolCallId.isNotEmpty) {
      message['tool_call_id'] = toolCallId;
    }
    return message;
  }
}