import 'package:flutter/foundation.dart';
import 'tool_interface.dart';
import 'tool_definition.dart';
import 'tool_result.dart';
import '../services/dictation_service.dart';
import '../services/settings_service.dart';

/// Tool: "dictate_note" — records voice via STT and saves to BuddyNotes.
class DictationTool implements ToolInterface {
  DictationTool({
    required DictationService dictationService,
    required SettingsService settingsService,
  })  : _dictation = dictationService,
        _settings = settingsService;

  final DictationService _dictation;
  final SettingsService _settings;

  static final _definition = ToolDefinition(
    name: 'dictate_note',
    description: 'Record a voice memo via the microphone, '
        'transcribe it, and save it as a note. Use this when the user wants '
        'to quickly capture a thought, idea, or reminder by speaking.',
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
    try {
      final lang = _settings.appLanguage;
      final locale = switch (lang) {
        'de' => 'de_DE',
        'es' => 'es_ES',
        'en' => 'en_US',
        _ => 'en_US',
      };

      final text = await _dictation.recordAndSave(locale: locale);

      if (text == null) {
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: 'Dictation cancelled or no speech detected.',
          isError: true,
          displayText: '🎙️ Keine Sprache erkannt oder abgebrochen.',
        );
      }

      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Dictation saved: $text',
        displayText: '🎙️ Notiz gespeichert: "$text"',
      );
    } catch (e) {
      debugPrint('DictationTool error: $e');
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Dictation failed: $e',
        isError: true,
        displayText: '❌ Diktier-Notiz fehlgeschlagen.',
      );
    }
  }
}
