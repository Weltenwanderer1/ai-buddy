import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'tool_interface.dart';
import 'tool_definition.dart';
import 'tool_result.dart';

/// Makes phone calls or opens the dialer.
class PhoneCallTool implements ToolInterface {
  static const _channel = MethodChannel('com.ai-buddy.app/contacts');

  static const _definition = ToolDefinition(
    name: 'phone_call',
    description: 'Startet einen Telefonanruf oder oeffnet den Telefon-Waehlscheibe.',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'number': {
          'type': 'string',
          'description': 'Telefonnummer (nur Ziffern, + und Leerzeichen)',
        },
        'contactId': {
          'type': 'string',
          'description': 'Optional: Kontakt-ID. Wenn gegeben, wird dessen Nummer verwendet.',
        },
        'mode': {
          'type': 'string',
          'enum': ['direct', 'dialer'],
          'description': 'direct=sofort anrufen (braucht Berechtigung), dialer=nur Waehlscheibe oeffnen',
        },
      },
      'required': ['number', 'mode'],
    },
  );

  @override
  ToolDefinition get definition => _definition;

  @override
  Future<ToolResult> execute(Map<String, dynamic> parameters) async {
    String number = parameters['number'] as String? ?? '';
    final contactId = parameters['contactId'] as String? ?? '';
    final mode = parameters['mode'] as String? ?? 'dialer';

    // If contactId given, fetch number
    if (contactId.isNotEmpty) {
      try {
        final fetched = await _channel.invokeMethod('searchContacts', {
          'query': contactId,
          'limit': 1,
        });
        if (fetched is List && fetched.isNotEmpty && fetched[0] is Map) {
          final contact = fetched[0] as Map;
          final phones = contact['phones'];
          if (phones is List && phones.isNotEmpty && phones[0] is Map) {
            number = ((phones[0] as Map)['number'] as String?) ?? '';
          }
        }
      } on PlatformException catch (e) {
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: 'Kontakt konnte nicht geladen werden: ${e.message}',
          isError: true,
          displayText: 'Kontakt-Fehler',
        );
      }
    }

    final cleanNumber = number.replaceAll(RegExp(r'[^\d+]'), '').trim();
    if (cleanNumber.isEmpty) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Keine gueltige Telefonnummer angegeben.',
        isError: true,
      );
    }

    if (mode == 'dialer') {
      final ok = await _channel.invokeMethod('openDialer', {'number': cleanNumber});
      // Always return here — never fall through to a direct call. A failed
      // dialer must NOT silently place a real phone call.
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: ok == true
            ? 'Waehlscheibe fuer $number wurde geoeffnet.'
            : 'Waehlscheibe konnte nicht geoeffnet werden.',
        isError: ok != true,
        displayText: ok == true ? '📞 Waehlscheibe geoeffnet' : '❌ Waehlscheibe fehlgeschlagen',
      );
    }

    // Direct call (mode == 'direct')
    final perm = await Permission.phone.request();
    if (!perm.isGranted) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Anrufberechtigung verweigert. Die App kann keine Telefonanrufe starten.',
        isError: true,
        displayText: 'Anruf-Berechtigung fehlt',
      );
    }

    try {
      final ok = await _channel.invokeMethod('makePhoneCall', {'number': cleanNumber});
      if (ok == true) {
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: 'Anruf an $number gestartet...',
          displayText: '📞 Rufe $number...',
        );
      } else {
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: 'Anruf konnte nicht gestartet werden.',
          isError: true,
        );
      }
    } on PlatformException catch (e) {
      if (e.code == 'PERMISSION_DENIED') {
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: 'Berechtigung fehlt. In den App-Einstellungen CALL_PHONE erlauben.',
          isError: true,
          displayText: 'Berechtigung fehlt',
        );
      }
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Fehler beim Anruf: ${e.message}',
        isError: true,
      );
    }
  }
}
