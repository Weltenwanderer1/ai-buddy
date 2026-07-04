import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'tool_interface.dart';
import 'tool_definition.dart';
import 'tool_result.dart';

/// Searches the device contacts by name or phone number.
/// Uses the platform channel to fetch contacts from native code.
class SearchContactsTool implements ToolInterface {
  static const _channel = MethodChannel('com.ai-buddy.app/contacts');

  static const _definition = ToolDefinition(
    name: 'search_contacts',
    description: 'Sucht Geraetekontakte nach Name/Nummer.',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'query': {
          'type': 'string',
          'description': 'Suchbegriff: Name oder Teil des Namens, oder Telefonnummer',
        },
        'limit': {
          'type': 'integer',
          'description': 'Maximale Anzahl der Ergebnisse (Standard: 10)',
        },
      },
      'required': ['query'],
    },
  );

  @override
  ToolDefinition get definition => _definition;

  @override
  Future<ToolResult> execute(Map<String, dynamic> parameters) async {
    final query = parameters['query'] as String? ?? '';
    final limit = parameters['limit'] as int? ?? 10;

    if (query.isEmpty) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Kein Suchbegriff angegeben',
        isError: true,
        displayText: 'Kontaktsuche: kein Begriff',
      );
    }

    // Request contacts permission first
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
      final List contacts = await _channel.invokeMethod('searchContacts', {
        'query': query,
        'limit': limit,
      });

      if (contacts.isEmpty) {
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: 'Keine Kontakte fuer "$query" gefunden.',
          displayText: '🔍 Keine Kontakte fuer "$query"',
        );
      }

      // Format results for the LLM
      final buffer = StringBuffer();
      buffer.writeln('Gefunden: ${contacts.length} Kontakt(e) fuer "\$query":');
      buffer.writeln('(Verwende die ID (z.B. ID: 42) fuer Bearbeiten oder Loeschen)');
      buffer.writeln('');
      for (final contact in contacts) {
        final Map<String, dynamic> c = Map<String, dynamic>.from(contact);
        buffer.writeln('- ${c['name'] ?? 'Unbekannt'} (ID: ${c['id']})');
        final phones = c['phones'] as List? ?? [];
        for (final p in phones) {
          final Map<String, dynamic> phone = Map<String, dynamic>.from(p);
          buffer.writeln('  ${phone['label'] ?? 'Telefon'}: ${phone['number'] ?? ''}');
        }
        final emails = c['emails'] as List? ?? [];
        for (final e in emails) {
          final Map<String, dynamic> email = Map<String, dynamic>.from(e);
          buffer.writeln('  ${email['label'] ?? 'E-Mail'}: ${email['address'] ?? ''}');
        }
      }

      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: buffer.toString(),
        displayText: '🔍 ${contacts.length} Kontakt(e) gefunden',
      );
    } on PlatformException catch (e) {
      if (e.code == 'PERMISSION_DENIED') {
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: 'Berechtigung fuer Kontakte verweigert. Bitte in den App-Einstellungen erlauben.',
          isError: true,
          displayText: 'Kontaktberechtigung fehlt',
        );
      }
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Fehler bei Kontaktsuche: ${e.message}',
        isError: true,
        displayText: 'Kontaktsuche-Fehler',
      );
    } catch (e) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Fehler bei Kontaktsuche: $e',
        isError: true,
        displayText: 'Kontaktsuche-Fehler',
      );
    }
  }
}
