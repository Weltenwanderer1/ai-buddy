import '../services/todo_service.dart';
import 'tool_interface.dart';
import 'tool_definition.dart';
import 'tool_result.dart';

/// AI-managed todo list — add, list, toggle, edit, or delete items.
///
/// Token-efficient: uses a single tool with multiple actions.
/// `prioritize_on_list`: reorders by appending new items to the top (like a
/// real person's quick-list). Off by default — new items are simply appended.
class ManageTodoTool implements ToolInterface {
  final TodoService _todo;

  ManageTodoTool(this._todo);

  static const _definition = ToolDefinition(
    name: 'manage_todo',
    description:
        'Todo-Liste verwalten: add, list, toggle, remove, clear, edit. '
        'Nutze list um den aktuellen Stand zu sehen. '
        'Nach jedem add/toggle/remove/clear sende die aktualisierte Liste als Display.',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'action': {
          'type': 'string',
          'enum': ['add', 'list', 'toggle', 'remove', 'clear', 'edit'],
          'description':
              'add: neues Todo hinzufügen. list: alle anzeigen. toggle: erledigt/nicht. '
              'remove: löschen (id nötig). clear: alles löschen. edit: text ändern (id + content nötig).',
        },
        'content': {
          'type': 'string',
          'description': 'Text für add/edit.',
        },
        'id': {
          'type': 'string',
          'description': 'Todo-ID für toggle/remove/edit. Bei list/add ignorieren.',
        },
      },
      'required': ['action'],
    },
  );

  @override
  ToolDefinition get definition => _definition;

  @override
  Future<ToolResult> execute(Map<String, dynamic> parameters) async {
    final action = parameters['action'] as String? ?? 'list';
    final content = (parameters['content'] as String? ?? '').trim();
    final id = parameters['id'] as String? ?? '';

    switch (action) {
      case 'add':
        if (content.isEmpty) {
          return ToolResult(
            toolName: definition.name,
            parameters: parameters,
            result: 'Kein Text für das Todo angegeben.',
            isError: true,
            displayText: '❌ Kein Text',
          );
        }
        _todo.add(content);
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: 'Todo hinzugefügt: "$content"\n\n${_todo.toPlainList()}',
          displayText: '✅ Todo: $content',
        );

      case 'list':
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: _todo.toPlainList(),
          displayText: _todo.isEmpty
              ? '📋 Keine Todos'
              : '📋 ${_todo.pendingCount} offene Todos',
        );

      case 'toggle':
        if (id.isEmpty) {
          return ToolResult(
            toolName: definition.name,
            parameters: parameters,
            result: 'Keine ID für toggle angegeben.',
            isError: true,
            displayText: '❌ ID fehlt',
          );
        }
        final done = _todo.toggle(id);
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: done
              ? 'Todo abgeschlossen ✓\n\n${_todo.toPlainList()}'
              : 'Todo wieder offen\n\n${_todo.toPlainList()}',
          displayText: done ? '✅ Erledigt' : '🔄 Wieder offen',
        );

      case 'remove':
        if (id.isEmpty) {
          return ToolResult(
            toolName: definition.name,
            parameters: parameters,
            result: 'Keine ID für remove angegeben.',
            isError: true,
            displayText: '❌ ID fehlt',
          );
        }
        final removed = _todo.remove(id);
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: removed
              ? 'Todo entfernt.\n\n${_todo.toPlainList()}'
              : 'Todo mit ID $id nicht gefunden.',
          displayText: '🗑️ Todo entfernt',
        );

      case 'clear':
        await _todo.clear();
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: 'Alle Todos gelöscht.',
          displayText: '🗑️ Liste geleert',
        );

      case 'edit':
        if (id.isEmpty || content.isEmpty) {
          return ToolResult(
            toolName: definition.name,
            parameters: parameters,
            result: 'ID und content sind für edit erforderlich.',
            isError: true,
            displayText: '❌ Parameter fehlen',
          );
        }
        final ok = _todo.edit(id, content);
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: ok
              ? 'Todo aktualisiert.\n\n${_todo.toPlainList()}'
              : 'Todo mit ID $id nicht gefunden.',
          displayText: ok ? '✏️ Todo bearbeitet' : '❌ Nicht gefunden',
        );

      default:
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: 'Unbekannte Aktion: $action',
          isError: true,
          displayText: '❌ Unbekannte Aktion',
        );
    }
  }
}
