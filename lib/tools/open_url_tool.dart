import 'tool_interface.dart';
import 'tool_definition.dart';
import 'tool_result.dart';

/// Opens a URL in the device browser.
class OpenUrlTool implements ToolInterface {
  static const _definition = ToolDefinition(
    name: 'open_url',
    description:
        'Öffnet eine URL im Standard-Browser des Geräts. Nutze dies, wenn der Nutzer eine Website öffnen möchte.',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'url': {
          'type': 'string',
          'description': 'Die zu öffnende URL (inklusive http:// oder https://)',
        },
      },
      'required': ['url'],
    },
  );

  @override
  ToolDefinition get definition => _definition;

  /// Callback to launch a URL. Registered by the app at startup.
  static Future<bool> Function(String url)? launchCallback;

  @override
  Future<ToolResult> execute(Map<String, dynamic> parameters) async {
    final url = parameters['url'] as String? ?? '';

    if (url.isEmpty) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Fehler: Keine URL angegeben.',
        isError: true,
        displayText: '❌ Keine URL',
      );
    }

    // Validate URL
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || !uri.scheme.startsWith('http')) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Fehler: Ungültige URL — $url',
        isError: true,
        displayText: '❌ Ungültige URL',
      );
    }

    if (launchCallback != null) {
      final success = await launchCallback!(url);
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: success ? 'URL geöffnet: $url' : 'Fehler: URL konnte nicht geöffnet werden.',
        isError: !success,
        displayText: success ? '🔗 URL geöffnet' : '❌ URL konnte nicht geöffnet werden',
      );
    }

    return ToolResult(
      toolName: definition.name,
      parameters: parameters,
      result: 'URL zum Öffnen: $url (Debug-Modus, kein url_launcher).',
      displayText: '🔗 URL (Debug): $url',
    );
  }
}
