import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'tool_interface.dart';
import 'tool_definition.dart';
import 'tool_result.dart';

/// Add, edit or delete device contacts.
class ManageContactsTool implements ToolInterface {
  static const _channel = MethodChannel('com.ai-buddy.app/contacts');

  static const _definition = ToolDefinition(
    name: 'manage_contacts',
    description: 'Fuegt einen Kontakt hinzu, bearbeitet Telefon/E-Mail eines bestehenden Kontakts, oder loescht einen Kontakt.',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'action': {
          'type': 'string',
          'enum': ['add', 'edit', 'delete'],
          'description': 'Aktion: add=neuer Kontakt, edit=bearbeiten, delete=loeschen',
        },
        'name': {
          'type': 'string',
          'description': 'Voller Name (nur bei add benoetigt)',
        },
        'contactId': {
          'type': 'string',
          'description': 'Kontakt-ID (bei edit/delete; von search_contacts bekommen)',
        },
        'phone': {
          'type': 'string',
          'description': 'Telefonnummer (nur bei add/edit)',
        },
        'email': {
          'type': 'string',
          'description': 'E-Mail-Adresse (nur bei add/edit)',
        },
      },
      'required': ['action'],
    },
  );

  @override
  ToolDefinition get definition => _definition;

  @override
  Future<ToolResult> execute(Map<String, dynamic> parameters) async {
    final action = parameters['action'] as String? ?? '';
    final name = parameters['name'] as String? ?? '';
    final contactId = parameters['contactId'] as String? ?? '';
    final phone = parameters['phone'] as String? ?? '';
    final email = parameters['email'] as String? ?? '';

    if (action.isEmpty) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Keine Aktion angegeben (add/edit/delete)',
        isError: true,
      );
    }

    // Require WRITE_CONTACTS permission
    final status = await Permission.contacts.request();
    if (!status.isGranted) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Berechtigung fuer Kontakte verweigert. Bitte in den App-Einstellungen erlauben.',
        isError: true,
        displayText: 'Kontaktberechtigung fehlt',
      );
    }

    try {
      switch (action) {
        case 'add':
          if (name.isEmpty) {
            return ToolResult(
              toolName: definition.name,
              parameters: parameters,
              result: 'Fuer "add" wird ein Name benoetigt.',
              isError: true,
            );
          }
          final ok = await _channel.invokeMethod('addContact', {
            'name': name,
            'phone': phone,
            'email': email,
          });
          if (ok == true) {
            final parts = <String>[
              'Kontakt "$name" angelegt',
            ];
            if (phone.isNotEmpty) parts.add('Telefon: $phone');
            if (email.isNotEmpty) parts.add('E-Mail: $email');
            return ToolResult(
              toolName: definition.name,
              parameters: parameters,
              result: parts.join('. '),
              displayText: '✅ Kontakt "$name" gespeichert',
            );
          } else {
            return ToolResult(
              toolName: definition.name,
              parameters: parameters,
              result: 'Kontakt konnte nicht angelegt werden.',
              isError: true,
            );
          }

        case 'edit':
          if (contactId.isEmpty) {
            return ToolResult(
              toolName: definition.name,
              parameters: parameters,
              result: 'Fuer "edit" wird eine contactId benoetigt. Suche zuerst den Kontakt.',
              isError: true,
            );
          }
          if (phone.isEmpty && email.isEmpty) {
            return ToolResult(
              toolName: definition.name,
              parameters: parameters,
              result: 'Nichts zu aendern — gib phone oder email an.',
              isError: true,
            );
          }
          final ok = await _channel.invokeMethod('editContact', {
            'contactId': contactId,
            'phone': phone,
            'email': email,
          });
          if (ok == true) {
            final parts = <String>['Kontakt aktualisiert'];
            if (phone.isNotEmpty) parts.add('neue Tel: $phone');
            if (email.isNotEmpty) parts.add('neue E-Mail: $email');
            return ToolResult(
              toolName: definition.name,
              parameters: parameters,
              result: parts.join('. '),
              displayText: '✏️ Kontakt aktualisiert',
            );
          } else {
            return ToolResult(
              toolName: definition.name,
              parameters: parameters,
              result: 'Kontakt konnte nicht bearbeitet werden.',
              isError: true,
            );
          }

        case 'delete':
          if (contactId.isEmpty) {
            return ToolResult(
              toolName: definition.name,
              parameters: parameters,
              result: 'Fuer "delete" wird eine contactId benoetigt. Suche zuerst den Kontakt.',
              isError: true,
            );
          }
          final ok = await _channel.invokeMethod('deleteContact', {
            'contactId': contactId,
          });
          if (ok == true) {
            return ToolResult(
              toolName: definition.name,
              parameters: parameters,
              result: 'Kontakt geloescht.',
              displayText: '🗑️ Kontakt geloescht',
            );
          } else {
            return ToolResult(
              toolName: definition.name,
              parameters: parameters,
              result: 'Kontakt konnte nicht geloescht werden.',
              isError: true,
            );
          }

        default:
          return ToolResult(
            toolName: definition.name,
            parameters: parameters,
            result: 'Unbekannte Aktion: $action',
            isError: true,
          );
      }
    } on PlatformException catch (e) {
      if (e.code == 'PERMISSION_DENIED') {
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: 'Berechtigung fehlt. Bitte in den App-Einstellungen erlauben.',
          isError: true,
          displayText: 'Berechtigung fehlt',
        );
      }
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Fehler: ${e.message}',
        isError: true,
      );
    } catch (e) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Fehler: $e',
        isError: true,
      );
    }
  }
}
