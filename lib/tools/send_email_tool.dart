import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'tool_interface.dart';
import 'tool_definition.dart';
import 'tool_result.dart';

/// Sends an email via the device's default email app.
/// Can search contacts to resolve contact names to email addresses.
class SendEmailTool implements ToolInterface {
  static const _channel = MethodChannel('com.ai-buddy.app/contacts');

  static const _definition = ToolDefinition(
    name: 'send_email',
    description: 'Oeffnet Mail-App mit vorausgefuellten Feldern. Empfaenger per Name oder E-Mail.',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'recipient': {
          'type': 'string',
          'description': 'Name des Kontakts oder E-Mail-Adresse',
        },
        'subject': {
          'type': 'string',
          'description': 'Betreff der E-Mail (optional)',
        },
        'body': {
          'type': 'string',
          'description': 'Inhalt der E-Mail',
        },
      },
      'required': ['recipient', 'body'],
    },
  );

  @override
  ToolDefinition get definition => _definition;

  @override
  Future<ToolResult> execute(Map<String, dynamic> parameters) async {
    final recipient = (parameters['recipient'] as String? ?? '').trim();
    final subject = (parameters['subject'] as String? ?? 'E-Mail von AI-Buddy').trim();
    final body = (parameters['body'] as String? ?? '').trim();

    if (recipient.isEmpty) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Kein Empfaenger angegeben',
        isError: true,
        displayText: 'E-Mail: kein Empfaenger',
      );
    }

    if (body.isEmpty) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Kein E-Mail-Inhalt angegeben',
        isError: true,
        displayText: 'E-Mail: kein Inhalt',
      );
    }

    String emailAddress;

    // Check if recipient is already an email address (contains @)
    if (recipient.contains('@')) {
      emailAddress = recipient;
    } else {
      // Resolve contact name to email
      final status = await Permission.contacts.request();
      if (!status.isGranted) {
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: 'Kontaktberechtigung benoetigt, um E-Mail-Adresse aufzuloesen.',
          isError: true,
          displayText: 'Kontaktberechtigung fehlt',
        );
      }

      try {
        final List contacts = await _channel.invokeMethod('searchContacts', {
          'query': recipient,
          'limit': 1,
        });

        if (contacts.isEmpty) {
          return ToolResult(
            toolName: definition.name,
            parameters: parameters,
            result: 'Kein Kontakt namens "$recipient" gefunden.',
            isError: true,
            displayText: 'Kontakt "$recipient" nicht gefunden',
          );
        }

        final Map<String, dynamic> c = Map<String, dynamic>.from(contacts.first);
        final emails = c['emails'] as List? ?? [];
        if (emails.isEmpty) {
          return ToolResult(
            toolName: definition.name,
            parameters: parameters,
            result: 'Kontakt "${c['name']}" hat keine E-Mail-Adresse hinterlegt.',
            isError: true,
            displayText: 'Keine E-Mail fuer "${c['name']}"',
          );
        }

        final Map<String, dynamic> firstEmail = Map<String, dynamic>.from(emails.first);
        emailAddress = firstEmail['address'] as String? ?? '';
      } on PlatformException catch (e) {
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: 'Fehler bei Kontaktaufloesung: ${e.message}',
          isError: true,
          displayText: 'Fehler bei Kontaktsuche',
        );
      }
    }

    if (emailAddress.isEmpty) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Keine gueltige E-Mail-Adresse gefunden.',
        isError: true,
        displayText: 'E-Mail ungueltig',
      );
    }

    try {
      final uri = Uri(
        scheme: 'mailto',
        path: emailAddress,
        query: 'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
      );
      await launchUrl(uri);
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'E-Mail an $emailAddress vorbereitet.',
        displayText: '📧 E-Mail an $recipient',
      );
    } catch (e) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Fehler beim Oeffnen der Mail-App: $e',
        isError: true,
        displayText: 'E-Mail Fehler',
      );
    }
  }
}
