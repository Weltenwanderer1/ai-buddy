import '../services/obsidian_vault_service.dart';
import 'tool_interface.dart';
import 'tool_definition.dart';
import 'tool_result.dart';

class ObsidianVaultTool implements ToolInterface {
  final ObsidianVaultService _vault;
  ObsidianVaultTool(this._vault);

  static const _definition = ToolDefinition(
    name: 'obsidian_vault',
    description:
        'Durchsucht, liest und schreibt Notizen im Obsidian Vault. '
        'Nutze action="search" bei Fragen des Nutzers um den Vault zu durchsuchen. '
        'Nutze action="write" um neue Notizen zu erstellen oder bestehende zu aktualisieren.',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'action': {
          'type': 'string',
          'enum': ['search', 'read', 'write', 'list'],
          'description':
              'Aktion: search=durchsuchen, read=lesen, write=schreiben/erstellen, list=Dateien auflisten',
        },
        'query': {
          'type': 'string',
          'description': 'Suchbegriff für search-Aktion',
        },
        'path': {
          'type': 'string',
          'description':
              'Relativer Pfad zur .md Datei (z.B. "10-Notes/Meine Notiz.md") für read/write/list',
        },
        'content': {
          'type': 'string',
          'description': 'Inhalt zum Schreiben (nur für write-Aktion)',
        },
        'limit': {
          'type': 'integer',
          'description': 'Max. Anzahl Ergebnisse (Standard: 10)',
        },
      },
      'required': ['action'],
    },
  );

  @override
  ToolDefinition get definition => _definition;

  @override
  Future<ToolResult> execute(Map<String, dynamic> parameters) async {
    final action = parameters['action'] as String? ?? 'search';

    if (!_vault.isConfigured) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result:
            'Obsidian Vault nicht konfiguriert. Bitte in den Einstellungen den Vault-Pfad setzen.',
        displayText: '📂 Vault nicht konfiguriert',
        isError: true,
      );
    }

    switch (action) {
      case 'search':
        return _search(parameters);
      case 'read':
        return _read(parameters);
      case 'write':
        return _write(parameters);
      case 'list':
        return _list(parameters);
      default:
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: 'Unbekannte Aktion: $action. Erlaubt: search, read, write, list',
          isError: true,
        );
    }
  }

  Future<ToolResult> _search(Map<String, dynamic> parameters) async {
    final query = parameters['query'] as String? ?? '';
    if (query.isEmpty) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Keine Suchanfrage angegeben.',
        displayText: '🔍 Keine Suchanfrage',
        isError: true,
      );
    }
    final rawLimit = parameters['limit'];
    final limit = (rawLimit is num ? rawLimit.toInt() : 10).clamp(1, 50);

    final results = await _vault.search(query, limit: limit);
    if (results.isEmpty) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Keine Ergebnisse im Vault für: "$query"',
        displayText: '🔍 Keine Ergebnisse zu "$query"',
      );
    }

    final buf = StringBuffer(
        'Vault-Suche "$query" — ${results.length} Ergebnisse:\n\n');
    for (var i = 0; i < results.length; i++) {
      final r = results[i];
      buf.writeln('${i + 1}. **${r['title']}** (`${r['path']}`)');
      final excerpt = r['excerpt'] as String? ?? '';
      if (excerpt.isNotEmpty) {
        buf.writeln('   $excerpt');
      }
      buf.writeln();
    }

    return ToolResult(
      toolName: definition.name,
      parameters: parameters,
      result: buf.toString().trim(),
      displayText: '🔍 ${results.length} Vault-Ergebnisse zu "$query"',
    );
  }

  Future<ToolResult> _read(Map<String, dynamic> parameters) async {
    final path = parameters['path'] as String? ?? '';
    if (path.isEmpty) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Kein Pfad angegeben.',
        displayText: '📂 Kein Pfad',
        isError: true,
      );
    }

    final content = await _vault.readNote(path);
    if (content == null) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Datei nicht gefunden: $path',
        displayText: '📂 Datei nicht gefunden',
        isError: true,
      );
    }

    final truncated = content.length > 5000
        ? '${content.substring(0, 5000)}\n... (${content.length} Zeichen)'
        : content;

    return ToolResult(
      toolName: definition.name,
      parameters: parameters,
      result: '`$path` (${content.length} Zeichen):\n$truncated',
      displayText: '📂 Gelesen: $path',
    );
  }

  Future<ToolResult> _write(Map<String, dynamic> parameters) async {
    final path = parameters['path'] as String? ?? '';
    final content = parameters['content'] as String? ?? '';

    if (path.isEmpty) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Kein Pfad angegeben.',
        displayText: '📝 Kein Pfad',
        isError: true,
      );
    }
    if (content.isEmpty) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Kein Inhalt angegeben.',
        displayText: '📝 Kein Inhalt',
        isError: true,
      );
    }

    // Ensure .md extension
    final mdPath = path.endsWith('.md') ? path : '$path.md';

    final success = await _vault.writeNote(mdPath, content);
    if (!success) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Fehler beim Schreiben: $mdPath',
        displayText: '📝 Schreibfehler',
        isError: true,
      );
    }

    return ToolResult(
      toolName: definition.name,
      parameters: parameters,
      result: 'Gespeichert: $mdPath',
      displayText: '📝 Gespeichert: $mdPath',
    );
  }

  Future<ToolResult> _list(Map<String, dynamic> parameters) async {
    final path = parameters['path'] as String? ?? '';
    final rawLimit = parameters['limit'];
    final limit = (rawLimit is num ? rawLimit.toInt() : 50).clamp(1, 200);

    final notes = await _vault.listNotes(folder: path, limit: limit);
    if (notes.isEmpty) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: path.isEmpty
            ? 'Vault ist leer oder nicht erreichbar.'
            : 'Keine .md Dateien in: $path',
        displayText: '📂 Keine Dateien',
      );
    }

    final buf = StringBuffer(
        'Vault-Dateien${path.isNotEmpty ? " in $path" : ""} (${notes.length}):\n');
    for (final note in notes) {
      buf.writeln('- **${note['title']}** (`${note['path']}`)');
    }

    return ToolResult(
      toolName: definition.name,
      parameters: parameters,
      result: buf.toString().trim(),
      displayText: '📂 ${notes.length} Vault-Dateien',
    );
  }
}
