import 'tool_interface.dart';
import 'tool_definition.dart';
import 'tool_result.dart';

/// Tool to send proactive notifications to the user.
class SendProactiveNotificationTool implements ToolInterface {
  static const _definition = ToolDefinition(
    name: 'send_proactive_notification',
    description:
        'Sendet dem Benutzer eine proaktive Benachrichtigung mit optionalen Action-Buttons. '
        'Nutze dies wenn du dem Benutzer etwas Wichtiges mitteilen möchtest, '
        'auch wenn er nicht direkt mit dir chattet.',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'title': {
          'type': 'string',
          'description': 'Titel der Benachrichtigung (kurz, auffällig)',
        },
        'body': {
          'type': 'string',
          'description': 'Haupttext der Benachrichtigung',
        },
        'priority': {
          'type': 'string',
          'description': 'Priorität: "low", "normal", "high", "urgent"',
          'enum': ['low', 'normal', 'high', 'urgent'],
        },
        'actions': {
          'type': 'array',
          'description':
              'Optionale Action-Buttons (max 3). Jeder hat "id" und "label".',
          'items': {
            'type': 'object',
            'properties': {
              'id': {'type': 'string'},
              'label': {'type': 'string'},
            },
          },
        },
      },
      'required': ['title', 'body'],
    },
  );

  @override
  ToolDefinition get definition => _definition;

  /// Callback to send a proactive notification.
  static Future<bool> Function({
    required String title,
    required String body,
    String? priority,
    List<Map<String, String>>? actions,
  })? sendCallback;

  @override
  Future<ToolResult> execute(Map<String, dynamic> parameters) async {
    final title = (parameters['title'] as String?)?.trim() ?? '';
    final body = (parameters['body'] as String?)?.trim() ?? '';
    final priority = (parameters['priority'] as String?) ?? 'normal';
    final actionsRaw = parameters['actions'] as List<dynamic>?;

    if (title.isEmpty || body.isEmpty) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Fehler: Titel und Body sind erforderlich.',
        isError: true,
        displayText: '❌ Titel/Body fehlt',
      );
    }

    if (sendCallback == null) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Fehler: Benachrichtigungsdienst nicht verfügbar.',
        isError: true,
        displayText: '❌ Service nicht verfügbar',
      );
    }

    final actions = <Map<String, String>>[];
    if (actionsRaw != null) {
      for (final a in actionsRaw.take(3)) {
        if (a is Map) {
          actions.add({
            'id': a['id']?.toString() ?? '',
            'label': a['label']?.toString() ?? '',
          });
        }
      }
    }

    try {
      final success = await sendCallback!(
        title: title,
        body: body,
        priority: priority,
        actions: actions.isNotEmpty ? actions : null,
      );
      if (success) {
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: 'Benachrichtigung gesendet: "$title"',
          displayText: '🔔 $title',
        );
      } else {
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: 'Fehler: Benachrichtigung konnte nicht gesendet werden.',
          isError: true,
          displayText: '❌ Senden fehlgeschlagen',
        );
      }
    } catch (e) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Fehler: $e',
        isError: true,
        displayText: '❌ Fehler',
      );
    }
  }
}
