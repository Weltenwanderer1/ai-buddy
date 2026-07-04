import '../services/buddy_capabilities_service.dart';
import 'tool_interface.dart';
import 'tool_definition.dart';
import 'tool_result.dart';

class UpdateCapabilitiesTool implements ToolInterface {
  static const _definition = ToolDefinition(
    name: 'update_capabilities',
    description: 'Aktualisiert die Faehigkeiten-Liste. Kompakt halten.',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'text': {
          'type': 'string',
          'description': 'Neue Fähigkeiten-Liste als kompletter Text. '
              'Struktur: [KATEGORIE] + Bullet-Points. '
              'Max 2000 Zeichen.',
        },
      },
      'required': ['text'],
    },
  );

  final BuddyCapabilitiesService _capabilities;

  UpdateCapabilitiesTool(this._capabilities);

  @override
  ToolDefinition get definition => _definition;

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final text = params['text'] as String?;
    if (text == null || text.trim().isEmpty) {
      return ToolResult(
        toolName: definition.name,
        parameters: params,
        result: 'Fehler: text darf nicht leer sein.',
        isError: true,
      );
    }
    if (text.length > 3000) {
      return ToolResult(
        toolName: definition.name,
        parameters: params,
        result: 'Fehler: Text zu lang (${text.length} Zeichen, max 3000). Kürze die Liste.',
        isError: true,
      );
    }
    await _capabilities.setCapabilities(text);
    return ToolResult(
      toolName: definition.name,
      parameters: params,
      result: 'Fähigkeiten-Liste aktualisiert ✓ (${text.length} Zeichen).',
    );
  }
}
