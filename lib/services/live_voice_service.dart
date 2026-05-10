import 'dart:async';
import 'package:flutter/material.dart';
import 'stt_service.dart';
import 'tts_playback_service.dart';
import 'ollama_cloud_service.dart';
import 'chat_history_service.dart';
import 'chat_service.dart';
import 'memory_service.dart';
import 'persona_service.dart';
import '../models/chat_message.dart';
import '../tools/tool_registry.dart';

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
  final OllamaCloudService _llm;
  final ChatHistoryService _chatHistory;
  final MemoryService _memory;
  final PersonaService _persona;
  final ToolRegistry? _toolRegistry;

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

  LiveVoiceService({
    required SttService stt,
    required TtsPlaybackService tts,
    required OllamaCloudService llm,
    required ChatHistoryService chatHistory,
    required MemoryService memory,
    required PersonaService persona,
    ToolRegistry? toolRegistry,
  })  : _stt = stt,
        _tts = tts,
        _llm = llm,
        _chatHistory = chatHistory,
        _memory = memory,
        _persona = persona,
        _toolRegistry = toolRegistry;

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
      notifyListeners(); // Force UI update so "Ich höre zu…" appears immediately
      debugPrint('LiveVoice [$iteration]: listening...');

      final transcript = await _stt.listenonce();

      if (!_active) break; // stopped while listening

      debugPrint('LiveVoice [$iteration]: transcript = "${transcript ?? '<null>'}"');

      if (transcript == null || transcript.trim().isEmpty) {
        // Nothing recognized — check if there was an STT error
        _consecutiveEmpty++;
        final sttErr = _stt.lastError;
        if (sttErr != null && _active) {
          debugPrint('LiveVoice [$iteration]: STT error: $sttErr');
        }
        // If too many consecutive empty recognitions, pause to avoid spin
        if (_consecutiveEmpty >= _maxConsecutiveEmpty) {
          debugPrint('LiveVoice: $_maxConsecutiveEmpty consecutive empty recognitions, pausing 2s');
          await Future.delayed(const Duration(seconds: 2));
          _consecutiveEmpty = 0;
        }
        // Retry listen
        continue;
      }

      // Successful recognition resets counter
      _consecutiveEmpty = 0;

      _lastTranscript = transcript;
      notifyListeners(); // Show transcript in UI immediately

      // 2. Think (send to LLM)
      _setState(LiveVoiceState.thinking);
      debugPrint('LiveVoice [$iteration]: thinking...');

      try {
        // Save user message
        final userMsg = ChatMessage(text: transcript, isUser: true, type: MessageType.voice);
        await _chatHistory.add(userMsg);

        // Call LLM via ChatService (with tools!)
        final chatService = ChatService(_llm, toolRegistry: _toolRegistry);
        final reply = await chatService.sendMessage(
          userMessage: transcript,
          persona: _persona,
          memory: _memory,
          history: _chatHistory.messages,
        );

        if (!_active) break; // stopped while thinking

        debugPrint('LiveVoice [$iteration]: reply = "${reply.length > 80 ? '${reply.substring(0, 80)}…' : reply}"');

        // Save assistant message
        final assistantMsg = ChatMessage(text: reply, isUser: false);
        await _chatHistory.add(assistantMsg);

        _lastReply = reply;
        notifyListeners(); // Show reply in UI immediately

        // 3. Speak (sanitize text for TTS first)
        _setState(LiveVoiceState.speaking);
        debugPrint('LiveVoice [$iteration]: speaking...');
        final sanitizedReply = _sanitizeForTts(reply);
        debugPrint('LiveVoice [$iteration]: sanitized = "${sanitizedReply.length > 80 ? '${sanitizedReply.substring(0, 80)}...' : sanitizedReply}"');
        final spoken = await _tts.speak(sanitizedReply);

        if (!_active) break; // stopped while speaking

        if (!spoken) {
          final ttsError = _tts.lastError ?? 'TTS nicht konfiguriert';
          debugPrint('LiveVoice [$iteration]: TTS failed: $ttsError');
          _setError('Sprachausgabe fehlgeschlagen: $ttsError');
          await Future.delayed(const Duration(seconds: 3));
          _clearError();
          _setState(LiveVoiceState.idle);
        }

        // Echo avoidance: wait after speaking before listening again
        // Device TTS has no built-in echo cancellation like ElevenLabs + just_audio
        debugPrint('LiveVoice [$iteration]: waiting 1s after speaking (echo avoidance)');
        await Future.delayed(const Duration(seconds: 1));
      } catch (e) {
        if (!_active) break;
        debugPrint('LiveVoice [$iteration]: error: $e');
        _setError('Fehler: ${_safeError(e)}');
        // Pause before retrying to avoid rapid error spin
        await Future.delayed(const Duration(seconds: 2));
        _clearError();
        // After error, continue loop if still active
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

  /// Strip formatting characters that TTS engines read aloud literally.
  /// Removes: markdown (*, _, ~, `), roleplay actions (*text*), emoji
  String _sanitizeForTts(String text) {
    var cleaned = text
        // Strip roleplay actions like *lacht* or *denkt nach*
        .replaceAll(RegExp(r'\*[^*]+\*'), '')
        // Remove remaining asterisks (bold/italic markdown)
        .replaceAll('*', '')
        // Remove underscores (italic markdown)
        .replaceAll('_', '')
        // Remove strikethrough
        .replaceAll('~~', '')
        // Remove backticks
        .replaceAll('`', '')
        // Remove common emoji that get read as "lachender Smiley" etc.
        .replaceAll(RegExp(r'[\u{1F600}-\u{1F64F}\u{1F300}-\u{1F5FF}\u{1F680}-\u{1F6FF}\u{1F1E0}-\u{1F1FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]', unicode: true), '')
        // Remove multiple spaces created by removals
        .replaceAll(RegExp(r'  +'), ' ')
        .trim();

    return cleaned;
  }
}