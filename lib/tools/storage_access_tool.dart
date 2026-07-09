import 'package:flutter/services.dart';
import 'tool_definition.dart';
import 'tool_interface.dart';
import 'tool_result.dart';

/// Checks and requests "All files access" so the buddy's file tools
/// (read_file/write_file/list_files/…) can reach the whole device storage,
/// not only its private sandbox. Call "check" before broad file work; if it
/// returns false, call "request" to open the system grant screen.
class StorageAccessTool implements ToolInterface {
  static const MethodChannel _channel = MethodChannel('com.aibuddy.app/files');

  static const _definition = ToolDefinition(
    name: 'storage_access',
    description:
        'Prueft oder beantragt den vollen Dateizugriff ("Zugriff auf alle Dateien"), '
        'damit read_file/write_file/list_files auf das ganze Geraet zugreifen koennen '
        '(z.B. /storage/emulated/0/Download). '
        'Aktionen: "check" (ist Zugriff erteilt?), "request" (Systemdialog oeffnen).',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'action': {
          'type': 'string',
          'enum': ['check', 'request'],
          'description': 'check = Status pruefen, request = Berechtigung anfragen',
        },
      },
      'required': ['action'],
    },
  );

  @override
  ToolDefinition get definition => _definition;

  @override
  Future<ToolResult> execute(Map<String, dynamic> parameters) async {
    final action = (parameters['action'] as String?)?.trim() ?? 'check';
    try {
      if (action == 'request') {
        final opened = await _channel.invokeMethod('requestAllFilesAccess') as bool? ?? false;
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: opened
              ? 'Berechtigungsdialog geoeffnet. Bitte "Zugriff auf alle Dateien zulassen" fuer AI-Buddy aktivieren, dann zurueckkehren.'
              : 'Konnte den Berechtigungsdialog nicht oeffnen.',
          isError: !opened,
          displayText: opened ? '📂 Zugriff anfragen' : '❌ Fehlgeschlagen',
        );
      }

      final granted = await _channel.invokeMethod('hasAllFilesAccess') as bool? ?? false;
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: granted
            ? 'Voller Dateizugriff ist erteilt — ich kann auf alle Dateien zugreifen.'
            : 'Kein voller Dateizugriff. Rufe storage_access mit action "request" auf, damit der Nutzer ihn erteilt.',
        displayText: granted ? '📂 Zugriff erteilt' : '📂 Zugriff fehlt',
      );
    } on PlatformException catch (e) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Fehler: ${e.message}',
        isError: true,
        displayText: '❌ Fehler',
      );
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
