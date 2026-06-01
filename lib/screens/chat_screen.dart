import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../widgets/message_bubble.dart';
import '../widgets/message_input.dart';
import '../services/chat_service.dart';
import '../services/chat_history_service.dart';
import '../services/memory_service.dart';
import '../services/buddy_capabilities_service.dart';
import '../services/persona_service.dart';
import '../services/persona_evolution_service.dart';
import '../services/live_voice_service.dart';
import '../services/stt_service.dart';
import '../services/tts_playback_service.dart';
import '../services/secure_config_service.dart';
import '../services/location_service.dart';
import '../services/ollama_cloud_service.dart';
import '../tools/tool_registry.dart';
import '../models/chat_message.dart';
import 'settings_screen.dart';

import '../services/proactive_engine.dart';
import '../services/self_identity_service.dart';
import '../services/buddy_notifier.dart';
import '../core/theme/app_colors.dart';
import '../core/version.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<double> _scrollOffsetNotifier = ValueNotifier<double>(0.0);
  bool _isStreaming = false;
  bool _isThinking = false;
  bool _isSending = false;
  String _streamingText = '';
  LiveVoiceService? _liveVoice;
  ToolRegistry? _toolRegistry;
  ProactiveEngine? _proactive;
  bool _isAppInBackground = false;
  final SttService _sttService = SttService();
  bool _showScrollToBottom = false;

  // Multi-select for message copying
  final Set<int> _selectedIndices = <int>{};
  bool get _isMultiSelectMode => _selectedIndices.isNotEmpty;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onScroll);
    // Ensure nav bar is transparent (no AppBar → theme overlay doesn't apply).
    // Done once in initState — calling in build() would re-run on every rebuild.
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarDividerColor: Colors.transparent,
    ));
    _initToolRegistry();
    _initProactiveEngine();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isAppInBackground = state != AppLifecycleState.resumed;
    // Clear notifications when user returns to chat
    if (state == AppLifecycleState.resumed) {
      BuddyNotifier.clearAll();
    }
  }

  void _onScroll() {
    _scrollOffsetNotifier.value = _scrollController.offset;
    // Show scroll-to-bottom button when not at bottom
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.offset;
      final atBottom = maxScroll - currentScroll < 100;
      if (_showScrollToBottom != !atBottom) {
        setState(() => _showScrollToBottom = !atBottom);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _scrollOffsetNotifier.dispose();
    _liveVoice?.removeListener(_onLiveVoiceUpdate);
    _liveVoice?.stop();
    _proactive?.stop();
    super.dispose();
  }

  void _initProactiveEngine() {
    try {
      final memory = context.read<MemoryService>();
      _proactive = ProactiveEngine(
        memory: memory,
      );
      _proactive!.init().then((_) {
        if (mounted) {
          _proactive!.start(
            onMessage: (msg) {
              if (!mounted) return;
              // Inject as a system-like proactive message into chat
              final chatHistory = context.read<ChatHistoryService>();
              chatHistory.add(ChatMessage(
                text: msg,
                isUser: false,
                type: MessageType.system,
              ));
            },
          );
        }
      });
    } catch (e) {
      debugPrint('ProactiveEngine init failed: $e');
    }
  }

  void _initToolRegistry() {
    try {
      // Reuse the fully-configured ToolRegistry from Provider (set up in main.dart)
      // rather than creating a duplicate with fewer tools registered.
      _toolRegistry = context.read<ToolRegistry>();
    } catch (e) {
      debugPrint('_initToolRegistry fallback: $e');
      _toolRegistry = ToolRegistry.createDefault();
    }
  }

  // ── Multi-Select ──
  void _toggleSelection(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
      } else {
        _selectedIndices.add(index);
      }
    });
  }

  void _exitMultiSelect() {
    setState(() => _selectedIndices.clear());
  }

  void _copySelectedMessages() {
    final chatHistory = context.read<ChatHistoryService>();
    final selected = _selectedIndices.toList()..sort();
    final buffer = StringBuffer();
    for (final i in selected) {
      if (i < chatHistory.messages.length) {
        final msg = chatHistory.messages[i];
        final buddyName = context.read<SecureConfigService>().buddyName;
        final prefix = msg.isUser ? 'Du' : buddyName;
        buffer.writeln('[$prefix] ${msg.text}');
      }
    }
    Clipboard.setData(ClipboardData(text: buffer.toString().trim()));
    HapticFeedback.mediumImpact();
    _exitMultiSelect();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${selected.length} Nachricht${selected.length == 1 ? '' : 'en'} kopiert',
        style: TextStyle(fontSize: 13)),
      duration: const Duration(seconds: 1),
      backgroundColor: AppColors.bgElevated,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
    ));
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _isSending) return;
    setState(() => _isSending = true);

    final memory = context.read<MemoryService>();
    final chatHistory = context.read<ChatHistoryService>();
    final personaEvolution = context.read<PersonaEvolutionService>();
    final selfIdentity = context.read<SelfIdentityService>();
    final persona = context.read<PersonaService>();
    final locationService = context.read<LocationService>();
    // Capture all context-dependent services BEFORE any await — using `context`
    // after an async gap is unsafe (widget may be unmounted).
    final cloudService = context.read<OllamaCloudService>();
    final configService = context.read<SecureConfigService>();
    final buddyCapabilities = context.read<BuddyCapabilitiesService>();
    final buddyName = configService.buddyName;

    setState(() => _isThinking = true);

    final userMsg = ChatMessage(text: text, isUser: true);
    await chatHistory.add(userMsg);
    HapticFeedback.selectionClick();
    _scrollToBottom();

    try {
      final chatService = ChatService(cloudService: cloudService, configService: configService, toolRegistry: _toolRegistry, selfIdentity: selfIdentity, locationService: locationService, buddyCapabilities: buddyCapabilities);
      // Use sendMessage (with tool support) as primary path
      final result = await chatService.sendMessage(
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
      final assistantMsg = ChatMessage(
        text: result.text,
        isUser: false,
        metadata: result.metadata,
      );
      await chatHistory.add(assistantMsg);
      _scrollToBottom();

      // Notify in taskbar if app is in background
      if (_isAppInBackground) {
        await BuddyNotifier.notifyBuddyReply(
          buddyName: buddyName,
          message: result.text,
          appInBackground: true,
        );
      }
    } catch (e) {
      debugPrint('sendMessage failed: $e, falling back to streaming');
      try {
        final chatService = ChatService(cloudService: cloudService, configService: configService, toolRegistry: _toolRegistry, selfIdentity: selfIdentity, locationService: locationService, buddyCapabilities: buddyCapabilities);
        await _sendMessageStream(chatService, text, persona, memory, chatHistory, personaEvolution, buddyName);
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
    String buddyName,
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
        // Tool execution marker - show activity, keep thinking state
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

      // Notify in taskbar if app is in background
      if (_isAppInBackground) {
        await BuddyNotifier.notifyBuddyReply(
          buddyName: buddyName,
          message: fullReply,
          appInBackground: true,
        );
      }
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
    final stt = _sttService;
    final tts = context.read<TtsPlaybackService>();
    final chatService = ChatService(
      cloudService: context.read<OllamaCloudService>(),
      configService: context.read<SecureConfigService>(),
      toolRegistry: _toolRegistry,
      selfIdentity: context.read<SelfIdentityService>(),
      locationService: context.read<LocationService>(),
      buddyCapabilities: context.read<BuddyCapabilitiesService>(),
    );
    final chatHistory = context.read<ChatHistoryService>();
    final memory = context.read<MemoryService>();
    final persona = context.read<PersonaService>();
    return LiveVoiceService(
      stt: stt,
      tts: tts,
      chatService: chatService,
      chatHistory: chatHistory,
      memory: memory,
      persona: persona,
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
        backgroundColor: AppColors.error.withValues(alpha: 0.9),
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
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF121216),
              Color(0xFF0B0B0F),
            ],
          ),
        ),
        child: Column(
          children: [
          // ─── Custom Header (Telegram style) ───
          _isMultiSelectMode
            ? _buildMultiSelectHeader()
            : _buildHeader(persona, isLiveActive),
          // ─── Messages ───
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(0, 4, 0, 4),
              itemCount: chatHistory.messages.length,
              itemBuilder: (context, index) {
                final message = chatHistory.messages[index];
                final isSelected = _selectedIndices.contains(index);
                return GestureDetector(
                  onTap: _isMultiSelectMode
                    ? () => _toggleSelection(index)
                    : null,
                  child: MessageBubble(
                    message: message,
                    index: index,
                    scrollOffsetNotifier: _scrollOffsetNotifier,
                    isSelected: isSelected,
                    onToggleSelection: _isMultiSelectMode || _selectedIndices.isEmpty
                      ? () => _toggleSelection(index)
                      : null,
                  ),
                );
              },
            ),
          ),

            // ─── Live Status Bar ───
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

            // ─── Input + Scroll-to-Bottom ───
            SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                // Scroll-to-bottom button — Kreis mit Pfeil nach unten
                if (_showScrollToBottom)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Center(
                      child: GestureDetector(
                        onTap: _scrollToBottom,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2A2A32),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.12),
                              width: 1,
                            ),
                          ),
                          child: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: AppColors.textSecondary,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                MessageInput(
                  onSend: _sendMessage,
                  isSending: _isSending,
                  isLiveModeActive: isLiveActive,
                  onToggleLiveMode: _toggleLiveVoice,
                  liveVoiceState: liveState,
                  sttService: _sttService,
                ),
              ],
            ),
            ),

          ],
        ),
      ),
    );
  }

  Widget _buildHeader(PersonaService persona, bool isLiveActive) {
    return SafeArea(
      bottom: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        decoration: BoxDecoration(
          color: Colors.transparent,
          border: Border(
            bottom: BorderSide(color: AppColors.glassBorder),
          ),
        ),
        child: Row(
          children: [
            // Avatar: Periwinkle-Kreis, weißer Buchstabe
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.25),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
              ),
              child: Center(
                child: Text(
                  persona.name.isNotEmpty ? persona.name[0].toUpperCase() : 'A',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
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
                    persona.name.isNotEmpty ? persona.name : context.select<SecureConfigService, String>((s) => s.buddyName),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    appVersion,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.4),
                      height: 1.0,
                    ),
                  ),
                  _StatusLine(
                    isThinking: _isThinking && !_isStreaming,
                    isStreaming: _isStreaming,
                    isLiveActive: isLiveActive,
                  ),
                ],
              ),
            ),
            // Settings button - clean, minimal
            Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  child: Icon(
                    Icons.tune_rounded,
                    color: AppColors.textTertiary.withValues(alpha: 0.7),
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMultiSelectHeader() {
    return SafeArea(
      bottom: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        decoration: BoxDecoration(
          color: AppColors.bgElevated,
          border: Border(
            bottom: BorderSide(color: AppColors.glassBorder),
          ),
        ),
        child: Row(
          children: [
            Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: _exitMultiSelect,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  child: Icon(Icons.close_rounded, color: AppColors.textSecondary, size: 22),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${_selectedIndices.length} ausgewählt',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            // Copy button
            if (_selectedIndices.isNotEmpty)
              Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: _copySelectedMessages,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    child: Icon(Icons.copy_rounded, color: AppColors.secondary, size: 22),
                  ),
                ),
              ),
          ],
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
        color: AppColors.bgCard.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.glassBorder.withValues(alpha: 0.3)),
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
              children: const [
                Text('Denkt nach...',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                SizedBox(height: 4),
                _AnimatedDots(),
              ],
            ),
          ),
          Icon(Icons.psychology_alt_rounded, size: 20, color: AppColors.primary.withValues(alpha: 0.6)),
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
    for (final c in _controllers) {
      c.dispose();
    }
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
                  color: AppColors.primary.withValues(alpha: opacity),
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
          color: AppColors.bgCard.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.3),
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
                    color: AppColors.primary.withValues(alpha: 0.8),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Schreibt',
                  style: TextStyle(
                    color: AppColors.primary.withValues(alpha: 0.7),
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
          LiveVoiceState.listening => 'Ich höre zu...',
          LiveVoiceState.thinking => 'Denkt nach...',
          LiveVoiceState.speaking => 'Spricht...',
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
            colors: [AppColors.success.withValues(alpha: 0.2), AppColors.success.withValues(alpha: 0.05)],
          ),
          LiveVoiceState.thinking => LinearGradient(
            colors: [AppColors.secondary.withValues(alpha: 0.2), AppColors.secondary.withValues(alpha: 0.05)],
          ),
          LiveVoiceState.speaking => LinearGradient(
            colors: [AppColors.primary.withValues(alpha: 0.2), AppColors.primary.withValues(alpha: 0.05)],
          ),
          LiveVoiceState.error => LinearGradient(
            colors: [AppColors.error.withValues(alpha: 0.2), AppColors.error.withValues(alpha: 0.05)],
          ),
          _ => null,
        };

        return AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: gradient,
            color: gradient == null ? AppColors.bgElevated.withValues(alpha: 0.5) : null,
            border: Border(
              top: BorderSide(color: stateColor.withValues(alpha: 0.3)),
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
                    color: stateColor.withValues(alpha: 0.15),
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
                          color: AppColors.textSecondary.withValues(alpha: 0.8)),
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
                      colors: [AppColors.error.withValues(alpha: 0.3), AppColors.error.withValues(alpha: 0.15)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: const [
                    Icon(Icons.stop_rounded, size: 16, color: AppColors.error),
                    SizedBox(width: 6),
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
          color: widget.color.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(widget.icon, size: widget.size, color: widget.color),
      ),
    );
  }
}

// ─── Status Line: animated "denkt..." / "schreibt..." / "Online" ───

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
            color: animate ? color.withValues(alpha: 0.5 + _dotController.value * 0.5) : (widget.isLiveActive ? color : color.withValues(alpha: 0.4)),
            shape: BoxShape.circle,
            boxShadow: animate || widget.isLiveActive
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.5),
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
