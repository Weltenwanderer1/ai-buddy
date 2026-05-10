/// Definition of a tool that can be called by the LLM.
class ToolDefinition {
  final String name;
  final String description;
  final Map<String, dynamic> parametersSchema;

  const ToolDefinition({
    required this.name,
    required this.description,
    required this.parametersSchema,
  });

  /// Convert to the JSON format expected by the Ollama/OpenAI API.
  Map<String, dynamic> toApiJson() => {
        'type': 'function',
        'function': {
          'name': name,
          'description': description,
          'parameters': parametersSchema,
        },
      };
}