import '../services/memory_service.dart';
import 'tool_interface.dart';
import 'tool_definition.dart';
import 'tool_result.dart';

/// Allows the LLM to search through user memories (short-term and long-term).
/// This gives the AI companion the ability to recall past conversations,
/// facts about the user, and historical context.
class SearchMemoriesTool implements ToolInterface {
  final MemoryService _memory;

  SearchMemoriesTool(this._memory);

  static const _definition = ToolDefinition(
    name: 'search_memories',
    description:
        'Durchsucht das Gedächtnis des Nutzers nach relevanten Informationen. '
        'Nutze dies, wenn der Nutzer nach vergangenen Gesprächen, '
        'gespeicherten Fakten oder früheren Ereignissen fragt. '
        'Auch nützlich um Kontext für personalisierte Antworten zu finden.',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'query': {
          'type': 'string',
          'description':
              'Die Suchanfrage. Kann ein Thema, Stichwort oder eine Frage sein (z.B. "Lieblingsessen", "Termine letzte Woche", "Geburtstag").',
        },
        'limit': {
          'type': 'integer',
          'description': 'Maximale Anzahl Ergebnisse (Standard: 10).',
        },
      },
      'required': ['query'],
    },
  );

  @override
  ToolDefinition get definition => _definition;

  @override
  Future<ToolResult> execute(Map<String, dynamic> parameters) async {
    final query = parameters['query'] as String? ?? '';
    final limit = (parameters['limit'] as int?) ?? 10;

    if (query.isEmpty) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Keine Suche möglich: leere Suchanfrage.',
        displayText: '🔍 Keine Suchanfrage',
        isError: true,
      );
    }

    final relevant = await _memory.getRelevantMemories(query, limit: limit);
    
    if (relevant.isEmpty) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Keine relevanten Erinnerungen gefunden für: "$query".',
        displayText: '🔍 Keine Erinnerungen zu "$query"',
      );
    }

    final lines = <String>[];
    for (var i = 0; i < relevant.length; i++) {
      final m = relevant[i];
      final source = m.source.isNotEmpty ? '[${m.source}] ' : '';
      final date = m.timestamp.toIso8601String().split('T').first;
      lines.add('${i + 1}. $source($date): ${m.content}');
    }

    final result = 'Erinnerungen zu "$query":\n${lines.join('\n')}';
    return ToolResult(
      toolName: definition.name,
      parameters: parameters,
      result: result,
      displayText: '🔍 ${relevant.length} Erinnerungen zu "$query" gefunden',
    );
  }
}
