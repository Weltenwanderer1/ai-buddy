import 'tool_definition.dart';
import 'tool_result.dart';

/// Interface that all tools must implement.
abstract class ToolInterface {
  /// The tool definition (name, description, parameters schema).
  ToolDefinition get definition;

  /// Execute the tool with the given parameters.
  Future<ToolResult> execute(Map<String, dynamic> parameters);
}
