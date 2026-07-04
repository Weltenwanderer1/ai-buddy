import 'package:url_launcher/url_launcher.dart';
import 'tool_interface.dart';
import 'tool_definition.dart';
import 'tool_result.dart';

/// Sends an SMS via the device's SMS app.
class SendSmsTool implements ToolInterface {
  static const _definition = ToolDefinition(
    name: 'send_sms',
    description: 'Sendet eine SMS. Oeffnet die SMS-App mit vorausgefuellter Nachricht.',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'phone': {'type': 'string', 'description': 'Telefonnummer'},
        'message': {'type': 'string', 'description': 'Nachrichtentext'},
      },
      'required': ['phone', 'message'],
    },
  );

  @override
  ToolDefinition get definition => _definition;

  @override
  Future<ToolResult> execute(Map<String, dynamic> parameters) async {
    try {
      final phone = parameters['phone'] as String? ?? '';
      final message = parameters['message'] as String? ?? '';
      if (phone.isEmpty || message.isEmpty) {
        return ToolResult(toolName: definition.name, parameters: parameters,
          result: 'Telefonnummer oder Nachricht fehlt', isError: true, displayText: 'SMS unvollstaendig');
      }
      final uri = Uri.parse('sms:$phone?body=${Uri.encodeComponent(message)}');
      await launchUrl(uri);
      return ToolResult(toolName: definition.name, parameters: parameters,
        result: 'SMS an $phone vorbereitet', displayText: '📱 SMS an $phone');
    } catch (e) {
      return ToolResult(toolName: definition.name, parameters: parameters,
        result: 'Fehler: $e', isError: true, displayText: 'SMS-Fehler');
    }
  }
}
