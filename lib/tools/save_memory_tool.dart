import '../services/memory_service.dart';
import 'tool_interface.dart';
import 'tool_definition.dart';
import 'tool_result.dart';

class SaveMemoryTool implements ToolInterface {
  final MemoryService _memory;
  SaveMemoryTool(this._memory);

  static const _definition = ToolDefinition(
    name: 'save_memory',
    description: 'Speichere wichtige Info dauerhaft. Tier: "core" fuer identitaetspraegend, "long_term" fuer Fakten/Vorlieben.',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'content': {
          'type': 'string',
          'description': 'Die zu speichernde Information.',
        },
        'tier': {
          'type': 'string',
          'enum': ['core', 'long_term'],
          'description': 'Speicher-Tier: "core" für identitätsprägend (wer ist der Nutzer, Beziehung, fundamentale Fakten), "long_term" für wichtige Fakten und Vorlieben.',
        },
        'source': {
          'type': 'string',
          'description': 'Quelle der Information (z.B. "user", "conversation", "extracted"). Standard: "extracted".',
        },
      },
      'required': ['content', 'tier'],
    },
  );

  @override
  ToolDefinition get definition => _definition;

  @override
  Future<ToolResult> execute(Map<String, dynamic> parameters) async {
    final content = parameters['content'] as String? ?? '';
    final tier = parameters['tier'] as String? ?? 'long_term';
    final source = parameters['source'] as String? ?? 'extracted';

    if (content.isEmpty) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Kein Inhalt zum Speichern.',
        displayText: '❌ Leere Information',
        isError: true,
      );
    }

    if (tier == 'core') {
      await _memory.addCore(content, source: source);
    } else {
      await _memory.addLongTerm(content, source: source);
    }

    return ToolResult(
      toolName: definition.name,
      parameters: parameters,
      result: 'Gespeichert als $tier: "$content"',
      displayText: '💾 Gespeichert ($tier)',
    );
  }
}
