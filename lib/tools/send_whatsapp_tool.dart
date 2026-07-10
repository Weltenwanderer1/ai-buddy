import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'tool_interface.dart';
import 'tool_definition.dart';
import 'tool_result.dart';

/// Opens WhatsApp to send a message to a phone number.
class SendWhatsAppTool implements ToolInterface {
  static const _accessibilityChannel =
      MethodChannel('com.aibuddy.app/accessibility');
  static const _definition = ToolDefinition(
    name: 'send_whatsapp',
    description:
        'Sendet eine WhatsApp-Nachricht. Oeffnet WhatsApp mit vorausgefuellter Nachricht.',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'phone': {
          'type': 'string',
          'description': 'Telefonnummer (international, ohne +)'
        },
        'message': {'type': 'string', 'description': 'Nachrichtentext'},
      },
      'required': ['phone'],
    },
  );

  @override
  ToolDefinition get definition => _definition;

  @override
  Future<ToolResult> execute(Map<String, dynamic> parameters) async {
    try {
      final phone = parameters['phone'] as String? ?? '';
      final message = parameters['message'] as String? ?? '';
      if (phone.isEmpty) {
        return ToolResult(
            toolName: definition.name,
            parameters: parameters,
            result: 'Keine Telefonnummer',
            isError: true,
            displayText: 'WhatsApp: keine Nummer');
      }
      var url = 'https://wa.me/$phone';
      if (message.isNotEmpty) url += '?text=${Uri.encodeComponent(message)}';
      await launchUrl(Uri.parse(url));
      var sent = false;
      if (message.isNotEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 1200));
        try {
          sent = await _accessibilityChannel.invokeMethod<bool>(
                'tapWhatsAppSend',
              ) ??
              false;
        } on PlatformException {
          // Optional: without Accessibility WhatsApp stays open for confirmation.
        }
      }
      return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: sent
              ? 'WhatsApp-Nachricht an $phone gesendet'
              : 'WhatsApp zu $phone geoeffnet. Fuer automatisches Senden AI-Buddy einmalig in den Android-Bedienungshilfen aktivieren.',
          displayText: '💬 WhatsApp an $phone');
    } catch (e) {
      return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: 'Fehler: $e',
          isError: true,
          displayText: 'WhatsApp-Fehler');
    }
  }
}
