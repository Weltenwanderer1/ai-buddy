import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/stt_service.dart';
import '../services/live_voice_service.dart';
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
    return SafeArea(
      child: widget.isLiveModeActive ? _buildLiveModeInput() : _buildNormalInput(),
    );
  }

  Widget _buildNormalInput() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Plus-Button links, im Feld
              IconButton(
                icon: Icon(Icons.add_circle_outline, color: AppColors.textTertiary, size: 22),
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Datei-Upload kommt bald')),
                ),
                tooltip: 'Datei anhängen',
                padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
              Expanded(
                child: TextField(
                  controller: _controller,
                  enabled: !widget.isSending,
                  style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.3),
                  decoration: InputDecoration(
                    hintText: 'Schreibe...',
                    hintStyle: TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 15,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.fromLTRB(0, 12, 0, 12),
                    isDense: true,
                  ),
                  textInputAction: TextInputAction.newline,
                  maxLines: 6,
                  minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                ),
              ),
              // Send-Button oder Mic-Button rechts, im Feld
              _hasText
                  ? Container(
                      width: 36,
                      height: 36,
                      margin: const EdgeInsets.fromLTRB(4, 8, 10, 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(18),
                        child: InkWell(
                          onTap: _submit,
                          borderRadius: BorderRadius.circular(18),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [AppColors.primary, Color(0xFFD946EF)],
                              ),
                            ),
                            child: const Icon(
                              Icons.send_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    )
                  : IconButton(
                      icon: Icon(
                        _isListening ? Icons.mic : Icons.mic_none,
                        color: _isListening ? AppColors.error : AppColors.textTertiary,
                        size: 22,
                      ),
                      onPressed: _isListening ? null : _startListening,
                      tooltip: 'Diktieren',
                      padding: const EdgeInsets.fromLTRB(4, 10, 12, 10),
                      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                    ),
            ],
          ),
        ),
      ),
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
