import 'tool_interface.dart';
import 'tool_definition.dart';
import 'tool_result.dart';

/// Shares text via Android share sheet.
class ShareTextTool implements ToolInterface {
  static const _definition = ToolDefinition(
    name: 'share_text',
    description:
        'Teilt Text über das Android Share-Sheet (z.B. an WhatsApp, E-Mail, etc.). Nutze dies, wenn der Nutzer etwas teilen möchte.',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'text': {
          'type': 'string',
          'description': 'Der zu teilende Text',
        },
        'subject': {
          'type': 'string',
          'description': 'Optionaler Betreff (z.B. für E-Mail)',
        },
      },
      'required': ['text'],
    },
  );

  @override
  ToolDefinition get definition => _definition;

  /// Callback to share text. Registered by the app at startup.
  static void Function(String text, String? subject)? shareCallback;

  @override
  Future<ToolResult> execute(Map<String, dynamic> parameters) async {
    final text = parameters['text'] as String? ?? '';
    final subject = parameters['subject'] as String?;

    if (text.isEmpty) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Fehler: Kein Text zum Teilen angegeben.',
        isError: true,
        displayText: '❌ Kein Text',
      );
    }

    if (shareCallback != null) {
      shareCallback!(text, subject);
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Text geteilt.',
        displayText: '📤 Geteilt',
      );
    }

    return ToolResult(
      toolName: definition.name,
      parameters: parameters,
      result: 'Text zum Teilen: $text (Debug-Modus, kein share_plus).',
      displayText: '📤 (Debug) Geteilt',
    );
  }
}
