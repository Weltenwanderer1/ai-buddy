import 'dart:async';
import 'package:flutter/material.dart';
import 'stt_service.dart';
import 'tts_playback_service.dart';
import 'chat_history_service.dart';
import 'chat_service.dart';
import 'memory_service.dart';
import 'persona_service.dart';
import '../models/chat_message.dart';

/// States for the Live Voice conversation loop.
enum LiveVoiceState {
  idle,
  listening,
  thinking,
  speaking,
  error,
}

/// Orchestrates the continuous listen → think → speak loop.
class LiveVoiceService extends ChangeNotifier {
  final SttService _stt;
  final TtsPlaybackService _tts;
  final ChatService _chatService;
  final ChatHistoryService _chatHistory;
  final MemoryService _memory;
  final PersonaService _persona;

  LiveVoiceState _state = LiveVoiceState.idle;
  String? _lastTranscript;
  String? _lastReply;
  String? _errorMessage;
  bool _active = false;
  int _loopIteration = 0;
  int _consecutiveEmpty = 0;
  static const int _maxConsecutiveEmpty = 10;

  LiveVoiceState get state => _state;
  String? get lastTranscript => _lastTranscript;
  String? get lastReply => _lastReply;
  String? get errorMessage => _errorMessage;
  bool get isActive => _active;
  String? get sttError => _stt.lastError;

  /// STT-Locale (z.B. de_DE, en_US) — folgt der App-Sprache.
  final String sttLocale;

  LiveVoiceService({
    required SttService stt,
    required TtsPlaybackService tts,
    required ChatService chatService,
    required ChatHistoryService chatHistory,
    required MemoryService memory,
    required PersonaService persona,
    this.sttLocale = 'en_US',
  })  : _stt = stt,
        _tts = tts,
        _chatService = chatService,
        _chatHistory = chatHistory,
        _memory = memory,
        _persona = persona;

  /// Start the live voice loop.
  Future<void> start() async {
    if (_active) return;
    _active = true;
    _loopIteration = 0;
    _consecutiveEmpty = 0;

    debugPrint('LiveVoice: start() called');

    // Ensure STT is initialized
    if (!_stt.isAvailable) {
      debugPrint('LiveVoice: initializing STT...');
      final ok = await _stt.init();
      if (!ok) {
        debugPrint('LiveVoice: STT init failed');
        // _active zurücksetzen — sonst zeigt die UI den Live-Modus als
        // aktiv, obwohl gar keine Schleife läuft.
        _active = false;
        _setError('Spracherkennung nicht verfügbar. Mikrofon-Berechtigung erteilt?');
        return;
      }
      debugPrint('LiveVoice: STT initialized successfully');
    }

    _clearError();
    _loop();
  }

  /// Stop the live voice loop and cancel any ongoing activity.
  Future<void> stop() async {
    debugPrint('LiveVoice: stop() called');
    _active = false;
    await _stt.stop();
    await _tts.stop();
    _setState(LiveVoiceState.idle);
  }

