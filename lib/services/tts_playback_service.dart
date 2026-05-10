import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:just_audio/just_audio.dart';
import 'elevenlabs_service.dart';
import 'device_tts_service.dart';
import 'secure_config_service.dart';

/// TTS engine selection.
enum TtsEngine {
  elevenLabs,
  device,
}

/// TTS playback service — supports ElevenLabs API and Device-native TTS.
class TtsPlaybackService extends ChangeNotifier {
  final ElevenLabsService _elevenLabs;
  final DeviceTtsService _deviceTts = DeviceTtsService();
  final AudioPlayer _player = AudioPlayer();
  String? currentlyPlayingId;
  bool autoPlay = false;

  /// Current TTS engine.
  TtsEngine _engine = TtsEngine.elevenLabs;
  TtsEngine get engine => _engine;

  /// Last error message for debugging.
  String? lastError;

  TtsPlaybackService(this._elevenLabs);

  bool get isPlaying => _player.playing;
  bool get isAvailable {
    if (_engine == TtsEngine.elevenLabs) return _elevenLabs.isAvailable;
    return _deviceTts.isAvailable;
  }

  /// Switch TTS engine.
  set engine(TtsEngine e) {
    if (_engine != e) {
      _engine = e;
      lastError = null;
      notifyListeners();
    }
  }

  /// Get DeviceTtsService (for voice selection in settings).
  DeviceTtsService get deviceTts => _deviceTts;

  /// Initialize device TTS if using device engine.
  Future<void> initDeviceTts() async {
    if (_engine == TtsEngine.device && !_deviceTts.isAvailable) {
      await _deviceTts.init();
    }
  }

  /// Load engine preference from secure config.
  Future<void> loadEnginePreference(SecureConfigService config) async {
    final pref = config.ttsEngine;
    _engine = pref == 'device' ? TtsEngine.device : TtsEngine.elevenLabs;
    if (_engine == TtsEngine.device) {
      await _deviceTts.init();
    }
    notifyListeners();
  }

  /// Synthesize text and play the resulting audio.
  /// Returns true if successful, false if TTS is not available or failed.
  /// ALL text is sanitized before TTS to prevent reading markdown/emoji aloud.
  Future<bool> speak(String text, {String? messageId}) async {
    lastError = null;
    
    final cleanText = _sanitizeForTts(text);
    if (cleanText.isEmpty) return true; // nothing to speak after sanitizing

    if (_engine == TtsEngine.device) {
      return _speakDevice(cleanText, messageId: messageId);
    }
    return _speakElevenLabs(cleanText, messageId: messageId);
  }

  Future<bool> _speakDevice(String text, {String? messageId}) async {
    if (!_deviceTts.isAvailable) {
      final ok = await _deviceTts.init();
      if (!ok) {
        lastError = 'Geräte-TTS nicht verfügbar: ${_deviceTts.lastError}';
        debugPrint('TTS: $lastError');
        return false;
      }
    }
    if (text.trim().isEmpty) {
      lastError = 'Leerer Text — nichts zu sagen';
      return false;
    }

    try {
      currentlyPlayingId = messageId;
      notifyListeners();
      // speak() now blocks until audio finishes (uses Completer)
      final ok = await _deviceTts.speak(text);
      if (!ok) {
        lastError = _deviceTts.lastError ?? 'Geräte-TTS Fehler';
      }
      currentlyPlayingId = null;
      notifyListeners();
      return ok;
    } catch (e) {
      currentlyPlayingId = null;
      lastError = 'Device TTS Fehler: $e';
      debugPrint('TTS: $lastError');
      notifyListeners();
      return false;
    }
  }

  Future<bool> _speakElevenLabs(String text, {String? messageId}) async {
    if (!_elevenLabs.isAvailable) {
      lastError = 'ElevenLabs nicht konfiguriert (API Key oder Voice ID fehlt)';
      debugPrint('TTS: $lastError');
      return false;
    }
    if (text.trim().isEmpty) {
      lastError = 'Leerer Text — nichts zu sagen';
      debugPrint('TTS: $lastError');
      return false;
    }

    try {
      // Cache check
      final cacheDir = await _getCacheDir();
      final cacheFile = File('${cacheDir.path}/${_hashText(text)}.mp3');

      List<int> audioBytes;
      if (await cacheFile.exists()) {
        debugPrint('TTS: using cached audio for "${text.substring(0, text.length > 40 ? 40 : text.length)}…"');
        audioBytes = await cacheFile.readAsBytes();
      } else {
        debugPrint('TTS: synthesizing "${text.substring(0, text.length > 40 ? 40 : text.length)}…"');
        audioBytes = await _elevenLabs.synthesize(text);
        if (audioBytes.isEmpty) {
          lastError = 'ElevenLabs gab leere Audio-Daten zurück';
          debugPrint('TTS: $lastError');
          return false;
        }
        debugPrint('TTS: got ${audioBytes.length} bytes, caching…');
        await cacheFile.writeAsBytes(audioBytes);
      }

      currentlyPlayingId = messageId;
      notifyListeners();
      await _player.setFilePath(cacheFile.path);
      await _player.play();
      await _player.processingStateStream.firstWhere(
        (state) => state == ProcessingState.completed,
      );
      currentlyPlayingId = null;
      notifyListeners();
      return true;
    } catch (e) {
      currentlyPlayingId = null;
      lastError = 'TTS Fehler: $e';
      debugPrint('TTS speak error: $e');
      notifyListeners();
      return false;
    }
  }

  /// Test the ElevenLabs connection. Returns the test result.
  Future<ElevenLabsTestResult> testConnection() => _elevenLabs.testConnection();

  /// Stop current playback.
  Future<void> stop() async {
    if (_engine == TtsEngine.device) {
      await _deviceTts.stop();
    } else {
      await _player.stop();
    }
    currentlyPlayingId = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _player.dispose();
    _deviceTts.dispose();
    super.dispose();
  }

  Future<Directory> _getCacheDir() async {
    final dir = await getTemporaryDirectory();
    final cacheDir = Directory('${dir.path}/ai_buddy/tts_cache');
    if (!await cacheDir.exists()) await cacheDir.create(recursive: true);
    return cacheDir;
  }

  String _hashText(String text) {
    var hash = 0;
    for (var i = 0; i < text.length; i++) {
      hash = ((hash << 5) - hash) + text.codeUnitAt(i);
      hash = hash & 0x7fffffff; // Keep positive
    }
    return hash.toRadixString(36);
  }

  /// Global TTS text sanitizer -- removes formatting that gets read aloud.
  /// Strips: markdown (*, _, ~, `), roleplay (*text*), all emoji, hashtags.
  static String _sanitizeForTts(String text) {
    return text
        .replaceAll(RegExp(r'\*[^*]+\*'), '')   // *roleplay actions*
        .replaceAll(RegExp(r'[*_~`#]'), '')     // markdown chars
        .replaceAll(RegExp(r'[\u{1F600}-\u{1F64F}\u{1F300}-\u{1F5FF}\u{1F680}-\u{1F6FF}\u{1F1E0}-\u{1F1FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]', unicode: true), '') // emoji
        .replaceAll(RegExp(r'  +'), ' ')
        .trim();
  }
}