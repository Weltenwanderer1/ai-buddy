import 'dart:math';
import 'dart:io';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
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
import 'package:audio_session/audio_session.dart';
import '../services/tts_playback_service.dart';
import '../services/secure_config_service.dart';
import '../services/settings_service.dart';
import '../services/location_service.dart';
import '../services/ollama_cloud_service.dart';
import '../services/anthropic_service.dart';
import '../tools/tool_registry.dart';
import '../models/chat_message.dart';
import 'settings_screen.dart';
import 'navigation_map_screen.dart';

import '../services/proactive_engine.dart';
import '../services/proactive_notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/self_identity_service.dart';
import '../services/buddy_notifier.dart';
import '../services/timer_service.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/buddy_colors.dart';
import '../widgets/active_timer_bar.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();
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

  // Audio routing: speaker vs earpiece
  bool _useEarpiece = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onScroll);
    // Ensure nav bar is transparent (no AppBar → theme overlay doesn't apply).
    // Done once in initState — calling in build() would re-run on every rebuild.
    // System UI overlay style wird jetzt dynamisch in build() via
    // AnnotatedRegion gesetzt, damit Theme-Wechsel sofort wirken.
    _initToolRegistry();
    _initProactiveEngine();
    _checkPendingProactiveReply();
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
    _liveVoice?.removeListener(_onLiveVoiceUpdate);
    _liveVoice?.stop();
    _proactive?.stop();
    super.dispose();
  }

  void _initProactiveEngine() {
    try {
      final memory = context.read<MemoryService>();
      final location = context.read<LocationService>();
      final timer = context.read<TimerService>();
      final notifications = context.read<ProactiveNotificationService>();
      _proactive = ProactiveEngine(
        memory: memory,
        locationService: location,
        timerService: timer,
        notificationService: notifications,
      );
      _proactive!.init().then((_) {
        if (mounted) {
          _proactive!.start(
            onMessage: (msg, {actions}) {
              if (!mounted) return;
              // Inject as a system-like proactive message into chat
              final chatHistory = context.read<ChatHistoryService>();
              chatHistory.add(ChatMessage(
                text: msg,
                isUser: false,
                type: MessageType.system,
                metadata: {'proactive': true},
              ));
            },
          );
        }
      });
    } catch (e) {
      debugPrint('ProactiveEngine init failed: $e');
    }
  }

  void _checkPendingProactiveReply() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pending = prefs.getString('proactive_pending_reply');
      if (pending != null && pending.isNotEmpty) {
        await prefs.remove('proactive_pending_reply');
        if (!mounted) return;
        final chatHistory = context.read<ChatHistoryService>();
        chatHistory.add(ChatMessage(
          text: pending,
          isUser: false,
          type: MessageType.system,
          metadata: {'proactive': true},
        ));
      }
    } catch (e) {
      debugPrint('_checkPendingProactiveReply: $e');
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
      backgroundColor: context.buddy.elev,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
    ));
  }

  Future<void> _sendMessage(String text, {Map<String, dynamic>? fileMetadata}) async {
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
    final anthropicService = context.read<AnthropicService?>();
    final appLanguage = context.read<SettingsService>().appLanguage;
    final buddyName = configService.buddyName;

    setState(() => _isThinking = true);

    final userMsg = ChatMessage(
      text: text,
      isUser: true,
      metadata: fileMetadata,
    );
    await chatHistory.add(userMsg);
    HapticFeedback.selectionClick();
    _scrollToBottom();

    try {
      final chatService = ChatService(cloudService: cloudService, anthropicService: anthropicService, configService: configService, toolRegistry: _toolRegistry, selfIdentity: selfIdentity, locationService: locationService, buddyCapabilities: buddyCapabilities, appLanguage: appLanguage);
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
        fileMetadata: fileMetadata,
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
        final chatService = ChatService(cloudService: cloudService, anthropicService: anthropicService, configService: configService, toolRegistry: _toolRegistry, selfIdentity: selfIdentity, locationService: locationService, buddyCapabilities: buddyCapabilities, appLanguage: appLanguage);
        await _sendMessageStream(chatService, text, persona, memory, chatHistory, personaEvolution, buddyName, fileMetadata);
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
      if (mounted) {
        setState(() {
          _isStreaming = false;
          _isThinking = false;
          _streamingText = '';
          _isSending = false;
        });
      }
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
    Map<String, dynamic>? fileMetadata,
  ) async {
    // Wird erst nach fehlgeschlagenem sendMessage (also nach awaits) gerufen
    // — der State kann bereits disposed sein.
    if (mounted) {
      setState(() {
        _isThinking = true;
        _isStreaming = true;
        _streamingText = '';
      });
    }
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
      fileMetadata: fileMetadata,
    );

    final buffer = StringBuffer();
    bool firstChunk = true;

    await for (final chunk in stream) {
      if (chunk == '🔧') {
        // Tool execution marker - show activity, keep thinking state
        if (mounted) setState(() => _isThinking = false);
        continue;
      }
      if (firstChunk) {
        firstChunk = false;
        if (mounted) setState(() => _isThinking = false);
      }
      buffer.write(chunk);
      if (mounted) setState(() => _streamingText = buffer.toString());
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

    if (mounted) {
      setState(() {
        _isStreaming = false;
        _isThinking = false;
        _streamingText = '';
      });
    }

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
      // Configure audio session for speaker/earpiece
      await _configureAudioSession();
      if (!mounted) return;
      setState(() {});
      await _liveVoice!.start();
    } else {
      _liveVoice!.removeListener(_onLiveVoiceUpdate);
      await _liveVoice!.stop();
      await _restoreAudioSession();
      if (mounted) setState(() {});
    }
  }

  void _toggleEarpiece() {
    setState(() => _useEarpiece = !_useEarpiece);
    _configureAudioSession();
  }

  Future<void> _configureAudioSession() async {
    try {
      final session = await AudioSession.instance;
      if (_useEarpiece) {
        await session.configure(const AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
          avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.allowBluetooth,
          avAudioSessionMode: AVAudioSessionMode.voiceChat,
          androidAudioAttributes: AndroidAudioAttributes(
            contentType: AndroidAudioContentType.speech,
            usage: AndroidAudioUsage.voiceCommunication,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        ));
      } else {
        await session.configure(const AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
          avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.defaultToSpeaker,
          avAudioSessionMode: AVAudioSessionMode.defaultMode,
          androidAudioAttributes: AndroidAudioAttributes(
            contentType: AndroidAudioContentType.speech,
            usage: AndroidAudioUsage.media,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        ));
      }
      await session.setActive(true);
    } catch (e) {
      debugPrint('AudioSession config error: $e');
    }
  }

  Future<void> _restoreAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.setActive(false);
    } catch (e) {
      debugPrint('AudioSession restore error: $e');
    }
  }

  LiveVoiceService _createLiveVoiceService(BuildContext context) {
    final stt = _sttService;
    final tts = context.read<TtsPlaybackService>();
    final appLanguage = context.read<SettingsService>().appLanguage;
    final chatService = ChatService(
      cloudService: context.read<OllamaCloudService>(),
      anthropicService: context.read<AnthropicService?>(),
      configService: context.read<SecureConfigService>(),
      toolRegistry: _toolRegistry,
      selfIdentity: context.read<SelfIdentityService>(),
      locationService: context.read<LocationService>(),
      buddyCapabilities: context.read<BuddyCapabilitiesService>(),
      appLanguage: appLanguage,
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
      sttLocale: SttService.localeFor(appLanguage),
    );
  }

  void _onLiveVoiceUpdate() {
    final lv = _liveVoice;
    if (lv == null || !mounted) return;

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
    final brightness = Theme.of(context).brightness;
    final isLight = brightness == Brightness.light;
    final showThinking = _isThinking || (isLiveActive && liveState == LiveVoiceState.thinking);
    final showStreaming = _isStreaming && _streamingText.isNotEmpty;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isLight ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: context.buddy.wall,
        systemNavigationBarIconBrightness: isLight ? Brightness.dark : Brightness.light,
        systemNavigationBarDividerColor: context.buddy.wall,
      ),
      sized: true,
      child: Scaffold(
        backgroundColor: context.buddy.wall,
        resizeToAvoidBottomInset: true,
        body: Stack(
          children: [
            // ─── Full-height messages ───
            Positioned.fill(
              child: ListView.builder(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  0,
                  MediaQuery.paddingOf(context).top + 60,
                  0,
                  MediaQuery.paddingOf(context).bottom + 80
                      + (showThinking || showStreaming ? 70 : 0),
                ),
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
                      isSelected: isSelected,
                      onToggleSelection: _isMultiSelectMode || _selectedIndices.isEmpty
                        ? () => _toggleSelection(index)
                        : null,
                    ),
                  );
                },
              ),
            ),

            // ─── Header (top overlay) ───
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _isMultiSelectMode
                ? _buildMultiSelectHeader()
                : _buildHeader(persona, isLiveActive),
            ),

            // ─── Bottom bar (transparent overlay) ───
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ─── Live Status Bar ───
                    if (isLiveActive) _LiveStatusBar(
                      liveVoice: _liveVoice!,
                      onStop: _toggleLiveVoice,
                    ),

                    // ─── Thinking Indicator ───
                    if (showThinking)
                      const _ThinkingBar(),

                    // ─── Streaming Bubble ───
                    if (showStreaming)
                      _StreamingBubble(text: _streamingText),

                    // ─── Timer Overlay ───
                    Consumer<TimerService>(
                      builder: (context, timerService, child) {
                        final timers = timerService.activeTimers;
                        if (timers.isEmpty) return const SizedBox.shrink();
                        return ActiveTimerBar(timers: timers);
                      },
                    ),

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
                                color: context.buddy.pill.withValues(alpha: 0.60),
                                shape: BoxShape.circle,
                                boxShadow: context.buddy.cardShadow,
                                border: Border.all(
                                  color: context.buddy.chipBorder,
                                  width: 1.5,
                                ),
                              ),
                              child: Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: context.buddy.t2,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ),

                    MessageInput(
                      onSend: _sendMessage,
                      onMenuTap: _showAttachmentMenu,
                      isSending: _isSending,
                      isLiveModeActive: isLiveActive,
                      onToggleLiveMode: _toggleLiveVoice,
                      liveVoiceState: liveState,
                      sttService: _sttService,
                      useEarpiece: _useEarpiece,
                      onToggleEarpiece: _toggleEarpiece,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
    ),
  );
  }

  Widget _buildHeader(PersonaService persona, bool isLiveActive) {
    final c = context.buddy;
    final name = persona.name.isNotEmpty
        ? persona.name
        : context.select<SecureConfigService, String>((s) => s.buddyName);
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: c.pill.withValues(alpha: 0.60),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: c.border, width: 1),
              ),
              child: Row(
                children: [
                  // Avatar: kleiner Periwinkle-Kreis mit Icon statt Buchstabe
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: c.t1,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Settings-Button in der Pille
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
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          Icons.tune_rounded,
                          color: c.t3.withValues(alpha: 0.7),
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMultiSelectHeader() {
    final c = context.buddy;
    return SafeArea(
      bottom: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        decoration: BoxDecoration(
          color: c.elev,
          border: Border(
            bottom: BorderSide(color: c.border),
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
                  child: Icon(Icons.close_rounded, color: c.t2, size: 22),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${_selectedIndices.length} ausgewählt',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: c.t1,
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

  // ─── Attachment Menu ───
  void _showAttachmentMenu() {
    final c = context.buddy;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          border: Border(top: BorderSide(color: c.border, width: 1)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Anhang',
                style: TextStyle(color: c.t1, fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              _MenuTile(
                icon: Icons.photo_camera_rounded,
                label: 'Foto aufnehmen',
                color: c.t1,
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndAttachImage(ImageSource.camera);
                },
              ),
              _MenuTile(
                icon: Icons.photo_library_rounded,
                label: 'Aus Galerie',
                color: c.t1,
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndAttachImage(ImageSource.gallery);
                },
              ),
              _MenuTile(
                icon: Icons.map_rounded,
                label: 'OSM Navigation',
                color: c.t1,
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NavigationMapScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndAttachImage(ImageSource source) async {
    final picker = ImagePicker();
    try {
      final xfile = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (xfile == null) return;

      final path = xfile.path;
      final file = File(path);
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return;
      // Kamera/Galerie pausieren die Activity — Widget kann weg sein.
      if (!mounted) return;

      // Send as a special user message with image metadata
      _sendMessage(
        source == ImageSource.camera ? '📷 Foto aufgenommen' : '🖼️ Bild aus Galerie',
        fileMetadata: {
          'attachment_type': 'image',
          'image_path': path,
          'image_bytes_base64': base64Encode(bytes),
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Fehler: $e', style: const TextStyle(fontSize: 13)),
          duration: const Duration(seconds: 2),
          backgroundColor: AppColors.error.withValues(alpha: 0.9),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: const EdgeInsets.all(16),
        ));
      }
    }
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.buddy;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: c.elev,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 16),
              Text(
                label,
                style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w500),
              ),
            ],
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
    // Kleine Bubble links — wie eine eingehende Nachricht, statt einer
    // breiten Status-Box über die volle Breite.
    final c = context.buddy;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        margin: const EdgeInsets.fromLTRB(12, 14, 12, 6),
        decoration: BoxDecoration(
          color: c.aiBubble,
          boxShadow: c.cardShadow,
          border: Border.all(color: c.aiBubbleBorder),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
          ),
        ),
        child: const _AnimatedDots(),
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
    final c = context.buddy;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        margin: const EdgeInsets.fromLTRB(12, 14, 12, 6),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        // Gleiche Optik wie eine fertige KI-Bubble — kein Stilbruch
        // zwischen Streaming und finaler Nachricht.
        decoration: BoxDecoration(
          color: c.aiBubble,
          boxShadow: c.cardShadow,
          border: Border.all(color: c.aiBubbleBorder),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
          ),
        ),
        // Kein extra "Schreibt"-Label — der Status steht bereits im Header.
        child: Text(
          text,
          style: TextStyle(
            color: c.t1,
            fontSize: 15,
            height: 1.4,
          ),
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
          LiveVoiceState.idle => context.buddy.t3,
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
            color: gradient == null ? context.buddy.elev.withValues(alpha: 0.5) : null,
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
                          color: context.buddy.t2.withValues(alpha: 0.8)),
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
