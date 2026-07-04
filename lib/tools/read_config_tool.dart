import 'tool_interface.dart';
import 'tool_definition.dart';
import 'tool_result.dart';

/// Reads the current AI-Buddy configuration.
class ReadConfigTool implements ToolInterface {
  static const _definition = ToolDefinition(
    name: 'read_config',
    description: 'Liest die AI-Buddy-Konfiguration. Optional: key fuer Einzelwert.',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'key': {
          'type': 'string',
          'description': 'Optionaler Schlüssel — gibt nur diesen Wert zurück (z.B. persona_name, tts_engine, ollama_model).',
        },
      },
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
      final key = parameters['key'] as String?;

      if (key != null && key.isNotEmpty) {
        final value = config[key];
        if (value == null) {
          return ToolResult(
            toolName: definition.name,
            parameters: parameters,
            result: 'Schlüssel "$key" nicht gefunden. Verfügbare Schlüssel: ${config.keys.join(", ")}',
            displayText: '⚙️ Schlüssel "$key" nicht gefunden',
          );
        }
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: '$key: $value',
          displayText: '⚙️ $key = $value',
        );
      }

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