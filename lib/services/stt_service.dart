import 'dart:async';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Speech-to-Text service using the speech_to_text package.
class SttService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;
  String? _lastError;

  bool get isAvailable => _isInitialized;
  bool get isListening => _isListening;
  String? get lastError => _lastError;

  /// Initialize the speech recognizer.
  Future<bool> init() async {
    _lastError = null;
    _isInitialized = await _speech.initialize(
      onError: (error) {
        debugPrint('STT onError: ${error.errorMsg} (permanent: ${error.permanent})');
        _isListening = false;
        _lastError = error.errorMsg;
      },
      onStatus: (status) {
        debugPrint('STT onStatus: $status');
        if (status == 'notListening' || status == 'done') {
          _isListening = false;
        }
      },
    );
    debugPrint('STT initialized: $_isInitialized, hasPermission: ${_speech.hasPermission}');
    return _isInitialized;
  }

  /// Start listening once and return the recognized text.
  /// Returns null on timeout or error.
  Future<String?> listenonce({String localeId = 'de_DE'}) async {
    if (!_isInitialized) {
      debugPrint('STT listenonce: not initialized');
      return null;
    }
    if (_isListening) {
      debugPrint('STT listenonce: already listening, stopping first');
      await _speech.stop();
      _isListening = false;
    }

    _lastError = null;
    final completer = Completer<String?>();
    _isListening = true;

    bool completed = false;

    _speech.listen(
      onResult: (result) {
        debugPrint('STT result: "${result.recognizedWords}" final=${result.finalResult}');
        if (result.finalResult && !completed) {
          completed = true;
          _isListening = false;
          completer.complete(result.recognizedWords);
        }
      },
      onSoundLevelChange: (level) {
        // Sound level feedback for debugging (only logs occasionally)
      },
      localeId: localeId,
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.confirmation,
        cancelOnError: true,
      ),
    );

    // Timeout after 30 seconds — return whatever partial result or null
    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        debugPrint('STT listenonce: 30s timeout reached');
        _speech.stop();
        _isListening = false;
        if (!completed) {
          completed = true;
          return null;
        }
        return null;
      },
    );
  }

  /// Stop listening.
  Future<void> stop() async {
    await _speech.stop();
    _isListening = false;
  }
}
