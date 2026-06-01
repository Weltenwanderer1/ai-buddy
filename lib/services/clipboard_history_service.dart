import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ClipboardEntry {
  final String text;
  final DateTime timestamp;
  final int length;

  ClipboardEntry({
    required this.text,
    required this.timestamp,
  }) : length = text.length;

  Map<String, dynamic> toJson() => {
    'text': text,
    'timestamp': timestamp.toIso8601String(),
  };

  factory ClipboardEntry.fromJson(Map<String, dynamic> json) => ClipboardEntry(
        text: json['text'] as String? ?? '',
        timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
            DateTime.now(),
      );
}

/// Service that tracks clipboard history by capturing on demand (app start/resume).
class ClipboardHistoryService {
  static const _prefKey = 'clipboard_history_v1';
  static const _maxEntries = 30;

  List<ClipboardEntry> _entries = [];
  String? _lastCaptured;

  Future<void> init() async {
    await _load();
  }

  List<ClipboardEntry> get entries => List.unmodifiable(_entries);

  /// Read current clipboard without storing.
  Future<String?> readCurrent() async {
    try {
      final data = await Clipboard.getData('text/plain');
      return data?.text;
    } catch (e) {
      debugPrint('ClipboardHistory: read error: $e');
      return null;
    }
  }

  /// Capture current clipboard into history if it's new & non-empty.
  Future<bool> capture() async {
    try {
      final text = await readCurrent();
      if (text == null || text.isEmpty) return false;
      if (text == _lastCaptured) return false;
      // Dedup: avoid identical text within last 3 entries
      if (_entries.isNotEmpty &&
          _entries.take(3).any((e) => e.text == text)) {
        return false;
      }
      final entry = ClipboardEntry(text: text, timestamp: DateTime.now());
      _entries.insert(0, entry);
      if (_entries.length > _maxEntries) {
        _entries = _entries.sublist(0, _maxEntries);
      }
      _lastCaptured = text;
      await _save();
      return true;
    } catch (e) {
      debugPrint('ClipboardHistory: capture error: $e');
      return false;
    }
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_prefKey);
      if (data == null) return;
      final List<dynamic> list = jsonDecode(data);
      _entries = list.map((e) => ClipboardEntry.fromJson(e)).toList();
      _lastCaptured = _entries.isNotEmpty ? _entries.first.text : null;
    } catch (e) {
      debugPrint('ClipboardHistory: load error: $e');
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _entries.map((e) => e.toJson()).toList();
      await prefs.setString(_prefKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('ClipboardHistory: save error: $e');
    }
  }

  /// Get recent clipboard entries as formatted text for LLM.
  String getHistoryForLLM({int limit = 10}) {
    if (_entries.isEmpty) return 'Keine Zwischenablage-Historie vorhanden.';
    final buffer = StringBuffer('Letzte Zwischenablage-Eintraege:\n');
    for (var i = 0; i < _entries.length && i < limit; i++) {
      final e = _entries[i];
      final date = '${e.timestamp.day.toString().padLeft(2,'0')}.${e.timestamp.month.toString().padLeft(2,'0')} ${e.timestamp.hour}:${e.timestamp.minute.toString().padLeft(2,'0')}';
      final text = e.text.length > 500 ? '${e.text.substring(0, 500)}...' : e.text;
      buffer.writeln('[${i + 1}] $date: $text');
    }
    return buffer.toString();
  }
}
