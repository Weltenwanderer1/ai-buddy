import 'dart:async';
import 'dart:convert';
import 'tool_interface.dart';
import 'tool_definition.dart';
import 'tool_result.dart';
import '../services/update_service.dart';

/// Check for app updates (GitHub Releases) and system status.
class CheckUpdateTool implements ToolInterface {
  static const _definition = ToolDefinition(
    name: 'check_update',
    description:
        'Prueft ob ein neues App-Update verfuegbar ist (GitHub Releases) '
        'und zeigt System-Status (Android-Version, Security-Patch).',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'includeSystemStatus': {
          'type': 'boolean',
          'description': 'Auch Android-System-Status anzeigen (default: true)',
        },
      },
      'required': [],
    },
  );

  @override
  ToolDefinition get definition => _definition;

  /// Injected service from main.dart
  static UpdateService? updateService;

  @override
  Future<ToolResult> execute(Map<String, dynamic> parameters) async {
    if (updateService == null) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: '{"error": "Update-Service nicht verfuegbar"}',
        isError: true,
        displayText: '❌ Update-Pruefung nicht verfuegbar',
      );
    }

    final includeSystem = parameters['includeSystemStatus'] as bool? ?? true;

    // Check app update
    final updateResult = await updateService!.checkAppUpdate();

    final parts = <String>[
      '📦 Ai-Buddy: ${updateResult.currentVersion}',
    ];

    if (updateResult.updateAvailable) {
      parts.add(
        '⬆️ Update verfuegbar: ${updateResult.latestVersion}\n'
        '   Release-Link: ${updateResult.releaseUrl ?? '—'}',
      );
      if (updateResult.releaseNotes != null && updateResult.releaseNotes!.isNotEmpty) {
        final notes = updateResult.releaseNotes!.replaceAll('\n', ' ');
        final short = notes.substring(0, 200);
        parts.add('   Notizen: $short...');
      }
    } else {
      parts.add('✅ Du hast die neueste Version.');
      if (updateResult.releaseNotes != null) {
        parts.add('   Hinweis: ${updateResult.releaseNotes}');
      }
    }

    // System status
    if (includeSystem) {
      final sys = await updateService!.getSystemStatus();
      parts.add(
        '\n🖥️ System: ${sys['platform']} ${sys['version'] ?? ''}\n'
        '   Security-Patch: ${sys['securityPatch'] ?? 'unbekannt'}\n'
        '   Gerät: ${sys['brand'] ?? ''} ${sys['model'] ?? ''}',
      );
    }

    final displayText = parts.join('\n');
    final jsonResult = <String, dynamic>{
      'currentVersion': updateResult.currentVersion,
      'updateAvailable': updateResult.updateAvailable,
      'latestVersion': updateResult.latestVersion,
      'releaseUrl': updateResult.releaseUrl,
    };

    return ToolResult(
      toolName: definition.name,
      parameters: parameters,
      result: jsonEncode(jsonResult),
      displayText: displayText,
    );
  }
}
