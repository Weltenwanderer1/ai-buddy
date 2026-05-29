import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'tool_interface.dart';
import 'tool_definition.dart';
import 'tool_result.dart';

/// Sends a message (SMS or WhatsApp) to a contact by name or number.
/// If a name is given, it resolves to a phone number via the contacts channel.
class SendMessageToContactTool implements ToolInterface {
  static const _channel = MethodChannel('com.ai-buddy.app/contacts');

  static const _definition = ToolDefinition(
    name: 'send_message_to_contact',
    description: 'Sendet Nachricht an Kontakt per SMS/WhatsApp. Kontakt per Name oder Nummer.',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'contact': {
          'type': 'string',
          'description': 'Name oder Telefonnummer des Kontakts',
        },
        'message': {
          'type': 'string',
          'description': 'Nachrichtentext',
        },
        'channel': {
          'type': 'string',
          'description': 'Kanal: "sms" oder "whatsapp" (Standard: "whatsapp")',
        },
      },
      'required': ['contact', 'message'],
    },
  );

  @override
  ToolDefinition get definition => _definition;

  @override
  Future<ToolResult> execute(Map<String, dynamic> parameters) async {
    final contact = parameters['contact'] as String? ?? '';
    final message = parameters['message'] as String? ?? '';
    final channel = parameters['channel'] as String? ?? 'whatsapp';

    if (contact.isEmpty) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Kein Kontakt angegeben',
        isError: true,
        displayText: 'Nachricht: kein Kontakt',
      );
    }

    if (message.isEmpty) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Kein Nachrichtentext angegeben',
        isError: true,
        displayText: 'Nachricht: kein Text',
      );
    }

    String phone;

    // Check if contact is already a phone number (starts with + or is all digits)
    final isPhoneNumber = RegExp(r'^[\d+\s\-()]+$').hasMatch(contact) &&
        contact.replaceAll(RegExp(r'[\s\-()]'), '').length >= 5;

    if (isPhoneNumber) {
      phone = contact.replaceAll(RegExp(r'[\s\-()]'), '');
      if (!phone.startsWith('+')) phone = '+$phone';
    } else {
      // Need contacts permission to resolve name
      final status = await Permission.contacts.request();
      if (!status.isGranted) {
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: 'Kontaktberechtigung benoetigt, um Namen aufzuloesen. Bitte erlauben und erneut versuchen.',
          isError: true,
          displayText: 'Kontaktberechtigung fehlt',
        );
      }

      // Resolve contact name to phone number
      try {
        final List contacts = await _channel.invokeMethod('searchContacts', {
          'query': contact,
          'limit': 1,
        });

        if (contacts.isEmpty) {
          return ToolResult(
            toolName: definition.name,
            parameters: parameters,
            result: 'Kein Kontakt namens "$contact" gefunden.',
            isError: true,
            displayText: 'Kontakt "$contact" nicht gefunden',
          );
        }

        final Map<String, dynamic> c = Map<String, dynamic>.from(contacts.first);
        final phones = c['phones'] as List? ?? [];
        if (phones.isEmpty) {
          return ToolResult(
            toolName: definition.name,
            parameters: parameters,
            result: 'Kontakt "${c['name']}" hat keine Telefonnummer.',
            isError: true,
            displayText: 'Keine Nummer fuer "${c['name']}"',
          );
        }

        // Use the first phone number
        final Map<String, dynamic> firstPhone = Map<String, dynamic>.from(phones.first);
        phone = firstPhone['number'] as String? ?? '';
        final resolvedName = c['name'] ?? contact;

        if (phone.isEmpty) {
          return ToolResult(
            toolName: definition.name,
            parameters: parameters,
            result: 'Keine gueltige Telefonnummer fuer "$resolvedName".',
            isError: true,
            displayText: 'Keine Nummer fuer "$resolvedName"',
          );
        }
      } on PlatformException catch (e) {
        if (e.code == 'PERMISSION_DENIED') {
          return ToolResult(
            toolName: definition.name,
            parameters: parameters,
            result: 'Kontaktberechtigung verweigert. Bitte in den App-Einstellungen erlauben.',
            isError: true,
            displayText: 'Kontaktberechtigung fehlt',
          );
        }
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: 'Fehler bei Kontaktauflsung: ${e.message}',
          isError: true,
          displayText: 'Fehler bei Kontaktsuche',
        );
      }
    }

    // Clean phone number for URLs
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');

    try {
      if (channel == 'sms') {
        final uri = Uri.parse('sms:$cleanPhone?body=${Uri.encodeComponent(message)}');
        await launchUrl(uri);
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: 'SMS an $cleanPhone vorbereitet.',
          displayText: '📱 SMS an $contact',
        );
      } else {
        // WhatsApp
        final uri = Uri.parse('https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}');
        await launchUrl(uri);
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: 'WhatsApp-Nachricht an $cleanPhone vorbereitet.',
          displayText: '💬 WhatsApp an $contact',
        );
      }
    } catch (e) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Fehler beim Oeffnen der Nachricht-App: $e',
        isError: true,
        displayText: 'Nachricht-Fehler',
      );
    }
  }
}
