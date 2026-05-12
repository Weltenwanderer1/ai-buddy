import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../widgets/message_bubble.dart';
import '../widgets/message_input.dart';
import '../services/chat_service.dart';
import '../services/chat_history_service.dart';
import '../services/memory_service.dart';
import '../services/persona_service.dart';
import '../services/ollama_cloud_service.dart';
import '../services/persona_evolution_service.dart';
import '../services/live_voice_service.dart';
import '../services/stt_service.dart';
import '../services/tts_playback_service.dart';
import '../services/secure_config_service.dart';

import '../tools/tool_registry.dart';
import '../models/chat_message.dart';
import 'settings_screen.dart';

import '../widgets/proactive_card.dart';
import '../services/proactive_engine.dart';
import '../services/self_identity_service.dart';
import '../core/theme/app_colors.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();
  bool _isStreaming = false;
  bool _isThinking = false;
  bool _isSending = false;
  String _streamingText = '';
  LiveVoiceService? _liveVoice;
  ToolRegistry? _toolRegistry;
  ProactiveEngine? _proactive;
  ProactiveSuggestion? _proactiveSuggestion;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initToolRegistry();
    _loadWelcome();
    _initProactiveEngine();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _liveVoice?.removeListener(_onLiveVoiceUpdate);
    _liveVoice?.stop();
    _proactive?.stop();
    super.dispose();
  }

  void _initProactiveEngine() {
    try {
      final ollamaService = context.read<OllamaCloudService>();
      final memory = context.read<MemoryService>();
      final persona = context.read<PersonaService>();
      _proactive = ProactiveEngine(
        llm: ollamaService,
        memory: memory,
        persona: persona,
        onSuggestion: (s) {
          if (mounted) {
            setState(() => _proactiveSuggestion = s);
          }
        },
      );
      _proactive!.init().then((_) {
        if (mounted) _proactive!.start();
      });
    } catch (e) {
      debugPrint('ProactiveEngine init failed: $e');
    }
  }

  void _initToolRegistry() {
    try {
      final secureConfig = context.read<SecureConfigService>();
      final memory = context.read<MemoryService>();
      final tavilyKey = secureConfig.tavilyApiKey;
      _toolRegistry = ToolRegistry.createDefault(tavilyApiKey: tavilyKey.isNotEmpty ? tavilyKey : null);
      _toolRegistry!.registerSearchMemories(memory);
    } catch (e) {
      _toolRegistry = ToolRegistry.createDefault();
    }
  }

  Future<void> _loadWelcome() async {
    // Chat startet leer — keine automatische Begrüßung.
    // User kann direkt schreiben.
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _isSending) return;
    setState(() => _isSending = true);

    final memory = context.read<MemoryService>();
    final chatHistory = context.read<ChatHistoryService>();
    final ollamaService = context.read<OllamaCloudService>();
    final personaEvolution = context.read<PersonaEvolutionService>();
    final selfIdentity = context.read<SelfIdentityService>();
    final persona = context.read<PersonaService>();

    setState(() => _isThinking = true);

    final userMsg = ChatMessage(text: text, isUser: true);
    await chatHistory.add(userMsg);
    HapticFeedback.selectionClick();
    _scrollToBottom();

    try {
      final chatService = ChatService(ollamaService, toolRegistry: _toolRegistry, selfIdentity: selfIdentity);
      await _sendMessageStream(chatService, text, persona, memory, chatHistory, personaEvolution);
    } catch (e) {
      debugPrint('Streaming failed: $e');
      try {
        final chatService = ChatService(ollamaService, toolRegistry: _toolRegistry, selfIdentity: selfIdentity);
        final reply = await chatService.sendMessage(
          userMessage: text,
          persona: persona,
          memory: memory,
          history: chatHistory.messages,
          personaEvolution: personaEvolution,
        );
        final assistantMsg = ChatMessage(text: reply, isUser: false);
        await chatHistory.add(assistantMsg);
        _scrollToBottom();
      } catch (e2) {
        debugPrint('Non-streaming fallback also failed: $e2');
        final errorMsg = e2.toString().contains('Timeout')
            ? 'Die Anfrage hat zu lange gedauert. Bitte versuche es erneut.'
            : 'Es ist ein Fehler aufgetreten. Bitte versuche es erneut.';
        await chatHistory.add(ChatMessage(
          text: errorMsg,
          isUser: false,
          type: MessageType.error,
        ));
        _scrollToBottom();
      }
    } finally {
      setState(() {
        _isStreaming = false;
        _isThinking = false;
        _streamingText = '';
        _isSending = false;
      });
    }
  }

  Future<void> _sendMessageStream(
    ChatService chatService,
    String text,
    PersonaService persona,
    MemoryService memory,
    ChatHistoryService chatHistory,
    PersonaEvolutionService? personaEvolution,
  ) async {
    setState(() {
      _isThinking = true;
      _isStreaming = true;
      _streamingText = '';
    });
    _scrollToBottom();

    final stream = chatService.streamResponse(
      userMessage: text,
      persona: persona,
      memory: memory,
      history: chatHistory.messages,
      personaEvolution: personaEvolution,
      onToolActivity: (msg) {
        if (mounted) {
          chatHistory.add(msg);
          _scrollToBottom();
        }
      },
    );

    final buffer = StringBuffer();
    bool firstChunk = true;

    await for (final chunk in stream) {
      if (chunk == '🔧') {
        // Tool execution marker — show activity, keep thinking state
        setState(() => _isThinking = false);
        continue;
      }
      if (firstChunk) {
        firstChunk = false;
        setState(() => _isThinking = false);
      }
      buffer.write(chunk);
      setState(() => _streamingText = buffer.toString());
      _scrollToBottom();
    }

    final fullReply = buffer.toString();
    if (fullReply.isNotEmpty) {
      final assistantMsg = ChatMessage(text: fullReply, isUser: false);
      await chatHistory.add(assistantMsg);
    }

    setState(() {
      _isStreaming = false;
      _isThinking = false;
      _streamingText = '';
    });

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }



  Future<void> _toggleLiveVoice() async {
    if (_liveVoice == null || !_liveVoice!.isActive) {
      _liveVoice ??= _createLiveVoiceService(context);
      _liveVoice!.addListener(_onLiveVoiceUpdate);
      setState(() {});
      await _liveVoice!.start();
    } else {
      _liveVoice!.removeListener(_onLiveVoiceUpdate);
      await _liveVoice!.stop();
      setState(() {});
    }
  }

  LiveVoiceService _createLiveVoiceService(BuildContext context) {
    final stt = SttService();
    final tts = context.read<TtsPlaybackService>();
    final llm = context.read<OllamaCloudService>();
    final chatHistory = context.read<ChatHistoryService>();
    final memory = context.read<MemoryService>();
    final persona = context.read<PersonaService>();
    return LiveVoiceService(
      stt: stt,
      tts: tts,
      llm: llm,
      chatHistory: chatHistory,
      memory: memory,
      persona: persona,
      toolRegistry: _toolRegistry,
    );
  }

  void _onLiveVoiceUpdate() {
    final lv = _liveVoice;
    if (lv == null) return;

    if (lv.state == LiveVoiceState.thinking || lv.state == LiveVoiceState.speaking) {
      _scrollToBottom();
    }

    if (lv.state == LiveVoiceState.error && lv.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(lv.errorMessage!, maxLines: 2),
        duration: const Duration(seconds: 3),
        backgroundColor: AppColors.error.withOpacity(0.9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
      ));
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final chatHistory = context.watch<ChatHistoryService>();
    final persona = context.watch<PersonaService>();
    final isLiveActive = _liveVoice?.isActive ?? false;
    final liveState = _liveVoice?.state ?? LiveVoiceState.idle;

    return Scaffold(
      backgroundColor: AppColors.bgDarkest,
      resizeToAvoidBottomInset: true,
      body: Column(
          children: [
            // ─── Custom Header ───
            _buildHeader(persona, isLiveActive),
            // ─── Messages ───
            Expanded(
              child: Stack(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [Color(0xFF03030A), Color(0xFF14141E), Color(0xFF03030A)],
                      ),
                    ),
                    child: ListView.builder(
                      controller: _scrollController,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                      itemCount: chatHistory.messages.length,
                      itemBuilder: (context, index) {
                        final message = chatHistory.messages[index];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            MessageBubble(message: message),
                          ],
                        );
                      },
                    ),
                  ),
                  // Fade out at top
                  Positioned(
                    top: 0, left: 0, right: 0,
                    child: IgnorePointer(
                      child: Container(
                        height: 20,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0xFF14141E),
                              Color(0xFF14141E).withOpacity(0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ─── Live Status Bar ───// ─── Live Status Bar ───
            if (isLiveActive) _LiveStatusBar(
              liveVoice: _liveVoice!,
              onStop: _toggleLiveVoice,
            ),

            // ─── Thinking Indicator ───
            if (_isThinking || (isLiveActive && liveState == LiveVoiceState.thinking))
              const _ThinkingBar(),

            // ─── Streaming Bubble ───
            if (_isStreaming && _streamingText.isNotEmpty)
              _StreamingBubble(text: _streamingText),

            // ─── Input ───
            MessageInput(
              onSend: _sendMessage,
              isSending: _isSending,
              isLiveModeActive: isLiveActive,
              onToggleLiveMode: _toggleLiveVoice,
              liveVoiceState: liveState,
            ),

            // ─── Proactive Card ───
            if (_proactiveSuggestion != null && !isLiveActive)
              ProactiveCard(
                suggestion: _proactiveSuggestion!,
                onSend: (text) {
                  setState(() => _proactiveSuggestion = null);
                  _sendMessage(text);
                },
              ),

            // ─── Quick Actions ───

          ],
        ),
    );
  }

  Widget _buildHeader(PersonaService persona, bool isLiveActive) {
    return ClipRect(
      child: Container(
        color: AppColors.bgDarkest,
        child: SafeArea(
          bottom: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            decoration: BoxDecoration(
              color: AppColors.bgDarkest.withOpacity(0.75),
              border: Border(
                bottom: BorderSide(
                  color: AppColors.glassBorder.withOpacity(0.2),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                // Avatar ohne Shadow
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      persona.name.isNotEmpty ? persona.name[0].toUpperCase() : 'A',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        persona.name.isNotEmpty ? persona.name : 'AI-Buddy',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      _StatusLine(
                        isThinking: _isThinking && !_isStreaming,
                        isStreaming: _isStreaming,
                        isLiveActive: isLiveActive,
                      ),
                    ],
                  ),
                ),
                // Settings button
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.primary.withOpacity(0.15),
                          AppColors.secondary.withOpacity(0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.2),
                      ),
                    ),
                    child: Icon(
                      Icons.tune_rounded,
                      color: AppColors.primary.withOpacity(0.9),
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Thinking Bar ───

class _ThinkingBar extends StatelessWidget {
  const _ThinkingBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.bgCard.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.glassBorder.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              shape: BoxShape.circle,
            ),
            child: const Center(child: SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Colors.white),
              ),
            )),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Denkt nach…',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                const _AnimatedDots(),
              ],
            ),
          ),
          Icon(Icons.psychology_alt_rounded, size: 20, color: AppColors.primary.withOpacity(0.6)),
        ],
      ),
    );
  }
}

