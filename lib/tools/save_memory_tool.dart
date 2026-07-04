import '../services/memory_service.dart';
import 'tool_interface.dart';
import 'tool_definition.dart';
import 'tool_result.dart';

class SaveMemoryTool implements ToolInterface {
  final MemoryService _memory;
  SaveMemoryTool(this._memory);

  static const _minContentLength = 10;

  static const _definition = ToolDefinition(
    name: 'save_memory',
    description: 'Speichere eine wichtige Info dauerhaft. VOLLSTAENDIGE SAETZE Pflicht — keine Einzelwoerter oder Fragmente.',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'content': {
          'type': 'string',
          'description': 'Die zu speichernde Information als vollstaendiger Satz. Mindestens 10 Zeichen. Beispiele: "Der Nutzer heisst Guenther und wohnt in Wien" — NICHT nur "Guenther". "Der Nutzer mag keine Suessigkeiten" — NICHT nur "Suessigkeiten".',
        },
        'tier': {
          'type': 'string',
          'enum': ['core', 'long_term'],
          'description': 'Speicher-Tier: "core" für identitätsprägend (wer ist der Nutzer, Beziehung, fundamentale Fakten), "long_term" für wichtige Fakten und Vorlieben.',
        },
        'source': {
          'type': 'string',
          'description': 'Quelle der Information (z.B. "user", "conversation", "extracted"). Standard: "extracted".',
        },
      },
      'required': ['content', 'tier'],
    },
  );

  @override
  ToolDefinition get definition => _definition;

  @override
  Future<ToolResult> execute(Map<String, dynamic> parameters) async {
    final content = parameters['content'] as String? ?? '';
    final tier = parameters['tier'] as String? ?? 'long_term';
    final source = parameters['source'] as String? ?? 'extracted';

    if (content.isEmpty) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Kein Inhalt zum Speichern.',
        displayText: '❌ Leere Information',
        isError: true,
      );
    }

    // Quality gate: reject fragments that are too short or lack context
    final trimmed = content.trim();
    if (trimmed.length < _minContentLength) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Abgelehnt: Inhalt zu kurz (${"${trimmed.length}"} Zeichen, Minimum $_minContentLength). '
            'Speichere vollstaendige Saetze mit Kontext, keine Einzelwoerter. '
            'Beispiel: "Der Nutzer heisst Guenther" statt nur "Guentther".',
        displayText: '⚠️ Zu kurz — bitte vollständigen Satz',
        isError: true,
      );
    }

    // Quality gate: reject if it looks like a single word or fragment
    final wordCount = trimmed.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    if (wordCount < 3) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Abgelehnt: Inhalt ist ein Fragment ($wordCount Wörter). '
            'Speichere vollstaendige Saetze: "Der Nutzer mag Pizza" statt nur "Pizza".',
        displayText: '⚠️ Fragment — bitte vollständigen Satz',
        isError: true,
      );
    }

    // Check for duplicates in the target tier
    if (tier == 'core') {
      final existing = _memory.coreMemories;
      if (existing.any((m) => _similarity(m.content, trimmed) > 0.85)) {
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: 'Bereits im Core-Gedaechtnis vorhanden: "$trimmed"',
          displayText: '💾 Bereits gespeichert',
        );
      }
      await _memory.addCore(content, source: source);
    } else {
      final existing = _memory.longTermMemories;
      if (existing.any((m) => _similarity(m.content, trimmed) > 0.85)) {
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: 'Bereits im Langzeitgedächtnis vorhanden: "$trimmed"',
          displayText: '💾 Bereits gespeichert',
        );
      }
      await _memory.addLongTerm(content, source: source);
    }

    // Effektiven Tier melden — alles außer 'core' landet im Langzeit-
    // gedächtnis, auch wenn das Modell z.B. 'short_term' angegeben hat.
    final effectiveTier = tier == 'core' ? 'core' : 'long_term';
    return ToolResult(
      toolName: definition.name,
      parameters: parameters,
      result: 'Gespeichert als $effectiveTier: "$content"',
      displayText: '💾 Gespeichert ($effectiveTier)',
    );
  }

  double _similarity(String a, String b) {
    final ta = a.toLowerCase().split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toSet();
    final tb = b.toLowerCase().split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toSet();
    if (ta.isEmpty || tb.isEmpty) return 0.0;
    final inter = ta.intersection(tb).length;
    return inter / (ta.length + tb.length - inter);
  }
}