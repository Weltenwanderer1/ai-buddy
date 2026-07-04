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
    _data.putIfAbsent('app_language', () => 'en');
    _data.putIfAbsent('onboarding_complete', () => false);
    _data.putIfAbsent('max_history', () => 20);
    _data.putIfAbsent('memory_promotion_threshold', () => 3);
    _data.putIfAbsent('memory_ttl_minutes', () => 60);
    _data.putIfAbsent('tts_enabled', () => false);
    _data.putIfAbsent('stt_enabled', () => false);
    _data.putIfAbsent('temperature', () => 0.5);
    _data.putIfAbsent('context_compression', () => true);
    _data.putIfAbsent('auto_memory', () => true);
    _data.putIfAbsent('live_voice_sensitivity', () => 0.5);
    _data.putIfAbsent('tool_calling', () => true);
    _data.putIfAbsent('max_tool_rounds', () => 3);
    _data.putIfAbsent('persona_evolution', () => true);
    _data.putIfAbsent('piper_speed', () => 1.0);
    _data.putIfAbsent('local_model_temperature', () => 0.5);
    _data.putIfAbsent('local_model_max_tokens', () => 512);
    _data.putIfAbsent('theme_mode', () => 'system'); // system | light | dark
    _data.putIfAbsent('accent_color', () => 0xFF6B8DD6); // Hex int for primary accent
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

  /// App UI language (ISO 639-1 code: en, de, es, ja, zh).
  String get appLanguage => _data['app_language'] as String? ?? 'en';
  set appLanguage(String value) {
    _data['app_language'] = value;
    notifyListeners();
    _scheduleSave();
  }

  /// Whether onboarding has been completed.
  bool get onboardingComplete => _data['onboarding_complete'] as bool? ?? false;
  set onboardingComplete(bool value) {
    _data['onboarding_complete'] = value;
    notifyListeners();
    _scheduleSave();
  }

  Map<String, dynamic> exportData() => Map.from(_data);

  ThemeMode get themeMode {
    final raw = _data['theme_mode'] as String? ?? 'system';
    switch (raw) {
      case 'light': return ThemeMode.light;
      case 'dark': return ThemeMode.dark;
      default: return ThemeMode.system;
    }
  }

  set themeMode(ThemeMode mode) {
    _data['theme_mode'] = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    notifyListeners();
    _scheduleSave();
  }

  Color get accentColor {
    return Color(_data['accent_color'] as int? ?? 0xFF6B8DD6);
  }

  set accentColor(Color value) {
    _data['accent_color'] = value.toARGB32();
    notifyListeners();
    _scheduleSave();
  }

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
