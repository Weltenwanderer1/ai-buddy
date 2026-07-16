import '../services/android_app_launcher_service.dart';
import '../services/shopping_service.dart';
import 'tool_interface.dart';
import 'tool_definition.dart';
import 'tool_result.dart';

/// Manages a categorized shopping list with receipt scanning support.
class ManageShoppingListTool implements ToolInterface {
  final ShoppingService _shoppingService;

  ManageShoppingListTool(this._shoppingService);

  static const String _bringPackage = 'ch.bring.android';

  static const _definition = ToolDefinition(
    name: 'manage_shopping_list',
    description:
        'Einkaufsliste verwalten (add/remove/list/clear). '
        'Erkennt Kategorien automatisch (Obst, Molkerei, etc.). '
        'Kann mehrere Artikel auf einmal hinzufügen: "add milch, brot, eier". '
        'Optional: Bring! App oeffnen.',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'action': {
          'type': 'string',
          'description':
              'Aktion: "add" (hinzufuegen, mehrere mit Komma trennen), '
              '"remove" (entfernen), "list" (anzeigen), "clear" (leeren)',
          'enum': ['add', 'remove', 'list', 'clear'],
        },
        'item': {
          'type': 'string',
          'description':
              'Name des Artikels oder mehrere durch Komma getrennt '
              '(z.B. "Milch, Brot, Äpfel"). Erforderlich fuer "add" und "remove".',
        },
        'category': {
          'type': 'string',
          'description':
              'Kategorie (optional): Obst & Gemüse, Molkerei & Eier, '
              'Brot & Getreide, Fleisch & Fisch, Getränke, Tiefkühl, '
              'Haushalt, Körperpflege, Baby & Kind, Tierbedarf, Sonstiges. '
              'Standard: automatische Erkennung.',
        },
        'launch_bring': {
          'type': 'boolean',
          'description':
              'Falls wahr, wird der Artikel per Share-Intent an die Bring! App '
              'gesendet. Setze true, wenn der Nutzer Bring! verwendet.',
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
    final rawItem = (parameters['item'] as String? ?? '').trim();
    final category = parameters['category'] as String?;
    final launchBring = parameters['launch_bring'] as bool? ?? false;

    String resultText = '';
    String displayVal = '🛒 Einkaufsliste';

    switch (action) {
      case 'add':
        if (rawItem.isEmpty) {
          return ToolResult(
            toolName: definition.name,
            parameters: parameters,
            result: 'Fehler: Artikelname fehlt.',
            isError: true,
            displayText: '❌ Artikel fehlt',
          );
        }
        // Support comma-separated batch add
        final items = rawItem
            .split(RegExp(r'[,;]\s*'))
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();

        int added = 0;
        for (final item in items) {
          final cat = category ?? ShoppingService.guessCategory(item);
          await _shoppingService.addItem(item, category: cat);
          added++;
        }

        if (added == 1) {
          resultText = '"$rawItem" wurde zur Einkaufsliste hinzugefügt.';
          displayVal = '➕ $rawItem';
        } else {
          resultText = '$added Artikel wurden hinzugefügt: ${items.join(", ")}.';
          displayVal = '➕ $added Artikel';
        }
        break;

      case 'remove':
        if (rawItem.isEmpty) {
          return ToolResult(
            toolName: definition.name,
            parameters: parameters,
            result: 'Fehler: Artikelname fehlt für das Entfernen.',
            isError: true,
            displayText: '❌ Artikel fehlt',
          );
        }
        // Find and remove item
        final idx = _shoppingService.items.indexWhere(
          (i) => i.name.toLowerCase() == rawItem.toLowerCase(),
        );
        if (idx >= 0) {
          final name = _shoppingService.items[idx].name;
          await _shoppingService.removeItem(idx);
          resultText = '"$name" wurde entfernt.';
          displayVal = '➖ $name';
        } else {
          resultText = '"$rawItem" nicht in der Liste gefunden.';
          displayVal = '❌ Nicht gefunden';
        }
        break;

      case 'clear':
        await _shoppingService.clearAll();
        resultText = 'Die Einkaufsliste wurde geleert.';
        displayVal = '🗑️ Liste geleert';
        break;

      case 'list':
      default:
        if (_shoppingService.totalCount == 0) {
          resultText = 'Deine Einkaufsliste ist aktuell leer.';
          displayVal = '🛒 Liste leer';
        } else {
          final grouped = _shoppingService.groupedItems;
          final buffer = StringBuffer('Einkaufsliste (${_shoppingService.totalCount} Artikel):\n');
          for (final entry in grouped.entries) {
            final unchecked = entry.value.where((i) => !i.checked).toList();
            if (unchecked.isNotEmpty) {
              buffer.writeln('\n${entry.key}:');
              for (final item in unchecked) {
                buffer.writeln('  • ${item.name}');
              }
            }
          }
          resultText = buffer.toString().trim();
          displayVal = '🛒 ${_shoppingService.totalCount} Artikel';
        }
        break;
    }

    if (launchBring && action == 'add' && rawItem.isNotEmpty) {
      try {
        final shared =
            await AndroidAppLauncherService.shareToApp(_bringPackage, rawItem);
        if (shared) {
          resultText +=
              ' Bring! App wurde geöffnet und der Artikel wurde geteilt — bitte in der App bestätigen.';
        } else {
          final launched =
              await AndroidAppLauncherService.launchApp(_bringPackage);
          if (launched) {
            resultText +=
                ' Bring! App wurde gestartet (Share nicht verfügbar).';
          } else {
            resultText +=
                ' Bring! App konnte nicht gestartet werden (nicht installiert).';
          }
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
