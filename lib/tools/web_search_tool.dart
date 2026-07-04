import 'dart:convert';
import 'dart:io';
import 'tool_interface.dart';
import 'tool_definition.dart';
import 'tool_result.dart';

/// Web search via DuckDuckGo (no API key required).
class WebSearchTool implements ToolInterface {
  static const _definition = ToolDefinition(
    name: 'web_search',
    description: 'Websuche nach aktuellen Informationen via DuckDuckGo.',
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

    final maxResults = ((parameters['max_results'] as num?)?.toInt() ?? 3).clamp(1, 5);

    final encodedQuery = Uri.encodeQueryComponent(query);
    final searchUrl = 'https://html.duckduckgo.com/html/?q=$encodedQuery';

    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(searchUrl));
      request.headers.set('User-Agent',
          'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');
      request.headers.set('Accept',
          'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8');

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

      final results = _parseResults(body, maxResults);

      if (results.isEmpty) {
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: 'Keine Ergebnisse gefunden für "$query".',
          displayText: '🔍 Keine Ergebnisse',
        );
      }

      final buffer = StringBuffer();
      buffer.writeln('Suchergebnisse für "$query":');
      buffer.writeln();
      for (final r in results) {
        buffer.writeln('- ${r['title']!}');
        buffer.writeln('  ${r['url']!}');
        if (r['snippet']!.isNotEmpty) buffer.writeln('  ${r['snippet']!}');
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
    } finally {
      client.close(force: true);
    }
  }

  /// Extrahiert Ergebnisse aus html.duckduckgo.com.
  ///
  /// Titel-Links (`a.result__a`) und Snippets (`a.result__snippet` — DDG
  /// rendert Snippets als <a>, nicht als <div>) werden getrennt in
  /// Dokument-Reihenfolge gesammelt und über den Index gepaart. Das ist
  /// robuster als ein Block-Regex über verschachteltes HTML.
  List<Map<String, String>> _parseResults(String html, int maxResults) {
    final anchors = RegExp(
      r'<a[^>]+class="[^"]*result__a[^"]*"[^>]+href="([^"]+)"[^>]*>(.*?)<\/a>',
      dotAll: true,
      caseSensitive: false,
    ).allMatches(html).toList();

    final snippets = RegExp(
      r'<(?:a|div)[^>]+class="[^"]*result__snippet[^"]*"[^>]*>(.*?)<\/(?:a|div)>',
      dotAll: true,
      caseSensitive: false,
    ).allMatches(html).map((m) => _stripHtml(m.group(1) ?? '')).toList();

    final results = <Map<String, String>>[];
    for (var i = 0; i < anchors.length && results.length < maxResults; i++) {
      final url = _decodeRedirect(anchors[i].group(1)?.trim() ?? '');
      final title = _stripHtml(anchors[i].group(2) ?? '');
      if (url.isEmpty || title.isEmpty) continue;
      // DDG blendet manchmal Anzeigen ein — die laufen über y.js statt /l/
      if (url.contains('duckduckgo.com/y.js')) continue;
      results.add({
        'url': url,
        'title': title,
        'snippet': i < snippets.length ? snippets[i] : '',
      });
    }
    return results;
  }

  /// Löst DuckDuckGo-Redirect-URLs auf (`//duckduckgo.com/l/?uddg=<ziel>`).
  static String _decodeRedirect(String url) {
    if (url.contains('/l/?') || url.contains('uddg=')) {
      final m = RegExp(r'uddg=([^&]+)').firstMatch(url);
      if (m != null) {
        try {
          return Uri.decodeComponent(m.group(1)!);
        } catch (_) {/* fällt unten durch */}
      }
    }
    if (url.startsWith('//')) return 'https:$url';
    return url;
  }

  String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&mdash;', '—')
        .replaceAll('&#x27;', "'")
        // &amp; zuletzt, sonst wird z.B. &amp;lt; doppelt dekodiert
        .replaceAll('&amp;', '&')
        .trim();
  }
}
