import 'package:flutter/services.dart';
import 'tool_interface.dart';
import 'tool_definition.dart';
import 'tool_result.dart';

/// Toggles WiFi on/off and queries its state.
class ToggleWifiTool implements ToolInterface {
  static const _channel = MethodChannel('com.aibuddy.app/wifi');

  static const _definition = ToolDefinition(
    name: 'toggle_wifi',
    description:
        'WLAN ein- oder ausschalten oder Status abfragen. '
        'Aktionen: "on" (einschalten), "off" (ausschalten), "status" (abfragen).',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'action': {
          'type': 'string',
          'description': 'Aktion: "on", "off" oder "status"',
          'enum': ['on', 'off', 'status'],
        },
      },
      'required': ['action'],
    },
  );

  @override
  ToolDefinition get definition => _definition;

  @override
  Future<ToolResult> execute(Map<String, dynamic> parameters) async {
    final action = (parameters['action'] as String?) ?? 'status';

    try {
      switch (action) {
        case 'on':
          final success = await _channel.invokeMethod('setWifiEnabled', {'enabled': true});
          if (success == true) {
            return ToolResult(
              toolName: definition.name,
              parameters: parameters,
              result: 'WLAN eingeschaltet.',
              displayText: '📶 WLAN an',
            );
          }
          return ToolResult(
            toolName: definition.name,
            parameters: parameters,
            result: 'Fehler: WLAN konnte nicht eingeschaltet werden.',
            isError: true,
            displayText: '❌ WLAN-Fehler',
          );

        case 'off':
          final success = await _channel.invokeMethod('setWifiEnabled', {'enabled': false});
          if (success == true) {
            return ToolResult(
              toolName: definition.name,
              parameters: parameters,
              result: 'WLAN ausgeschaltet.',
              displayText: '📶 WLAN aus',
            );
          }
          return ToolResult(
            toolName: definition.name,
            parameters: parameters,
            result: 'Fehler: WLAN konnte nicht ausgeschaltet werden.',
            isError: true,
            displayText: '❌ WLAN-Fehler',
          );

        case 'status':
          final enabled = await _channel.invokeMethod('getWifiState');
          return ToolResult(
            toolName: definition.name,
            parameters: parameters,
            result: enabled == true ? 'WLAN ist eingeschaltet.' : 'WLAN ist ausgeschaltet.',
            displayText: enabled == true ? '📶 WLAN: an' : '📶 WLAN: aus',
          );

        default:
          return ToolResult(
            toolName: definition.name,
            parameters: parameters,
            result: 'Unbekannte Aktion: $action',
            isError: true,
          );
      }
    } catch (e) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Fehler: $e',
        isError: true,
        displayText: '❌ WLAN-Fehler',
      );
    }
  }
}
