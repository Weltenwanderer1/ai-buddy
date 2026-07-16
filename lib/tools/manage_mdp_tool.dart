import 'tool_interface.dart';
import 'tool_definition.dart';
import 'tool_result.dart';
import '../services/mdp_service.dart';

/// Tool for managing medication schedule via chat.
class ManageMdpTool implements ToolInterface {
  final MdpService _mdpService;

  ManageMdpTool(this._mdpService);

  static const _definition = ToolDefinition(
    name: 'manage_mdp',
    description:
        'Medikamentenplan (MDP) verwalten: Eintrag hinzufügen, löschen oder '
        'als genommen markieren. Beispiele: "Erinner mich an Vitamin D '
        'jeden Morgen um 8 Uhr", "Ibuprofen 400 um 14 Uhr Mo/Mi/Fr", '
        '"Markier Metformin als genommen".',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'action': {
          'type': 'string',
          'description':
              'Aktion: "add" (hinzufuegen), "remove" (entfernen), '
              '"take" (als genommen markieren), "list" (alle aktiven anzeigen)',
          'enum': ['add', 'remove', 'take', 'list'],
        },
        'name': {
          'type': 'string',
          'description': 'Medikamentenname, z.B. "Vitamin D" oder "Ibuprofen"',
        },
        'dosage': {
          'type': 'string',
          'description': 'Dosierung, z.B. "1000 IE" oder "400 mg"',
        },
        'time': {
          'type': 'string',
          'description':
              'Uhrzeit im 24h-Format "HH:mm", z.B. "08:00". '
              'Standard: "08:00"',
        },
        'weekdays': {
          'type': 'string',
          'description':
              'Wochentage als Ziffern: "1,2,3,4,5,6,7" (1=Mo…7=So). '
              'Standard: "1,2,3,4,5,6,7" (taeglich). '
              'Nur Werktage: "1,2,3,4,5". Wochenende: "6,7"',
        },
        'note': {
          'type': 'string',
          'description': 'Notiz, z.B. "zum Essen" oder "vor dem Schlafen"',
        },
      },
      'required': ['action'],
    },
  );

  @override
  ToolDefinition get definition => _definition;

  @override
  Future<ToolResult> execute(Map<String, dynamic> parameters) async {
    final action = parameters['action'] as String? ?? 'list';
    final name = (parameters['name'] as String? ?? '').trim();
    final dosage = (parameters['dosage'] as String? ?? '').trim();
    String time = (parameters['time'] as String? ?? '08:00').trim();
    final note = (parameters['note'] as String? ?? '').trim();
    final weekdaysStr = (parameters['weekdays'] as String? ?? '1,2,3,4,5,6,7').trim();

    String resultText = '';
    String displayVal = '💊 Medikamentenplan';

    switch (action) {
      case 'add':
        if (name.isEmpty) {
          return ToolResult(
            toolName: definition.name,
            parameters: parameters,
            result: 'Fehler: Medikamentenname fehlt.',
            isError: true,
            displayText: '❌ Name fehlt',
          );
        }
        // Normalize time
        if (!time.contains(':')) {
          time = '$time:00';
        }
        // Parse weekdays
        List<int> weekdays;
        try {
          weekdays = weekdaysStr
              .split(RegExp(r'[,;.\s]+'))
              .map((s) => int.tryParse(s.trim()))
              .whereType<int>()
              .where((d) => d >= 1 && d <= 7)
              .toList();
          if (weekdays.isEmpty) weekdays = [1, 2, 3, 4, 5, 6, 7];
        } catch (_) {
          weekdays = [1, 2, 3, 4, 5, 6, 7];
        }

        final now = DateTime.now();
        final entry = MdpEntry(
          id: '${now.millisecondsSinceEpoch}_$name',
          name: name,
          dosage: dosage,
          time: time,
          weekdays: weekdays,
          note: note,
          createdAt: now,
        );
        await _mdpService.addEntry(entry);
        resultText = '"$name${dosage.isNotEmpty ? ' ($dosage)' : ''}" '
            'wurde zum Medikamentenplan hinzugefügt (${time} Uhr, ${entry.weekdayLabel}).';
        displayVal = '💊 +$name';
        break;

      case 'remove':
        if (name.isEmpty) {
          return ToolResult(
            toolName: definition.name,
            parameters: parameters,
            result: 'Fehler: Medikamentenname fehlt.',
            isError: true,
            displayText: '❌ Name fehlt',
          );
        }
        final found = _mdpService.entries.where(
          (e) => e.name.toLowerCase().contains(name.toLowerCase()),
        ).toList();
        if (found.isEmpty) {
          resultText = '"$name" nicht im Medikamentenplan gefunden.';
          displayVal = '❌ Nicht gefunden';
        } else {
          for (final e in found) {
            await _mdpService.removeEntry(e.id);
          }
          resultText = '${found.length} Eintrag${found.length > 1 ? 'e' : ''} zu "$name" entfernt.';
          displayVal = '🗑️ $name';
        }
        break;

      case 'take':
        if (name.isEmpty) {
          return ToolResult(
            toolName: definition.name,
            parameters: parameters,
            result: 'Fehler: Medikamentenname fehlt.',
            isError: true,
            displayText: '❌ Name fehlt',
          );
        }
        final dueNow = _mdpService.dueToday.where(
          (e) => e.name.toLowerCase().contains(name.toLowerCase()),
        ).toList();
        if (dueNow.isEmpty) {
          resultText = '"$name" ist heute nicht fällig oder bereits genommen.';
          displayVal = '❌ Nicht fällig';
        } else {
          for (final e in dueNow) {
            await _mdpService.markTaken(e.id);
          }
          resultText = '"$name" wurde als genommen markiert. ✅';
          displayVal = '✅ $name genommen';
        }
        break;

      case 'list':
      default:
        final due = _mdpService.dueToday;
        final allActive = _mdpService.activeEntries;
        if (allActive.isEmpty) {
          resultText = 'Dein Medikamentenplan ist aktuell leer.';
          displayVal = '💊 Keine Medikamente';
        } else {
          final buffer = StringBuffer('💊 Medikamentenplan (${allActive.length} aktiv):\n\n');
          buffer.writeln('Heute fällig:');
          if (due.isEmpty) {
            buffer.writeln('  ✅ Alle erledigt oder nichts geplant.');
          } else {
            for (final e in due) {
              buffer.writeln('  • 💊 $name${e.dosage.isNotEmpty ? ' (${e.dosage})' : ''} — ${e.time} Uhr');
            }
          }
          buffer.writeln('\nAlle aktiven:');
          for (final e in allActive) {
            final taken = _mdpService.isTaken(e.id);
            buffer.writeln('  ${taken ? '✅' : '💊'} $name${e.dosage.isNotEmpty ? ' (${e.dosage})' : ''} — ${e.time} ${e.weekdayLabel}');
          }
          resultText = buffer.toString();
          displayVal = '💊 ${allActive.length} Medikamente';
        }
        break;
    }

    return ToolResult(
      toolName: definition.name,
      parameters: parameters,
      result: resultText,
      displayText: displayVal,
    );
  }
}
