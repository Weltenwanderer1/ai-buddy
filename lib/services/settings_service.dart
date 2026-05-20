import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';

/// Key-value settings with debounced save and safe JSON loading.
class SettingsService extends ChangeNotifier {
  static const _saveDebounceMs = 500;

  final Map<String, dynamic> _data = {};
  final _saveController = PublishSubject<void>();
  StreamSubscription<void>? _saveSubscription;

  late File _file;

  dynamic operator [](String key) => _data[key];
  void operator []=(String key, dynamic value) {
    _data[key] = value;
    notifyListeners();
    _scheduleSave();
  }

  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    _file = File('${dir.path}/ai_buddy/settings.json');
    _saveSubscription = _saveController
        .debounceTime(const Duration(milliseconds: _saveDebounceMs))
        .listen((_) => _doSave());
    await _load();
    _setDefaults();
    notifyListeners();
  }

  void _setDefaults() {
    _data.putIfAbsent('max_history', () => 20);
    _data.putIfAbsent('memory_promotion_threshold', () => 3);
    _data.putIfAbsent('memory_ttl_minutes', () => 60);
    _data.putIfAbsent('tts_enabled', () => false);
    _data.putIfAbsent('stt_enabled', () => false);
    _data.putIfAbsent('temperature', () => 0.7);
  }

  void _scheduleSave() {
    _saveController.add(null);
  }

  Future<void> _doSave() async {
    await _file.parent.create(recursive: true);
    await _file.writeAsString(const JsonEncoder.withIndent('  ').convert(_data));
  }

  Future<void> _load() async {
    if (!await _file.exists()) return;
    try {
      final raw = await _file.readAsString();
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      _data.addAll(decoded);
    } catch (e) {
      // Corrupted — keep defaults
    }
  }

  Map<String, dynamic> exportData() => Map.from(_data);

  Future<void> importData(Map<String, dynamic> data) async {
    _data.clear();
    _data.addAll(data);
    notifyListeners();
    await _doSave();
  }

  @override
  void dispose() {
    _saveSubscription?.cancel();
    _saveController.close();
    super.dispose();
  }
}
