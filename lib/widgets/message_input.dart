import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/stt_service.dart';
import '../services/live_voice_service.dart';
import '../services/persona_service.dart';
import '../models/chat_message.dart';
import '../core/theme/app_colors.dart';

/// Modernes Message-Input mit Glas-Effekt, Gradient-Send-Button und animierten Icons.
class MessageInput extends StatefulWidget {
  final void Function(String text) onSend;
  final void Function(String text, {MessageType type})? onSendWithType;
  final bool isLiveModeActive;
  final VoidCallback? onToggleLiveMode;
  final LiveVoiceState liveVoiceState;
  final bool isSending;

  const MessageInput({
    super.key,
    required this.onSend,
    this.onSendWithType,
    this.isLiveModeActive = false,
    this.onToggleLiveMode,
    this.liveVoiceState = LiveVoiceState.idle,
    this.isSending = false,
  });

  @override
  State<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput> {
  final _controller = TextEditingController();
  bool _isListening = false;
  final SttService _stt = SttService();
  bool _sttInitialized = false;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _initStt();
    _controller.addListener(() {
      final has = _controller.text.isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  Future<void> _initStt() async {
    _sttInitialized = await _stt.init();
  }

  Future<void> _startListening() async {
    if (!_sttInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Spracherkennung nicht verfügbar')),
      );
      return;
    }
    setState(() => _isListening = true);
    try {
      final result = await _stt.listenonce();
      if (result != null && result.trim().isNotEmpty) {
        _controller.text = result;
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Spracherkennung fehlgeschlagen')),
        );
      }
    } finally {
      if (mounted) setState(() => _isListening = false);
    }
  }

  void _submit() {
    if (widget.isSending) return;
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    // Slash commands with pre-processing
    if (text == '/briefing') {
      _controller.clear();
      widget.onSend('Gib mir ein kurzes Briefing: Welche Termine habe ich heute im Kalender? Gibt es offene Erinnerungen? Was steht heute an?');
      return;
    }
    if (text == '/erinnere') {
      _controller.clear();
      widget.onSend('Durchsuche meine gespeicherten Erinnerungen und sag mir, woran ich heute denken sollte.');
      return;
    }
    if (text == '/hilfe') {
      _controller.clear();
      widget.onSend('Was kannst du alles für mich tun? Welche Tools und Features hast du?');
      return;
    }

    _controller.clear();
    widget.onSend(text);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgDark.withOpacity(0.9),
        border: Border(
          top: BorderSide(color: AppColors.glassBorder.withOpacity(0.5)),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: widget.isLiveModeActive ? _buildLiveModeInput() : _buildNormalInput(),
        ),
      ),
    );
  }

  Widget _buildNormalInput() {
    final personaName = context.watch<PersonaService>().name;
    final isLive = widget.isLiveModeActive;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _ActionButton(
          icon: Icons.add_circle_outline,
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Datei-Upload kommt bald')),
          ),
          tooltip: 'Datei anhängen',
        ),
        const SizedBox(width: 6),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                constraints: const BoxConstraints(maxHeight: 120),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.08),
                  ),
                ),
                child: TextField(
                  controller: _controller,
                  enabled: !widget.isSending,
                  style: TextStyle(color: Colors.white, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: isLive ? 'Schreibe...' : 'Schreibe $personaName...',
                    hintStyle: TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 15,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    suffixIcon: _hasText
                        ? null
                        : IconButton(
                            icon: Icon(
                              _isListening ? Icons.mic : Icons.mic_none,
                              color: _isListening
                                  ? AppColors.error
                                  : AppColors.textTertiary,
                              size: 22,
                            ),
                            onPressed: _isListening ? null : _startListening,
                            tooltip: 'Diktieren',
                          ),
                  ),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _submit(),
                  maxLines: 4,
                  minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        AnimatedSwitcher(
          duration: AppColors.animNormal,
          child: _hasText
              ? _GradientSendButton(onSend: _submit)
              : _ActionButton(
                  icon: widget.isLiveModeActive
                      ? Icons.stop_circle_outlined
                      : Icons.headset_mic_outlined,
                  onTap: widget.onToggleLiveMode ?? () {},
                  tooltip: 'Live-Sprachmodus',
                  activeColor: widget.isLiveModeActive ? AppColors.error : AppColors.primary,
                ),
        ),
      ],
    );
  }

  Widget _buildLiveModeInput() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.success.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.success.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PulsingDot(color: AppColors.success),
              const SizedBox(width: 6),
              Text(
                'LIVE',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.success,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Sprachmodus aktiv — sprich einfach',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
        _ActionButton(
          icon: Icons.stop_circle_outlined,
          onTap: widget.onToggleLiveMode ?? () {},
          tooltip: 'Live-Modus beenden',
          activeColor: AppColors.error,
          size: 28,
        ),
      ],
    );
  }
}

/// Send-Button mit Gradient und Glow.
class _GradientSendButton extends StatelessWidget {
  final VoidCallback onSend;
  const _GradientSendButton({required this.onSend});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSend,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
              spreadRadius: -2,
            ),
          ],
        ),
        child: const Icon(
          Icons.arrow_upward,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }
}

/// Runder Action-Button (Mic, Add, etc.).
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final Color? activeColor;
  final double size;

  const _ActionButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.activeColor,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(
              icon,
              color: activeColor ?? AppColors.textTertiary,
              size: size,
            ),
          ),
        ),
      ),
    );
  }
}

/// Pulsierender grüner Punkt für LIVE-Indikator.
class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: widget.color.withOpacity(0.5 + _ctrl.value * 0.5),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(0.3 * (1 - _ctrl.value)),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
        );
      },
    );
  }
}