// ─── Animated Dot Loader ───

class _AnimatedDots extends StatefulWidget {
  const _AnimatedDots();

  @override
  State<_AnimatedDots> createState() => _AnimatedDotsState();
}

class _AnimatedDotsState extends State<_AnimatedDots>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (index) {
      return AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1400),
        value: index * 0.33,
      )..repeat();
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: _controllers.asMap().entries.map((entry) {
        return AnimatedBuilder(
          animation: entry.value,
          builder: (_, __) {
            final progress = (entry.value.value + entry.value.value * 0.5) % 1.0;
            final offset = sin(progress * pi * 2) * 3;
            final opacity = 0.4 + (sin(progress * pi * 2) + 1) * 0.3;
            return Transform.translate(
              offset: Offset(0, offset),
              child: Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(opacity),
                  shape: BoxShape.circle,
                ),
              ),
            );
          },
        );
      }).toList(),
    );
  }
}

// ─── Streaming Bubble ───

class _StreamingBubble extends StatelessWidget {
  final String text;
  const _StreamingBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        margin: const EdgeInsets.fromLTRB(16, 2, 16, 6),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.bgCard.withOpacity(0.5),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppColors.primary.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.8),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Schreibt',
                  style: TextStyle(
                    color: AppColors.primary.withOpacity(0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Live Status Bar ───

class _LiveStatusBar extends StatelessWidget {
  final LiveVoiceService liveVoice;
  final VoidCallback onStop;

  const _LiveStatusBar({required this.liveVoice, required this.onStop});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: liveVoice,
      builder: (context, _) {
        final state = liveVoice.state;
        final stateLabel = switch (state) {
          LiveVoiceState.idle => 'Bereit',
          LiveVoiceState.listening => 'Ich höre zu…',
          LiveVoiceState.thinking => 'Denkt nach…',
          LiveVoiceState.speaking => 'Spricht…',
          LiveVoiceState.error => 'Fehler',
        };
        final stateColor = switch (state) {
          LiveVoiceState.idle => AppColors.textTertiary,
          LiveVoiceState.listening => AppColors.success,
          LiveVoiceState.thinking => AppColors.secondary,
          LiveVoiceState.speaking => AppColors.primary,
          LiveVoiceState.error => AppColors.error,
        };
        final gradient = switch (state) {
          LiveVoiceState.listening => LinearGradient(
            colors: [AppColors.success.withOpacity(0.2), AppColors.success.withOpacity(0.05)],
          ),
          LiveVoiceState.thinking => LinearGradient(
            colors: [AppColors.secondary.withOpacity(0.2), AppColors.secondary.withOpacity(0.05)],
          ),
          LiveVoiceState.speaking => LinearGradient(
            colors: [AppColors.primary.withOpacity(0.2), AppColors.primary.withOpacity(0.05)],
          ),
          LiveVoiceState.error => LinearGradient(
            colors: [AppColors.error.withOpacity(0.2), AppColors.error.withOpacity(0.05)],
          ),
          _ => null,
        };

        return AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: gradient,
            color: gradient == null ? AppColors.bgElevated.withOpacity(0.5) : null,
            border: Border(
              top: BorderSide(color: stateColor.withOpacity(0.3)),
            ),
          ),
          child: Row(
            children: [
              if (state == LiveVoiceState.listening)
                _PulsingIcon(icon: Icons.mic_rounded, color: stateColor, size: 22)
              else
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: stateColor.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    switch (state) {
                      LiveVoiceState.thinking => Icons.psychology_rounded,
                      LiveVoiceState.speaking => Icons.volume_up_rounded,
                      LiveVoiceState.error => Icons.error_outline_rounded,
                      _ => Icons.mic_none_rounded,
                    },
                    size: 18, color: stateColor,
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(stateLabel, style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700, color: stateColor)),
                    if (liveVoice.lastTranscript != null &&
                        (state == LiveVoiceState.thinking || state == LiveVoiceState.speaking))
                      Text(
                        '"${_trunc(liveVoice.lastTranscript!, 60)}"',
                        style: TextStyle(
                          fontSize: 12, fontStyle: FontStyle.italic,
                          color: AppColors.textSecondary.withOpacity(0.8)),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onStop,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.error.withOpacity(0.3), AppColors.error.withOpacity(0.15)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.stop_rounded, size: 16, color: AppColors.error),
                    const SizedBox(width: 6),
                    Text('Stop', style: TextStyle(
                      color: AppColors.error, fontWeight: FontWeight.w700, fontSize: 13)),
                  ]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _trunc(String s, int max) =>
      s.length > max ? '${s.substring(0, max)}...' : s;
}

// ─── Pulsing Icon ───

class _PulsingIcon extends StatefulWidget {
  final IconData icon; final Color color; final double size;
  const _PulsingIcon({required this.icon, required this.color, required this.size});

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween(begin: 0.75, end: 1.15).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: widget.color.withOpacity(0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(widget.icon, size: widget.size, color: widget.color),
      ),
    );
  }
}

