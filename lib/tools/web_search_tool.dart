import 'dart:convert';
import 'dart:io';
import 'tool_interface.dart';
import 'tool_definition.dart';
import 'tool_result.dart';

/// Web search via Tavily API.
class WebSearchTool implements ToolInterface {
  static const _definition = ToolDefinition(
    name: 'web_search',
    description:
        'Sucht im Internet nach Informationen. Nutze dies, wenn der Nutzer eine Frage hat, die aktuelle Informationen aus dem Web erfordert (Wetter, Nachrichten, Fakten, etc.).',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'query': {
          'type': 'string',
          'description': 'Die Suchanfrage',
        },
        'max_results': {
          'type': 'integer',
          'description': 'Maximale Anzahl Ergebnisse (1-5, Standard 3)',
        },
      },
      'required': ['query'],
    },
  );

  @override
  ToolDefinition get definition => _definition;

  /// API key for Tavily. Set by the app at startup from secure config.
  String? apiKey;

  WebSearchTool({this.apiKey});

  @override
  Future<ToolResult> execute(Map<String, dynamic> parameters) async {
    final query = parameters['query'] as String? ?? '';
    if (query.isEmpty) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Fehler: Keine Suchanfrage angegeben.',
        isError: true,
        displayText: '❌ Keine Suchanfrage',
      );
    }

    final maxResults = (parameters['max_results'] as int?) ?? 3;
    final clampedMax = maxResults.clamp(1, 5);

    if (apiKey == null || apiKey!.isEmpty) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result:
            'Fehler: Kein Tavily API-Key konfiguriert. Bitte in den Einstellungen einen TAVILY_API_KEY eintragen.',
        isError: true,
        displayText: '❌ Kein API-Key',
      );
    }

    try {
      final client = HttpClient();
      final request = await client.postUrl(Uri.parse('https://api.tavily.com/search'));
      request.headers.set('Content-Type', 'application/json');
      request.headers.set('Authorization', 'Bearer $apiKey');
      request.write(jsonEncode({
        'query': query,
        'max_results': clampedMax,
        'include_answer': true,
      }));

      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode != 200) {
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: 'Fehler: Suche fehlgeschlagen (HTTP ${response.statusCode})',
          isError: true,
          displayText: '❌ Suche fehlgeschlagen',
        );
      }

      final data = jsonDecode(body) as Map<String, dynamic>;
      final answer = data['answer'] as String? ?? '';
      final results = data['results'] as List? ?? [];

      final buffer = StringBuffer();
      if (answer.isNotEmpty) {
        buffer.writeln('Antwort: $answer');
        buffer.writeln();
      }
      buffer.writeln('Ergebnisse:');
      for (final r in results) {
        final title = r['title'] as String? ?? '';
        final url = r['url'] as String? ?? '';
        final content = r['content'] as String? ?? '';
        buffer.writeln('- $title');
        buffer.writeln('  $url');
        buffer.writeln('  $content');
        buffer.writeln();
      }

      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: buffer.toString(),
        displayText: '🔍 Suche: $query',
      );
    } catch (e) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Fehler bei der Suche: $e',
        isError: true,
        displayText: '❌ Suchfehler',
      );
    }
  }
}