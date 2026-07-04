import 'package:flutter/services.dart';
import 'tool_interface.dart';
import 'tool_definition.dart';
import 'tool_result.dart';

/// Toggles Bluetooth on/off and queries its state.
class ToggleBluetoothTool implements ToolInterface {
  static const _channel = MethodChannel('com.aibuddy.app/bluetooth');

  static const _definition = ToolDefinition(
    name: 'toggle_bluetooth',
    description:
        'Bluetooth ein- oder ausschalten oder Status abfragen. '
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
          final success = await _channel.invokeMethod('setBluetoothEnabled', {'enabled': true});
          if (success == true) {
            return ToolResult(
              toolName: definition.name,
              parameters: parameters,
              result: 'Bluetooth eingeschaltet.',
              displayText: '🔵 Bluetooth an',
            );
          }
          return ToolResult(
            toolName: definition.name,
            parameters: parameters,
            result: 'Fehler: Bluetooth konnte nicht eingeschaltet werden. Berechtigung fehlt möglicherweise.',
            isError: true,
            displayText: '❌ Bluetooth-Fehler',
          );

        case 'off':
          final success = await _channel.invokeMethod('setBluetoothEnabled', {'enabled': false});
          if (success == true) {
            return ToolResult(
              toolName: definition.name,
              parameters: parameters,
              result: 'Bluetooth ausgeschaltet.',
              displayText: '🔵 Bluetooth aus',
            );
          }
          return ToolResult(
            toolName: definition.name,
            parameters: parameters,
            result: 'Fehler: Bluetooth konnte nicht ausgeschaltet werden.',
            isError: true,
            displayText: '❌ Bluetooth-Fehler',
          );

        case 'status':
          final enabled = await _channel.invokeMethod('getBluetoothState');
          return ToolResult(
            toolName: definition.name,
            parameters: parameters,
            result: enabled == true
                ? 'Bluetooth ist eingeschaltet.'
                : 'Bluetooth ist ausgeschaltet.',
            displayText: enabled == true ? '🔵 Bluetooth: an' : '🔵 Bluetooth: aus',
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
        displayText: '❌ Bluetooth-Fehler',
      );
    }
  }
}
