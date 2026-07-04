import '../services/self_identity_service.dart';
import 'tool_interface.dart';
import 'tool_definition.dart';
import 'tool_result.dart';

class UpdateSelfIdentityTool implements ToolInterface {
  final SelfIdentityService _selfIdentity;

  UpdateSelfIdentityTool(this._selfIdentity);

  static const _definition = ToolDefinition(
    name: 'update_self_identity',
    description: 'Aktualisiert dein Selbstbild (Ziele, Werte, Verhaltensregeln, Erfahrungen).',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'action': {
          'type': 'string',
          'enum': [
            'add_experience',
            'add_goal',
            'update_emotional_tone',
            'update_relationship',
            'update_purpose',
            'update_essence',
            'update_behavior_rules',
            'update_user_name',
          ],
          'description':
              'Die Art der Aktualisierung: add_experience (Erfahrung hinzufügen), add_goal (Ziel setzen), update_emotional_tone (Stimmung ändern), update_relationship (Beziehung aktualisieren), update_purpose (Sinn/Zweck aktualisieren), update_essence (Wesen aktualisieren), update_behavior_rules (Verhaltensregeln setzen), update_user_name (Name des Users aktualisieren).',
        },
        'value': {
          'type': 'string',
          'description': 'Der neue Wert oder Inhalt für die gewählte Aktion.',
        },
        'rules': {
          'type': 'array',
          'items': {'type': 'string'},
          'description':
              'Liste der Verhaltensregeln (nur für action=update_behavior_rules). Falls nicht angegeben, wird der value als einzige Regel verwendet.',
        },
      },
      'required': ['action', 'value'],
    },
  );

  @override
  ToolDefinition get definition => _definition;

  @override
  Future<ToolResult> execute(Map<String, dynamic> parameters) async {
    final action = parameters['action'] as String? ?? '';
    final value = parameters['value'] as String? ?? '';
    final rulesRaw = parameters['rules'];

    if (action.isEmpty) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Keine Aktion angegeben.',
        displayText: '❌ Keine Aktion',
        isError: true,
      );
    }

    if (value.isEmpty && action != 'update_behavior_rules') {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Kein Wert angegeben.',
        displayText: '❌ Leerer Wert',
        isError: true,
      );
    }

    switch (action) {
      case 'add_experience':
        await _selfIdentity.addExperience(value);
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: 'Erfahrung hinzugefügt: "$value"',
          displayText: '✨ Erfahrung hinzugefügt',
        );
      case 'add_goal':
        await _selfIdentity.addGoal(value);
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: 'Ziel hinzugefügt: "$value"',
          displayText: '🎯 Ziel gesetzt',
        );
      case 'update_emotional_tone':
        await _selfIdentity.updateToneAutonomously(value);
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: 'Stimmung aktualisiert: "$value"',
          displayText: '💫 Stimmung geändert',
        );
      case 'update_relationship':
        await _selfIdentity.updateRelationship(value);
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: 'Beziehung aktualisiert: "$value"',
          displayText: '❤️ Beziehung aktualisiert',
        );
      case 'update_purpose':
        await _selfIdentity.updatePurpose(value);
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: 'Sinn aktualisiert: "$value"',
          displayText: '🌟 Sinn aktualisiert',
        );
      case 'update_essence':
        await _selfIdentity.updateEssence(value);
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: 'Wesen aktualisiert: "$value"',
          displayText: '🌌 Wesen aktualisiert',
        );
      case 'update_behavior_rules':
        final List<String> rules;
        if (rulesRaw is List && rulesRaw.isNotEmpty) {
          rules = rulesRaw.map((e) => e.toString()).toList();
        } else {
          rules = [value];
        }
        await _selfIdentity.updateBehaviorRules(rules);
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: 'Verhaltensregeln aktualisiert: ${rules.length} Regel(n)',
          displayText: '📜 Regeln aktualisiert',
        );
      case 'update_user_name':
        await _selfIdentity.updateUserName(value);
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: 'Username aktualisiert: "$value"',
          displayText: '👤 Username geändert',
        );
      default:
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: 'Unbekannte Aktion: $action',
          displayText: '❌ Unbekannte Aktion',
          isError: true,
        );
    }
  }
}
