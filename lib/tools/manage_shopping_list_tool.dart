import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/android_app_launcher_service.dart';
import 'tool_interface.dart';
import 'tool_definition.dart';
import 'tool_result.dart';

/// Manages a local shopping list and offers integration with the Bring! app.
class ManageShoppingListTool implements ToolInterface {
  static const String _storageKey = 'shopping_list_items';
  static const String _bringPackage = 'ch.bring.android';

  static const _definition = ToolDefinition(
    name: 'manage_shopping_list',
    description: 'Einkaufsliste verwalten (add/remove/list/clear). Optional: Bring! App oeffnen.',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'action': {
          'type': 'string',
          'description': 'Aktion: "add" (hinzufuegen), "remove" (entfernen), "list" (anzeigen), "clear" (leeren)',
          'enum': ['add', 'remove', 'list', 'clear']
        },
        'item': {
          'type': 'string',
          'description': 'Name des Artikels (z.B. "Pizza", "Milch"), erforderlich fuer "add" und "remove"',
        },
        'launch_bring': {
          'type': 'boolean',
          'description': 'Falls wahr, wird zusaetzlich versucht, die Bring! Einkaufsliste-App zu oeffnen.',
        }
      },
      'required': ['action'],
    },
  );

  @override
  ToolDefinition get definition => _definition;

  @override
  Future<ToolResult> execute(Map<String, dynamic> parameters) async {
    final action = parameters['action'] as String? ?? 'list';
    final item = (parameters['item'] as String? ?? '').trim();
    final launchBring = parameters['launch_bring'] as bool? ?? false;

    final prefs = await SharedPreferences.getInstance();
    List<String> items = [];
    final raw = prefs.getString(_storageKey);
    if (raw != null) {
      try {
        items = List<String>.from(jsonDecode(raw));
      } catch (_) {}
    }

    String resultText = '';
    String displayVal = '🛒 Einkaufsliste';

    switch (action) {
      case 'add':
        if (item.isEmpty) {
          return ToolResult(
            toolName: definition.name,
            parameters: parameters,
            result: 'Fehler: Artikelname fehlt für das Hinzufügen.',
            isError: true,
            displayText: '❌ Artikel fehlt',
          );
        }
        if (!items.contains(item)) {
          items.add(item);
          await prefs.setString(_storageKey, jsonEncode(items));
        }
        resultText = '"$item" wurde zur Einkaufsliste hinzugefügt. Aktuelle Liste: ${items.join(', ')}.';
        displayVal = '➕ Hinzugefügt: $item';
        break;

      case 'remove':
        if (item.isEmpty) {
          return ToolResult(
            toolName: definition.name,
            parameters: parameters,
            result: 'Fehler: Artikelname fehlt für das Entfernen.',
            isError: true,
            displayText: '❌ Artikel fehlt',
          );
        }
        items.remove(item);
        await prefs.setString(_storageKey, jsonEncode(items));
        resultText = '"$item" wurde aus der Einkaufsliste entfernt. Aktuelle Liste: ${items.isEmpty ? 'leer' : items.join(', ')}.';
        displayVal = '➖ Entfernt: $item';
        break;

      case 'clear':
        items.clear();
        await prefs.remove(_storageKey);
        resultText = 'Die Einkaufsliste wurde geleert.';
        displayVal = '🗑️ Liste geleert';
        break;

      case 'list':
      default:
        if (items.isEmpty) {
          resultText = 'Deine Einkaufsliste ist aktuell leer.';
          displayVal = '🛒 Liste leer';
        } else {
          resultText = 'Einkaufsliste Artikel: ${items.join(', ')}.';
          displayVal = '🛒 ${items.length} Artikel';
        }
        break;
    }

    if (launchBring || (action == 'add' && item.toLowerCase().contains('bring'))) {
      try {
        final launched = await AndroidAppLauncherService.launchApp(_bringPackage);
        if (launched) {
          resultText += ' Bring! App wurde gestartet.';
        } else {
          resultText += ' Bring! App konnte nicht gestartet werden (nicht installiert).';
        }
      } catch (e) {
        resultText += ' Fehler beim Starten von Bring!: $e';
      }
    }

    return ToolResult(
      toolName: definition.name,
      parameters: parameters,
      result: resultText,
      displayText: displayVal,
    );
  }
}
