import 'tool_interface.dart';
import 'tool_definition.dart';
import 'tool_result.dart';

/// Reads the current AI-Buddy configuration.
class ReadConfigTool implements ToolInterface {
  static const _definition = ToolDefinition(
    name: 'read_config',
    description:
        'Liest die aktuelle AI-Buddy-Konfiguration (Persona-Name, Modell, TTS-Einstellungen, etc.). Nutze dies, um die aktuellen Einstellungen zu erfahren.',
    parametersSchema: {
      'type': 'object',
      'properties': {},
      'required': [],
    },
  );

  @override
  ToolDefinition get definition => _definition;

  /// Callback to read config. Registered by the app at startup.
  static Map<String, dynamic> Function()? readConfigCallback;

  @override
  Future<ToolResult> execute(Map<String, dynamic> parameters) async {
    if (readConfigCallback == null) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Fehler: Konfiguration nicht verfügbar.',
        isError: true,
        displayText: '❌ Config nicht verfügbar',
      );
    }

    try {
      final config = readConfigCallback!();
      final buffer = StringBuffer('Aktuelle Konfiguration:\n');
      for (final entry in config.entries) {
        buffer.writeln('  ${entry.key}: ${entry.value}');
      }
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: buffer.toString(),
        displayText: '⚙️ Konfiguration gelesen',
      );
    } catch (e) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Fehler beim Lesen der Konfiguration: $e',
        isError: true,
        displayText: '❌ Config-Lesefehler',
      );
    }
  }
}
