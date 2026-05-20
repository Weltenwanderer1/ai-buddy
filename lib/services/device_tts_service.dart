import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Device-native TTS service using flutter_tts.
/// Free, offline (after voice download), no API key needed.
class DeviceTtsService {
  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;
  String? _lastError;

  /// Completer that resolves when current speak finishes.
  Completer<void>? _speakCompleter;

  bool get isAvailable => _initialized;
  String? get lastError => _lastError;

  /// Available voices after init.
  List<Map<String, String>> _voices = [];
  List<Map<String, String>> get voices => _voices;

  /// Currently selected voice name.
  String? _currentVoice;
  String? get currentVoice => _currentVoice;

  /// Whether TTS is currently speaking.
  bool get isSpeaking => _speakCompleter != null && !_speakCompleter!.isCompleted;

  /// Initialize TTS and load German voices.
  Future<bool> init({String language = 'de-DE'}) async {
    if (_initialized) return true;

    try {
      // Set up speak completion handler — resolves the completer
      _tts.setCompletionHandler(() {
        debugPrint('DeviceTts: completionHandler fired');
        final c = _speakCompleter;
        if (c != null && !c.isCompleted) {
          c.complete();
        }
      });

      // Set up error handler
      _tts.setErrorHandler((msg) {
        debugPrint('DeviceTts: errorHandler fired: $msg');
        final c = _speakCompleter;
        if (c != null && !c.isCompleted) {
          c.completeError('TTS error: $msg');
        }
      });

      // Set language first
      await _tts.setLanguage(language);

      // Configure
      await _tts.setSpeechRate(0.55); // moderate pace for German
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);

      // Get available voices
      final voicesRaw = await _tts.getVoices;
      if (voicesRaw != null && voicesRaw is List) {
        _voices = voicesRaw.map<Map<String, String>>((v) {
          final m = v as Map;
          final name = (m['name'] ?? '').toString();
          final locale = (m['locale'] ?? '').toString();
          return {'name': name, 'locale': locale};
        }).toList();
        final germanVoices = _voices
            .where((v) => v['locale']!.startsWith('de'))
            .toList();
        debugPrint('DeviceTts: ${voicesRaw.length} total voices, ${germanVoices.length} German');
        for (final v in germanVoices) {
          debugPrint('  German voice: ${v['name']} (${v['locale']})');
        }
      }

      // Try to pick a German voice
      final germanVoices2 = _voices
          .where((v) => v['locale']!.startsWith('de'))
          .toList();
      if (germanVoices2.isNotEmpty) {
        final firstVoice = germanVoices2.first;
        _currentVoice = firstVoice['name'];
        await _tts.setVoice({'name': firstVoice['name']!, 'locale': firstVoice['locale']!});
        debugPrint('DeviceTts: using voice ${firstVoice['name']}');
      }

      _initialized = true;
      _lastError = null;
      return true;
    } catch (e) {
      _lastError = 'DeviceTts init failed: $e';
      debugPrint(_lastError);
      return false;
    }
  }

  /// Speak text and **wait until speaking finishes**.
  /// Returns true if successful. Blocks until audio is done.
  Future<bool> speak(String text) async {
    if (!_initialized) {
      final ok = await init();
      if (!ok) return false;
    }
    if (text.trim().isEmpty) return false;

    try {
      // Stop any ongoing speech
      await stop();
      await Future.delayed(const Duration(milliseconds: 50));

      // Create completer for this utterance
      _speakCompleter = Completer<void>();

      debugPrint('DeviceTts: speak("$text")');
      final result = await _tts.speak(text);

      if (result != 1) {
        debugPrint('DeviceTts: speak() returned $result (not 1)');
        _speakCompleter = null;
        return false;
      }

      // Wait for completion handler to fire
      await _speakCompleter!.future;
      _speakCompleter = null;
      debugPrint('DeviceTts: speak completed');
      return true;
    } catch (e) {
      _lastError = 'DeviceTts speak error: $e';
      debugPrint(_lastError);
      _speakCompleter = null;
      return false;
    }
  }

  /// Stop speaking.
  Future<void> stop() async {
    await _tts.stop();
    // Resolve any pending completer so callers don't hang
    final c = _speakCompleter;
    if (c != null && !c.isCompleted) {
      c.complete();
    }
    _speakCompleter = null;
  }

  /// Set voice by name.
  Future<bool> setVoice(String voiceName, String locale) async {
    try {
      await _tts.setVoice({'name': voiceName, 'locale': locale});
      _currentVoice = voiceName;
      return true;
    } catch (e) {
      debugPrint('DeviceTts: failed to set voice $voiceName: $e');
      return false;
    }
  }

  /// Set speech rate (0.0 - 1.0).
  Future<void> setSpeechRate(double rate) async {
    await _tts.setSpeechRate(rate);
  }

  void dispose() {
    _tts.stop();
  }
}
