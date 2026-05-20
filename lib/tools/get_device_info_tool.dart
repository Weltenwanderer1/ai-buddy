import 'dart:io';
import 'tool_interface.dart';
import 'tool_definition.dart';
import 'tool_result.dart';

/// Returns device information: name, OS version, battery, storage.
class GetDeviceInfoTool implements ToolInterface {
  static const _definition = ToolDefinition(
    name: 'get_device_info',
    description:
        'Gibt Geräteinformationen zurück: Gerätename, Betriebssystemversion, freier Speicherplatz und Plattform.',
    parametersSchema: {
      'type': 'object',
      'properties': {},
      'required': [],
    },
  );

  @override
  ToolDefinition get definition => _definition;

  @override
  Future<ToolResult> execute(Map<String, dynamic> parameters) async {
    final platform = Platform.operatingSystem;
    final version = Platform.operatingSystemVersion;
    final hostname = Platform.localHostname;

    // Get storage info
    String storageInfo = 'Nicht verfügbar';
    try {
      final dir = Directory.systemTemp;
      // Try to get free space via df-like approach
      final result = await Process.run('df', ['-h', dir.path]);
      if (result.exitCode == 0) {
        final lines = (result.stdout as String).split('\n');
        if (lines.length >= 2) {
          storageInfo = lines[1].trim().replaceAll(RegExp(r'\s+'), ' ');
        }
      }
    } catch (_) {
      storageInfo = 'Speicherinfo nicht ermittelbar';
    }

    final result =
        'Gerät: $hostname\nPlattform: $platform\nOS-Version: $version\nSpeicher: $storageInfo';

    return ToolResult(
      toolName: definition.name,
      parameters: parameters,
      result: result,
      displayText: '📱 Geräteinfo abgerufen',
    );
  }
}