// ─── Status Line: animated "denkt…" / "schreibt…" / "Online" ───

class _StatusLine extends StatefulWidget {
  final bool isThinking;
  final bool isStreaming;
  final bool isLiveActive;

  const _StatusLine({
    required this.isThinking,
    required this.isStreaming,
    required this.isLiveActive,
  });

  @override
  State<_StatusLine> createState() => _StatusLineState();
}

class _StatusLineState extends State<_StatusLine> with SingleTickerProviderStateMixin {
  late AnimationController _dotController;
  int _dotCount = 0;

  @override
  void initState() {
    super.initState();
    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() {
            _dotCount = (_dotCount + 1) % 4;
          });
          _dotController.forward(from: 0);
        }
      });
  }

  @override
  void didUpdateWidget(covariant _StatusLine old) {
    super.didUpdateWidget(old);
    if ((widget.isThinking || widget.isStreaming) && !_dotController.isAnimating) {
      _dotController.forward();
    }
    if (!widget.isThinking && !widget.isStreaming) {
      _dotController.stop();
      _dotCount = 0;
    }
  }

  @override
  void dispose() {
    _dotController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String label;
    Color color;
    bool animate;

    if (widget.isLiveActive) {
      label = 'Live-Sprachmodus aktiv';
      color = AppColors.success;
      animate = false;
    } else if (widget.isThinking) {
      label = 'denkt${'.' * ((_dotCount % 3) + 1)}';
      color = AppColors.primary;
      animate = true;
    } else if (widget.isStreaming) {
      label = 'schreibt${'.' * ((_dotCount % 3) + 1)}';
      color = AppColors.secondary;
      animate = true;
    } else {
      label = 'Online';
      color = AppColors.success;
      animate = false;
    }

    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: animate ? color.withOpacity(0.5 + _dotController.value * 0.5) : (widget.isLiveActive ? color : color.withOpacity(0.4)),
            shape: BoxShape.circle,
            boxShadow: animate || widget.isLiveActive
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.5),
                      blurRadius: 6,
                    ),
                  ]
                : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: animate ? color : (widget.isLiveActive ? color : AppColors.textTertiary),
            fontWeight: animate || widget.isLiveActive ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
