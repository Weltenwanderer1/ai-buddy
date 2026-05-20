import 'dart:convert';
import 'dart:io';
import 'tool_interface.dart';
import 'tool_definition.dart';
import 'tool_result.dart';

/// Fetches a webpage and extracts text content.
class GetWebpageTool implements ToolInterface {
  static const _definition = ToolDefinition(
    name: 'get_webpage',
    description:
        'Ruft eine Webseite ab und extrahiert den Textinhalt. Nutze dies, um Informationen von einer bestimmten URL zu holen.',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'url': {
          'type': 'string',
          'description': 'Die abzurufende URL (inklusive http:// oder https://)',
        },
        'max_chars': {
          'type': 'integer',
          'description': 'Maximale Zeichenanzahl des extrahierten Texts (Standard 5000)',
        },
      },
      'required': ['url'],
    },
  );

  @override
  ToolDefinition get definition => _definition;

  @override
  Future<ToolResult> execute(Map<String, dynamic> parameters) async {
    final url = parameters['url'] as String? ?? '';
    final maxChars = (parameters['max_chars'] as int?) ?? 5000;

    if (url.isEmpty) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Fehler: Keine URL angegeben.',
        isError: true,
        displayText: '❌ Keine URL',
      );
    }

    Uri? uri;
    try {
      uri = Uri.parse(url);
      if (!uri.hasScheme || (!uri.scheme.startsWith('http'))) {
        throw FormatException('Ungültiges URL-Schema');
      }
    } catch (e) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Fehler: Ungültige URL — $url',
        isError: true,
        displayText: '❌ Ungültige URL',
      );
    }

    try {
      final client = HttpClient();
      final request = await client.getUrl(uri);
      request.headers.set('User-Agent', 'AI-Buddy/1.0');
      final response = await request.close();

      if (response.statusCode != 200) {
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: 'Fehler: HTTP ${response.statusCode}',
          isError: true,
          displayText: '❌ HTTP ${response.statusCode}',
        );
      }

      final body = await response.transform(utf8.decoder).join();
      final text = _extractText(body);

      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: text.length > maxChars
            ? '${text.substring(0, maxChars)}\n\n[... gekürzt]'
            : text,
        displayText: '📄 Seite abgerufen',
      );
    } catch (e) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Fehler beim Abrufen: $e',
        isError: true,
        displayText: '❌ Abruffehler',
      );
    }
  }

  /// Very basic HTML-to-text: strip tags, decode entities.
  String _extractText(String html) {
    // Remove script and style blocks
    var text = html.replaceAll(RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false), '');
    text = text.replaceAll(RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false), '');
    // Remove all HTML tags
    text = text.replaceAll(RegExp(r'<[^>]+>'), ' ');
    // Decode common HTML entities
    text = text.replaceAll('&amp;', '&');
    text = text.replaceAll('&lt;', '<');
    text = text.replaceAll('&gt;', '>');
    text = text.replaceAll('&quot;', '"');
    text = text.replaceAll('&#39;', "'");
    text = text.replaceAll('&nbsp;', ' ');
    // Collapse whitespace
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return text;
  }
}
