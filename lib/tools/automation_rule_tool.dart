import 'tool_interface.dart';
import 'tool_definition.dart';
import 'tool_result.dart';

/// Tool for managing automation rules ("If X then Y").
class AutomationRuleTool implements ToolInterface {
  static const _definition = ToolDefinition(
    name: 'automation_rule',
    description:
        'Automatisierungsregeln erstellen, auflisten, bearbeiten oder löschen. '
        'Regeln folgen dem Schema "Wenn [Trigger], dann [Aktionen]". '
        'Trigger: wifi_connect, wifi_disconnect, location_enter, location_leave, '
        'time_of_day, calendar_event, battery_low, battery_charging. '
        'Aktionen: set_volume, mute_device, send_notification, set_timer, open_app, set_wifi, set_bluetooth.',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'action': {
          'type': 'string',
          'description': 'Aktion: "create", "list", "update", "delete", "toggle"',
          'enum': ['create', 'list', 'update', 'delete', 'toggle'],
        },
        'rule_id': {
          'type': 'string',
          'description': 'Regel-ID (bei update/delete/toggle)',
        },
        'name': {
          'type': 'string',
          'description': 'Name der Regel',
        },
        'enabled': {
          'type': 'boolean',
          'description': 'Regel aktivieren/deaktivieren (bei toggle)',
        },
        'trigger': {
          'type': 'object',
          'description': 'Trigger-Definition: {type, params}',
          'properties': {
            'type': {'type': 'string'},
            'params': {'type': 'object'},
          },
        },
        'rules': {
          'type': 'array',
          'description': 'Liste von Aktionen: [{type, params}]',
          'items': {
            'type': 'object',
            'properties': {
              'type': {'type': 'string'},
              'params': {'type': 'object'},
            },
          },
        },
      },
      'required': ['action'],
    },
  );

  @override
  ToolDefinition get definition => _definition;

  /// Callbacks for CRUD operations.
  static Future<bool> Function({
    required String name,
    required Map<String, dynamic> trigger,
    required List<Map<String, dynamic>> actions,
  })? createRuleCallback;

  static Future<List<Map<String, dynamic>>> Function()? listRulesCallback;

  static Future<bool> Function({
    required String ruleId,
    String? name,
    Map<String, dynamic>? trigger,
    List<Map<String, dynamic>>? actions,
  })? updateRuleCallback;

  static Future<bool> Function({required String ruleId})? deleteRuleCallback;

  static Future<bool> Function({
    required String ruleId,
    required bool enabled,
  })? toggleRuleCallback;

  @override
  Future<ToolResult> execute(Map<String, dynamic> parameters) async {
    final action = (parameters['action'] as String?) ?? 'list';

    switch (action) {
      case 'create':
        return _createRule(parameters);
      case 'list':
        return _listRules();
      case 'update':
        return _updateRule(parameters);
      case 'delete':
        return _deleteRule(parameters);
      case 'toggle':
        return _toggleRule(parameters);
      default:
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: 'Unbekannte Aktion: $action',
          isError: true,
        );
    }
  }

  Future<ToolResult> _createRule(Map<String, dynamic> parameters) async {
    final name = (parameters['name'] as String?)?.trim() ?? '';
    final triggerData = parameters['trigger'] as Map<String, dynamic>?;
    final actionsData = parameters['rules'] as List<dynamic>?;

    if (name.isEmpty || triggerData == null || actionsData == null || actionsData.isEmpty) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Fehler: name, trigger und rules (Aktionen) sind erforderlich.',
        isError: true,
        displayText: '❌ Parameter fehlen',
      );
    }

    if (createRuleCallback == null) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Fehler: Automatisierungsdienst nicht verfügbar.',
        isError: true,
        displayText: '❌ Service nicht verfügbar',
      );
    }

    try {
      final actions = actionsData
          .map((a) => Map<String, dynamic>.from(a as Map))
          .toList();
      final success = await createRuleCallback!(
        name: name,
        trigger: triggerData,
        actions: actions,
      );
      if (success) {
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: 'Automatisierungsregel "$name" erstellt.',
          displayText: '⚡ Regel erstellt: $name',
        );
      }
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Fehler: Regel konnte nicht erstellt werden.',
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

  Future<ToolResult> _listRules() async {
    if (listRulesCallback == null) {
      return ToolResult(
        toolName: definition.name,
        parameters: {'action': 'list'},
        result: 'Fehler: Automatisierungsdienst nicht verfügbar.',
        isError: true,
        displayText: '❌ Service nicht verfügbar',
      );
    }

    try {
      final rules = await listRulesCallback!();
      if (rules.isEmpty) {
        return ToolResult(
          toolName: definition.name,
          parameters: {'action': 'list'},
          result: 'Keine Automatisierungsregeln vorhanden.',
          displayText: '⚡ Keine Regeln',
        );
      }

      final buffer = StringBuffer('Automatisierungsregeln:\n');
      for (final rule in rules) {
        final status = rule['enabled'] == true ? '✅' : '⏸️';
        buffer.writeln(
          '$status [${rule['id']}] ${rule['name']} — Trigger: ${rule['trigger_type']}',
        );
      }
      return ToolResult(
        toolName: definition.name,
        parameters: {'action': 'list'},
        result: buffer.toString(),
        displayText: '⚡ ${rules.length} Regel(n)',
      );
    } catch (e) {
      return ToolResult(
        toolName: definition.name,
        parameters: {'action': 'list'},
        result: 'Fehler: $e',
        isError: true,
        displayText: '❌ Fehler',
      );
    }
  }

  Future<ToolResult> _updateRule(Map<String, dynamic> parameters) async {
    final ruleId = (parameters['rule_id'] as String?)?.trim() ?? '';
    if (ruleId.isEmpty) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Fehler: rule_id erforderlich.',
        isError: true,
        displayText: '❌ Keine Regel-ID',
      );
    }

    if (updateRuleCallback == null) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Fehler: Service nicht verfügbar.',
        isError: true,
        displayText: '❌ Service nicht verfügbar',
      );
    }

    try {
      final name = parameters['name'] as String?;
      final trigger = parameters['trigger'] as Map<String, dynamic>?;
      final actionsData = parameters['rules'] as List<dynamic>?;
      final actions = actionsData
          ?.map((a) => Map<String, dynamic>.from(a as Map))
          .toList();

      final success = await updateRuleCallback!(
        ruleId: ruleId,
        name: name,
        trigger: trigger,
        actions: actions,
      );
      if (success) {
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: 'Regel $ruleId aktualisiert.',
          displayText: '⚡ Regel aktualisiert',
        );
      }
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Regel nicht gefunden.',
        isError: true,
        displayText: '❌ Nicht gefunden',
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

  Future<ToolResult> _deleteRule(Map<String, dynamic> parameters) async {
    final ruleId = (parameters['rule_id'] as String?)?.trim() ?? '';
    if (ruleId.isEmpty) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Fehler: rule_id erforderlich.',
        isError: true,
        displayText: '❌ Keine Regel-ID',
      );
    }

    if (deleteRuleCallback == null) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Fehler: Service nicht verfügbar.',
        isError: true,
        displayText: '❌ Service nicht verfügbar',
      );
    }

    try {
      final success = await deleteRuleCallback!(ruleId: ruleId);
      if (success) {
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: 'Regel $ruleId gelöscht.',
          displayText: '🗑️ Regel gelöscht',
        );
      }
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Regel nicht gefunden.',
        isError: true,
        displayText: '❌ Nicht gefunden',
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

  Future<ToolResult> _toggleRule(Map<String, dynamic> parameters) async {
    final ruleId = (parameters['rule_id'] as String?)?.trim() ?? '';
    final enabled = parameters['enabled'] as bool? ?? true;
    if (ruleId.isEmpty) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Fehler: rule_id erforderlich.',
        isError: true,
        displayText: '❌ Keine Regel-ID',
      );
    }

    if (toggleRuleCallback == null) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Fehler: Service nicht verfügbar.',
        isError: true,
        displayText: '❌ Service nicht verfügbar',
      );
    }

    try {
      final success = await toggleRuleCallback!(ruleId: ruleId, enabled: enabled);
      if (success) {
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: enabled
              ? 'Regel $ruleId aktiviert.'
              : 'Regel $ruleId deaktiviert.',
          displayText: enabled ? '⚡ Regel aktiviert' : '⏸️ Regel deaktiviert',
        );
      }
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Regel nicht gefunden.',
        isError: true,
        displayText: '❌ Nicht gefunden',
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
