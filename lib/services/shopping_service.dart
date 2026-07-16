import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A categorized shopping list item.
class ShoppingItem {
  final String name;
  final String category;
  final bool checked;

  const ShoppingItem({
    required this.name,
    required this.category,
    this.checked = false,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'category': category,
        'checked': checked,
      };

  factory ShoppingItem.fromJson(Map<String, dynamic> json) => ShoppingItem(
        name: json['name'] as String? ?? '',
        category: json['category'] as String? ?? 'Sonstiges',
        checked: json['checked'] as bool? ?? false,
      );
}

/// Service for a categorized shopping list with receipt scanning support.
class ShoppingService extends ChangeNotifier {
  static const String _storageKey = 'shopping_list_v2';
  List<ShoppingItem> _items = [];

  static const List<String> categories = [
    'Obst & Gemüse',
    'Molkerei & Eier',
    'Brot & Getreide',
    'Fleisch & Fisch',
    'Getränke',
    'Tiefkühl',
    'Haushalt',
    'Körperpflege',
    'Baby & Kind',
    'Tierbedarf',
    'Sonstiges',
  ];

  List<ShoppingItem> get items => List.unmodifiable(_items);

  int get totalCount => _items.length;
  int get checkedCount => _items.where((i) => i.checked).length;

  /// Guess a category based on item name (simple keyword mapping).
  static String guessCategory(String name) {
    final n = name.toLowerCase();
    if (n.contains('apfel') || n.contains('banane') || n.contains('birne') ||
        n.contains('orange') || n.contains('traube') || n.contains('erdbee') ||
        n.contains('salat') || n.contains('tomate') || n.contains('gurke') ||
        n.contains('karotte') || n.contains('zwiebel') || n.contains('knoblauch') ||
        n.contains('paprika') || n.contains('brokkoli') || n.contains('spinat') ||
        n.contains('obst') || n.contains('gemüse') || n.contains('kartoffel'))
      return 'Obst & Gemüse';

    if (n.contains('milch') || n.contains('joghurt') || n.contains('käse') ||
        n.contains('butter') || n.contains('sahne') || n.contains('quark') ||
        n.contains('ei') || n.contains('eier'))
      return 'Molkerei & Eier';

    if (n.contains('brot') || n.contains('brötchen') || n.contains('toast') ||
        n.contains('mehl') || n.contains('nudel') || n.contains('reis') ||
        n.contains('müsli') || n.contains('haferflocken') || n.contains('cornflakes'))
      return 'Brot & Getreide';

    if (n.contains('fleisch') || n.contains('hack') || n.contains('hähnchen') ||
        n.contains('huhn') || n.contains('rind') || n.contains('schwein') ||
        n.contains('wurst') || n.contains('salami') || n.contains('schinken') ||
        n.contains('fisch') || n.contains('lachs'))
      return 'Fleisch & Fisch';

    if (n.contains('wasser') || n.contains('saft') || n.contains('cola') ||
        n.contains('limo') || n.contains('bier') || n.contains('wein') ||
        n.contains('sprite') || n.contains('fanta') || n.contains('schorle'))
      return 'Getränke';

    if (n.contains('eis') || n.contains('tiefkühl') || n.contains('pizza') ||
        n.contains('pommes'))
      return 'Tiefkühl';

    if (n.contains('klopapier') || n.contains('putz') || n.contains('müll') ||
        n.contains('müllsack') || n.contains('spüli') || n.contains('wasch') ||
        n.contains('reiniger') || n.contains('seife') || n.contains('schwamm'))
      return 'Haushalt';

    if (n.contains('shampoo') || n.contains('dusch') || n.contains('zahn') ||
        n.contains('deo') || n.contains('creme') || n.contains('rasier'))
      return 'Körperpflege';

    if (n.contains('windel') || n.contains('baby') || n.contains('brei') ||
        n.contains('schnuller'))
      return 'Baby & Kind';

    if (n.contains('hund') || n.contains('katze') || n.contains('futter') ||
        n.contains('streu') || n.contains('tier'))
      return 'Tierbedarf';

    return 'Sonstiges';
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        _items = list.map((e) => ShoppingItem.fromJson(e as Map<String, dynamic>)).toList();
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(_items.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKey, raw);
  }

  Future<void> addItem(String name, {String? category}) async {
    final cleaned = name.trim();
    if (cleaned.isEmpty) return;
    final cat = category ?? guessCategory(cleaned);
    if (_items.any((i) => i.name.toLowerCase() == cleaned.toLowerCase() && !i.checked)) {
      // Already on list, don't duplicate
      return;
    }
    _items.add(ShoppingItem(name: cleaned, category: cat));
    await _save();
    notifyListeners();
  }

  /// Add multiple items at once (from receipt scan, batch input).
  Future<void> addItems(List<String> names) async {
    for (final name in names) {
      await addItem(name);
    }
  }

  Future<void> toggleItem(int index) async {
    if (index < 0 || index >= _items.length) return;
    final old = _items[index];
    _items[index] = ShoppingItem(
      name: old.name,
      category: old.category,
      checked: !old.checked,
    );
    await _save();
    notifyListeners();
  }

  Future<void> removeItem(int index) async {
    if (index < 0 || index >= _items.length) return;
    _items.removeAt(index);
    await _save();
    notifyListeners();
  }

  Future<void> clearChecked() async {
    _items.removeWhere((i) => i.checked);
    await _save();
    notifyListeners();
  }

  Future<void> clearAll() async {
    _items.clear();
    await _save();
    notifyListeners();
  }

  /// Get items grouped by category.
  Map<String, List<ShoppingItem>> get groupedItems {
    final map = <String, List<ShoppingItem>>{};
    for (final cat in categories) {
      final catItems = _items.where((i) => i.category == cat).toList();
      if (catItems.isNotEmpty) map[cat] = catItems;
    }
    // Unmatched categories
    final other = _items.where((i) => !categories.contains(i.category)).toList();
    if (other.isNotEmpty) map['Sonstiges'] = [
      ...(map['Sonstiges'] ?? []),
      ...other,
    ];
    return map;
  }
}
