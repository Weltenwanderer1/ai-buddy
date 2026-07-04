import 'dart:io';
import 'tool_interface.dart';
import 'tool_definition.dart';
import 'tool_result.dart';

class GetBatteryInfoTool implements ToolInterface {
  static const _definition = ToolDefinition(
    name: 'get_battery_info',
    description: 'Akkustand in Prozent und Ladestatus.',
    parametersSchema: {'type': 'object', 'properties': {}, 'required': []},
  );

  @override
  ToolDefinition get definition => _definition;

  @override
  Future<ToolResult> execute(Map<String, dynamic> parameters) async {
    try {
      int? level; String status = 'unbekannt';
      try {
        final f = File('/sys/class/power_supply/battery/capacity');
        if (await f.exists()) level = int.tryParse((await f.readAsString()).trim());
      } catch (_) {}
      try {
        final f = File('/sys/class/power_supply/battery/status');
        if (await f.exists()) {
          final raw = (await f.readAsString()).trim().toLowerCase();
          status = raw == 'charging' ? 'laedt' : raw == 'full' ? 'voll' : raw == 'discharging' ? 'entlaedt' : raw;
        }
      } catch (_) {}
      if (level == null) return ToolResult(toolName: definition.name, parameters: parameters, result: 'Nicht verfuegbar', isError: true, displayText: 'Keine Akku-Info');
      return ToolResult(toolName: definition.name, parameters: parameters, result: 'Akku: $level%, $status', displayText: 'Akku: $level% ($status)');
    } catch (e) {
      return ToolResult(toolName: definition.name, parameters: parameters, result: 'Fehler: $e', isError: true, displayText: 'Fehler');
    }
  }
}
