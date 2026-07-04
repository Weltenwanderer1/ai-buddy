import 'dart:async';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Speech-to-Text service using the speech_to_text package.
class SttService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;
  String? _lastError;

  // Aktive listenonce-Session: erlaubt onError/onStatus (registriert in
  // init) und stop(), den wartenden Aufrufer sofort zu entblocken —
  // vorher hing listenonce bei Fehlern bis zum 120s-Timeout.
  Completer<String?>? _activeCompleter;
  String _accumulated = '';

  bool get isAvailable => _isInitialized;
  bool get isListening => _isListening;
  String? get lastError => _lastError;

  void _finishActive(String? value) {
    final c = _activeCompleter;
    _activeCompleter = null;
    _isListening = false;
    if (c != null && !c.isCompleted) c.complete(value);
  }

  /// Initialize the speech recognizer.
  Future<bool> init() async {
    _lastError = null;
    _isInitialized = await _speech.initialize(
      onError: (error) {
        debugPrint('STT onError: ${error.errorMsg} (permanent: ${error.permanent})');
        _isListening = false;
        _lastError = error.errorMsg;
        // error_no_match / error_speech_timeout etc. beenden die Erkennung —
        // den Aufrufer nicht bis zum Timeout hängen lassen.
        _finishActive(_accumulated.isNotEmpty ? _accumulated : null);
      },
      onStatus: (status) {
        debugPrint('STT onStatus: $status');
        if (status == 'notListening' || status == 'done') {
          _isListening = false;
          // Das finale onResult kann kurz NACH 'done' eintreffen — kleine
          // Gnadenfrist, dann mit dem bisherigen Text abschließen.
          Future.delayed(const Duration(milliseconds: 600), () {
            _finishActive(_accumulated.isNotEmpty ? _accumulated : null);
          });
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
      await stop();
    }

    _lastError = null;
    final completer = Completer<String?>();
    _activeCompleter = completer;
    _accumulated = '';
    _isListening = true;

    try {
      await _speech.listen(
        onResult: (result) {
          debugPrint('STT result: "${result.recognizedWords}" final=${result.finalResult}');
          _accumulated = result.recognizedWords;
          if (result.finalResult) {
            _finishActive(result.recognizedWords);
          }
        },
        onSoundLevelChange: (level) {
          // Sound level feedback for debugging (only logs occasionally)
        },
        localeId: localeId,
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.dictation,
          cancelOnError: false,
          partialResults: true,
        ),
      );
    } catch (e) {
      // ListenFailedException (Mikro belegt, Berechtigung entzogen, ...)
      debugPrint('STT listen failed: $e');
      _lastError = '$e';
      _finishActive(null);
    }

    // Timeout after 120 seconds for dictation — return accumulated text or null
    return completer.future.timeout(
      const Duration(seconds: 120),
      onTimeout: () {
        debugPrint('STT listenonce: 120s timeout reached, returning accumulated: "$_accumulated"');
        _speech.stop();
        _activeCompleter = null;
        _isListening = false;
        return _accumulated.isNotEmpty ? _accumulated : null;
      },
    );
  }

  /// Stop listening.
  Future<void> stop() async {
    await _speech.stop();
    // Wartende listenonce-Futures sofort mit dem bisherigen Text auflösen.
    _finishActive(_accumulated.isNotEmpty ? _accumulated : null);
  }
}
