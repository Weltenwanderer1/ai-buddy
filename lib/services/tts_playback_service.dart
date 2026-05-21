import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:just_audio/just_audio.dart';
import 'piper_tts_service.dart';
import 'device_tts_service.dart';
import 'secure_config_service.dart';

/// TTS engine selection.
enum TtsEngine {
  piper,
  device;
  
  String get label {
    switch (this) {
      case TtsEngine.piper: return 'Piper (Offline)';
      case TtsEngine.device: return 'Gerät';
    }
  }
}

/// TTS playback service — supports Piper (offline neural TTS) and Device-native TTS.
/// Piper is the primary engine, Device TTS is the fallback.
class TtsPlaybackService extends ChangeNotifier {
  final PiperTtsService _piper;
  final DeviceTtsService _deviceTts = DeviceTtsService();
  final AudioPlayer _player = AudioPlayer();
  String? currentlyPlayingId;
  bool autoPlay = false;
  Completer<void>? _playbackCompleter;

  /// Current TTS engine.
  TtsEngine _engine = TtsEngine.piper;
  TtsEngine get engine => _engine;

  /// Last error message for debugging.
  String? lastError;

  TtsPlaybackService(this._piper);

  bool get isPlaying => _player.playing;
  bool get isAvailable {
    switch (_engine) {
      case TtsEngine.piper: return _piper.isLoaded;
      case TtsEngine.device: return _deviceTts.isAvailable;
    }
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

  /// Get PiperTtsService (for voice download/management in settings).
  PiperTtsService get piper => _piper;

  /// Initialize device TTS if using device engine.
  Future<void> initDeviceTts() async {
    if (_engine == TtsEngine.device && !_deviceTts.isAvailable) {
      await _deviceTts.init();
    }
  }

  /// Load engine preference from secure config.
  Future<void> loadEnginePreference(SecureConfigService config) async {
    final pref = config.ttsEngine;
    _engine = switch (pref) {
      'device' => TtsEngine.device,
      'piper' => TtsEngine.piper,
      _ => TtsEngine.piper,
    };

    // Try to auto-load Piper voice if configured
    if (_engine == TtsEngine.piper) {
      final voiceId = config.piperVoice;
      final voice = PiperVoice.fromId(voiceId);
      if (voice != null && await _piper.isVoiceDownloaded(voice)) {
        await _piper.loadVoice(voice);
        if (!_piper.isLoaded) {
          debugPrint('TTS: Piper voice $voiceId failed to load, falling back to device');
          _engine = TtsEngine.device;
          await _deviceTts.init();
        }
      } else {
        debugPrint('TTS: Piper voice not downloaded, falling back to device TTS');
        _engine = TtsEngine.device;
        await _deviceTts.init();
      }
    } else if (_engine == TtsEngine.device) {
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

    switch (_engine) {
      case TtsEngine.device:
        return _speakDevice(cleanText, messageId: messageId);
      case TtsEngine.piper:
        final ok = await _speakPiper(cleanText, messageId: messageId);
        if (!ok) {
          debugPrint('TTS: Piper failed ($lastError). Falling back to device TTS.');
          return _speakDevice(cleanText, messageId: messageId);
        }
        return true;
    }
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

  Future<bool> _speakPiper(String text, {String? messageId}) async {
    if (!_piper.isLoaded) {
      lastError = 'Piper TTS nicht geladen — Stimme heruntergeladen?';
      debugPrint('TTS: $lastError');
      return false;
    }
    if (text.trim().isEmpty) {
      lastError = 'Leerer Text — nichts zu sagen';
      return false;
    }

    try {
      // Cache check
      final cacheDir = await _getCacheDir();
      final cacheFile = File('${cacheDir.path}/${_hashText(text)}.wav');

      String audioPath;
      if (await cacheFile.exists()) {
        debugPrint('TTS: using cached Piper audio for "${text.substring(0, text.length > 40 ? 40 : text.length)}…"');
        audioPath = cacheFile.path;
      } else {
        debugPrint('TTS: Piper synthesizing "${text.substring(0, text.length > 40 ? 40 : text.length)}…"');
        final synthesized = await _piper.synthesize(text);
        if (synthesized == null) {
          lastError = _piper.lastError ?? 'Piper Synthese fehlgeschlagen';
          debugPrint('TTS: $lastError');
          return false;
        }
        // Piper writes to its own temp file — copy to cache
        final srcFile = File(synthesized);
        await srcFile.copy(cacheFile.path);
        audioPath = cacheFile.path;
      }

      currentlyPlayingId = messageId;
      notifyListeners();

      await _player.setFilePath(audioPath);

      final completer = Completer<void>();
      _playbackCompleter = completer;

      final subscription = _player.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          if (!completer.isCompleted) completer.complete();
        }
      }, onError: (e) {
        if (!completer.isCompleted) completer.completeError(e);
      });

      try {
        await _player.play();
        await completer.future;
      } finally {
        await subscription.cancel();
        _playbackCompleter = null;
        currentlyPlayingId = null;
        notifyListeners();
      }

      return true;
    } catch (e) {
      currentlyPlayingId = null;
      lastError = 'Piper TTS Fehler: $e';
      debugPrint('TTS Piper speak error: $e');
      notifyListeners();
      return false;
    }
  }

  /// Stop current playback.
  Future<void> stop() async {
    if (_engine == TtsEngine.device) {
      await _deviceTts.stop();
    } else {
      await _player.stop();
      if (_playbackCompleter != null && !_playbackCompleter!.isCompleted) {
        _playbackCompleter!.complete();
      }
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