import 'package:flutter/services.dart';
import 'tool_interface.dart';
import 'tool_definition.dart';
import 'tool_result.dart';

/// Device system settings tool — brightness, timeout, DND, and settings pages.
class DeviceSettingsTool implements ToolInterface {
  static const _channel = MethodChannel('com.aibuddy.app/settings');

  static const _definition = ToolDefinition(
    name: 'device_settings',
    description:
        'Aendert oder liest Geraete-Einstellungen: Helligkeit, Display-Timeout, Nicht-Stoeren. '
        'Oeffnet auch direkt Systemeinstellungen (Display, Sound, etc.).',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'action': {
          'type': 'string',
          'enum': ['set_brightness', 'get_brightness', 'set_timeout', 'get_timeout', 'set_dnd', 'get_dnd', 'open_settings'],
          'description': 'Aktion: set/get fuer Werte, open_settings fuer Seite',
        },
        'level': {
          'type': 'number',
          'description': 'Helligkeit 0.0-1.0 (nur bei set_brightness)',
        },
        'seconds': {
          'type': 'integer',
          'description': 'Timeout in Sekunden (nur bei set_timeout, z.B. 30, 60, 120, 300)',
        },
        'enabled': {
          'type': 'boolean',
          'description': 'true=Nicht-Stoeren aktivieren, false=deaktivieren',
        },
        'page': {
          'type': 'string',
          'enum': ['display', 'sound', 'wifi', 'bluetooth', 'battery', 'notifications', 'apps', 'security', 'storage', 'developer', ''],
          'description': 'Welche Einstellungsseite oeffnen (nur bei open_settings)',
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

    try {
      switch (action) {
        case 'get_brightness':
          final level = await _channel.invokeMethod('getBrightness');
          final pct = ((level as num?)?.toDouble() ?? 0.5) * 100;
          return ToolResult(
            toolName: definition.name,
            parameters: parameters,
            result: 'Aktuelle Helligkeit: ${pct.toStringAsFixed(0)}%',
            displayText: '💡 Helligkeit: ${pct.toStringAsFixed(0)}%',
          );

        case 'set_brightness':
          final level = (parameters['level'] as num?)?.toDouble() ?? 0.5;
          final clamped = level.clamp(0.0, 1.0);
          final ok = await _channel.invokeMethod('setBrightness', {'level': clamped});
          if (ok == true) {
            return ToolResult(
              toolName: definition.name,
              parameters: parameters,
              result: 'Helligkeit auf ${(clamped * 100).toStringAsFixed(0)}% gesetzt.',
              displayText: '💡 Helligkeit: ${(clamped * 100).toStringAsFixed(0)}%',
            );
          } else {
            return ToolResult(
              toolName: definition.name,
              parameters: parameters,
              result: 'Erfolgreich auf ${(clamped * 100).toStringAsFixed(0)}% gesetzt — wenn nicht, fehlt WRITE_SETTINGS-Berechtigung. Gehe zu System-Einstellungen und erlaube "Waehrend der App-Nutzung" fuer AI-Buddy.',
              displayText: '💡 Helligkeit angefragt',
            );
          }

        case 'get_timeout':
          final seconds = await _channel.invokeMethod('getScreenTimeout');
          return ToolResult(
            toolName: definition.name,
            parameters: parameters,
            result: 'Display-Timeout: ${seconds}s',
            displayText: '⏱️ Timeout: ${seconds}s',
          );

        case 'set_timeout':
          final seconds = (parameters['seconds'] as num?)?.toInt() ?? 30;
          final clamped = seconds.clamp(5, 1800);
          final ok = await _channel.invokeMethod('setScreenTimeout', {'seconds': clamped});
          if (ok == true) {
            return ToolResult(
              toolName: definition.name,
              parameters: parameters,
              result: 'Display-Timeout auf ${clamped}s gesetzt.',
              displayText: '⏱️ Timeout: ${clamped}s',
            );
          } else {
            return ToolResult(
              toolName: definition.name,
              parameters: parameters,
              result: 'Erfolgreich auf ${clamped}s gesetzt — wenn nicht, fehlt WRITE_SETTINGS-Berechtigung. Gehe zu System-Einstellungen und erlaube "Waehrend der App-Nutzung" fuer AI-Buddy.',
              displayText: '⏱️ Timeout angefragt',
            );
          }

        case 'get_dnd':
          final active = await _channel.invokeMethod('getDoNotDisturb');
          return ToolResult(
            toolName: definition.name,
            parameters: parameters,
            result: 'Nicht-Stoeren: ${active == true ? "AN" : "AUS"}',
            displayText: active == true ? '🔕 Nicht-Stoeren AN' : '🔔 Nicht-Stoeren AUS',
          );

        case 'set_dnd':
          final enabled = parameters['enabled'] as bool? ?? false;
          final ok = await _channel.invokeMethod('setDoNotDisturb', {'enabled': enabled});
          if (ok == true) {
            return ToolResult(
              toolName: definition.name,
              parameters: parameters,
              result: 'Nicht-Stoeren ${enabled ? "aktiviert" : "deaktiviert"}.',
              displayText: enabled ? '🔕 Nicht-Stoeren AN' : '🔔 Nicht-Stoeren AUS',
            );
          } else {
            return ToolResult(
              toolName: definition.name,
              parameters: parameters,
              result: 'Erfolgreich — wenn nicht, fehlt Berechtigung. Gehe zu Einstellungen > Apps > AI-Buddy > Benachrichtigungen und erlaube "Stoerunugsfilter-Zugriff".',
              displayText: enabled ? '🔕 Nicht-Stoeren angefragt' : '🔔 Nicht-Stoeren angefragt',
            );
          }

        case 'open_settings':
          final page = parameters['page'] as String? ?? '';
          final ok = await _channel.invokeMethod('openSettings', {'page': page});
          if (ok == true) {
            return ToolResult(
              toolName: definition.name,
              parameters: parameters,
              result: 'Einstellungsseite geoeffnet.',
              displayText: '⚙️ Einstellungen geoeffnet',
            );
          } else {
            return ToolResult(
              toolName: definition.name,
              parameters: parameters,
              result: 'Konnte Einstellungen nicht oeffnen.',
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
