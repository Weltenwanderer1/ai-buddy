import '../services/buddy_notes_service.dart';
import 'tool_interface.dart';
import 'tool_definition.dart';
import 'tool_result.dart';

/// KI kann Buddy Notizen lesen und schreiben.
class BuddyNotesTool implements ToolInterface {
  final BuddyNotesService _notes;

  BuddyNotesTool(this._notes);

  static const _definition = ToolDefinition(
    name: 'buddy_notes',
    description:
        'Liest oder schreibt die Buddy Notizen. Nutze dies um wichtige Informationen über Tools, Skills, Passwörter, oder Erkenntnisse dauerhaft zu speichern. '
        'action=read: lies aktuelle Notizen. '
        'action=write: füge eine neue Notiz hinzu (bestehende werden nicht überschrieben). '
        'action=overwrite: ersetze alle Notizen (vorsicht!).',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'action': {
          'type': 'string',
          'enum': ['read', 'write', 'overwrite'],
          'description': 'read = lesen, write = anhängen, overwrite = ersetzen',
        },
        'content': {
          'type': 'string',
          'description': 'Inhalt für write/overwrite. Bei read nicht nötig.',
        },
      },
      'required': ['action'],
    },
  );

  @override
  ToolDefinition get definition => _definition;

  @override
  Future<ToolResult> execute(Map<String, dynamic> parameters) async {
    final action = parameters['action'] as String? ?? 'read';
    final content = parameters['content'] as String? ?? '';

    switch (action) {
      case 'read':
        final notes = _notes.notes;
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: notes.isEmpty ? 'Keine Notizen vorhanden.' : notes,
          displayText: '📓 Notizen gelesen',
        );
      case 'write':
        if (content.isEmpty) {
          return ToolResult(
            toolName: definition.name,
            parameters: parameters,
            result: 'Kein Inhalt zum Speichern.',
            displayText: '❌ Leerer Inhalt',
            isError: true,
          );
        }
        await _notes.append(content);
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: 'Notiz hinzugefügt: "$content"',
          displayText: '📝 Notiz gespeichert',
        );
      case 'overwrite':
        await _notes.updateNotes(content);
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: content.isEmpty ? 'Notizen gelöscht.' : 'Notizen überschrieben.',
          displayText: content.isEmpty ? '🗑️ Notizen gelöscht' : '📝 Notizen überschrieben',
        );
      default:
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: 'Unbekannte Aktion: $action',
          displayText: '❌ Unbekannte Aktion',
          isError: true,
        );
    }
  }
}