  /// Main conversation loop. Runs as long as _active is true.
  Future<void> _loop() async {
    debugPrint('LiveVoice: entering main loop');
    while (_active) {
      _loopIteration++;
      final iteration = _loopIteration;

      // 1. Listen
      _setState(LiveVoiceState.listening);
      _lastTranscript = null;
      notifyListeners();
      debugPrint('LiveVoice [$iteration]: listening...');

      final transcript = await _stt.listenonce(localeId: sttLocale);

      if (!_active) break;

      debugPrint('LiveVoice [$iteration]: transcript = "${transcript ?? '<null>'}"');

      if (transcript == null || transcript.trim().isEmpty) {
        _consecutiveEmpty++;
        final sttErr = _stt.lastError;
        if (sttErr != null && _active) {
          debugPrint('LiveVoice [$iteration]: STT error: $sttErr');
        }
        if (_consecutiveEmpty >= _maxConsecutiveEmpty) {
          debugPrint('LiveVoice: $_maxConsecutiveEmpty consecutive empty recognitions, pausing 2s');
          await Future.delayed(const Duration(seconds: 2));
          _consecutiveEmpty = 0;
        }
        continue;
      }

      _consecutiveEmpty = 0;
      _lastTranscript = transcript;
      notifyListeners();

      // 2. Think + 3. Speak — STREAMED sentence-by-sentence. As soon as the
      // first sentence is generated it starts speaking while the rest of the
      // reply is still being produced, so the user hears a response within a
      // second or two instead of waiting for the whole answer + full synthesis.
      _setState(LiveVoiceState.thinking);
      debugPrint('LiveVoice [$iteration]: thinking (streaming)...');

      try {
        final userMsg = ChatMessage(text: transcript, isUser: true, type: MessageType.voice);
        await _chatHistory.add(userMsg);

        final full = StringBuffer();     // complete reply (for history)
        final pending = StringBuffer();  // text not yet handed to TTS
        Future<void> speakChain = Future.value();
        bool startedSpeaking = false;
        bool ttsFailed = false;

        void enqueue(String sentence) {
          final s = sentence.trim();
          if (s.isEmpty) return;
          // Chain sentences so they play in order, one after another, while
          // later ones are still streaming in.
          speakChain = speakChain.then((_) async {
            if (!_active || ttsFailed) return;
            if (!startedSpeaking) {
              startedSpeaking = true;
              _setState(LiveVoiceState.speaking);
            }
            final ok = await _tts.speak(s);
            if (!ok) ttsFailed = true;
          });
        }

        final stream = _chatService.streamResponse(
          userMessage: transcript,
          persona: _persona,
          memory: _memory,
          history: _chatHistory.messages,
        );

        await for (final chunk in stream) {
          if (!_active) break;
          if (chunk == '🔧') continue; // tool-execution marker, not speech
          full.write(chunk);
          pending.write(chunk);
          // Flush every complete sentence as soon as it is available.
          for (var idx = _firstSentenceEnd(pending.toString());
              idx > 0;
              idx = _firstSentenceEnd(pending.toString())) {
            final text = pending.toString();
            enqueue(text.substring(0, idx));
            final rest = text.substring(idx);
            pending.clear();
            pending.write(rest);
          }
        }

        if (!_active) break;

        // Speak any trailing text that had no sentence terminator.
        if (pending.toString().trim().isNotEmpty) enqueue(pending.toString());
        // Wait until everything queued has finished playing.
        await speakChain;

        if (!_active) break;

        final replyText = full.toString().trim();
        debugPrint('LiveVoice [$iteration]: reply = "${replyText.length > 80 ? '${replyText.substring(0, 80)}…' : replyText}"');
        if (replyText.isNotEmpty) {
          await _chatHistory.add(ChatMessage(text: replyText, isUser: false));
          _lastReply = replyText;
          notifyListeners();
        }

        if (ttsFailed) {
          final ttsError = _tts.lastError ?? 'TTS nicht konfiguriert';
          debugPrint('LiveVoice [$iteration]: TTS failed: $ttsError');
          _setError('Sprachausgabe fehlgeschlagen: $ttsError');
          await Future.delayed(const Duration(seconds: 3));
          _clearError();
          _setState(LiveVoiceState.idle);
        }

        // Short echo-avoidance gap before listening again.
        await Future.delayed(const Duration(milliseconds: 400));
      } catch (e) {
        if (!_active) break;
        debugPrint('LiveVoice [$iteration]: error: $e');
        _setError('Fehler: ${_safeError(e)}');
        await Future.delayed(const Duration(seconds: 2));
        _clearError();
        if (_active) continue;
      }
    }

    debugPrint('LiveVoice: loop ended');
    if (_state != LiveVoiceState.idle) {
      _setState(LiveVoiceState.idle);
    }
  }

  void _setState(LiveVoiceState s) {
    _state = s;
    notifyListeners();
  }

  void _setError(String msg) {
    _errorMessage = msg;
    _setState(LiveVoiceState.error);
  }

  void _clearError() {
    _errorMessage = null;
  }

  String _safeError(dynamic e) {
    final s = e.toString();
    return s.length > 120 ? '${s.substring(0, 120)}…' : s;
  }

  /// Index just past the first sentence terminator in [text], or -1 if none.
  /// Requires a small minimum length so abbreviations and tiny fragments don't
  /// trigger choppy one-word synthesis. TTS sanitizing happens in the TTS
  /// service, so raw text (with markdown) is fine here.
  int _firstSentenceEnd(String text) {
    for (final m in RegExp(r'[.!?…\n]').allMatches(text)) {
      if (m.end >= 15) return m.end;
    }
    return -1;
  }
}
