import 'tool_interface.dart';
import 'tool_definition.dart';
import 'tool_result.dart';

/// Updates an AI-Buddy configuration value.
class UpdateConfigTool implements ToolInterface {
  static const _definition = ToolDefinition(
    name: 'update_config',
    description:
        'Ändert einen Konfigurationswert von AI-Buddy (z.B. Persona-Name, Modell, TTS-Einstellungen). Erlaubte Schlüssel: persona_name, default_model, tts_engine, temperature, memory_ttl_minutes, memory_promotion_threshold, max_history.',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'key': {
          'type': 'string',
          'description':
              'Der Konfigurationsschlüssel (z.B. "persona_name", "default_model", "tts_engine", "temperature")',
        },
        'value': {
          'type': 'string',
          'description': 'Der neue Wert als String',
        },
      },
      'required': ['key', 'value'],
    },
  );

  @override
  ToolDefinition get definition => _definition;

  /// Allowed config keys that can be updated via this tool.
  static const _allowedKeys = {
    'persona_name',
    'default_model',
    'tts_engine',
    'temperature',
    'memory_ttl_minutes',
    'memory_promotion_threshold',
    'max_history',
  };

  /// Callback to update a config value. Registered by the app at startup.
  static Future<bool> Function(String key, dynamic value)?
      updateConfigCallback;

  @override
  Future<ToolResult> execute(Map<String, dynamic> parameters) async {
    final key = parameters['key'] as String? ?? '';
    final value = parameters['value'] as String? ?? '';

    if (key.isEmpty) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Fehler: Kein Konfigurationsschlüssel angegeben.',
        isError: true,
        displayText: '❌ Kein Schlüssel',
      );
    }

    if (!_allowedKeys.contains(key)) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result:
            'Fehler: Schlüssel "$key" ist nicht erlaubt. Erlaubt: ${_allowedKeys.join(", ")}',
        isError: true,
        displayText: '❌ Schlüssel nicht erlaubt',
      );
    }

    if (updateConfigCallback == null) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Fehler: Konfigurations-Update nicht verfügbar.',
        isError: true,
        displayText: '❌ Config-Update nicht verfügbar',
      );
    }

    try {
      final success = await updateConfigCallback!(key, value);
      if (success) {
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: 'Konfiguration "$key" auf "$value" geändert.',
          displayText: '⚙️ $key → $value',
        );
      } else {
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: 'Fehler: Konfiguration "$key" konnte nicht geändert werden.',
          isError: true,
          displayText: '❌ Config-Änderung fehlgeschlagen',
        );
      }
    } catch (e) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Fehler beim Ändern der Konfiguration: $e',
        isError: true,
        displayText: '❌ Config-Fehler',
      );
    }
  }
}