import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A lightweight, structured todo list.
///
/// Stored as a JSON array of {id, text, done, created} objects
/// in SharedPreferences. No SQLite overhead for lists <500 items.
/// Loaded on init; writes are immediate + atomic via SharedPreferences.
class TodoService extends ChangeNotifier {
  static const _key = 'todo_items';

  List<TodoItem> _items = [];

  List<TodoItem> get items => List.unmodifiable(_items);
  int get pendingCount => _items.where((t) => !t.done).length;
  bool get isEmpty => _items.isEmpty;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      try {
        _items = (jsonDecode(raw) as List)
            .map((e) => TodoItem.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        _items = [];
      }
    }
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(_items.map((e) => e.toJson()).toList()));
  }

  /// Add a new todo item. Returns its assigned id.
  String add(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return '';
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    _items.add(TodoItem(id: id, text: trimmed));
    _persist();
    notifyListeners();
    return id;
  }

  /// Toggle done/undone by id. Returns the new done state.
  bool toggle(String id) {
    final idx = _items.indexWhere((t) => t.id == id);
    if (idx == -1) return false;
    _items[idx] = _items[idx].copyWith(done: !_items[idx].done);
    _persist();
    notifyListeners();
    return _items[idx].done;
  }

  /// Remove a specific item by id.
  bool remove(String id) {
    final len = _items.length;
    _items.removeWhere((t) => t.id == id);
    if (_items.length == len) return false;
    _persist();
    notifyListeners();
    return true;
  }

  /// Clear all items.
  Future<void> clear() async {
    _items.clear();
    await _persist();
    notifyListeners();
  }

  /// Edit the text of an existing item.
  bool edit(String id, String newText) {
    final trimmed = newText.trim();
    if (trimmed.isEmpty) return false;
    final idx = _items.indexWhere((t) => t.id == id);
    if (idx == -1) return false;
    _items[idx] = _items[idx].copyWith(text: trimmed);
    _persist();
    notifyListeners();
    return true;
  }

  /// Return a plain-text list for AI consumption (token-efficient).
  /// Example output: "1. [x] Milch kaufen\n2. [ ] Zahnarzt termin"
  String toPlainList() {
    if (_items.isEmpty) return 'Keine Todos.';
    return _items.asMap().entries.map((e) {
      final i = e.key + 1;
      final t = e.value;
      final check = t.done ? 'x' : ' ';
      return '$i. [$check] ${t.text}';
    }).join('\n');
  }
}

class TodoItem {
  final String id;
  final String text;
  final bool done;
  final String created;

  const TodoItem({
    required this.id,
    required this.text,
    this.done = false,
    this.created = '',
  });

  TodoItem copyWith({String? text, bool? done}) {
    return TodoItem(
      id: id,
      text: text ?? this.text,
      done: done ?? this.done,
      created: created,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'done': done,
    'created': created,
  };

  factory TodoItem.fromJson(Map<String, dynamic> json) => TodoItem(
    id: json['id'] as String? ?? '',
    text: json['text'] as String? ?? '',
    done: json['done'] as bool? ?? false,
    created: json['created'] as String? ?? '',
  );
}
