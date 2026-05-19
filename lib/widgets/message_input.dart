import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/stt_service.dart';
import '../services/live_voice_service.dart';
import '../models/chat_message.dart';
import '../core/theme/app_colors.dart';

/// Minimaler Glas-Look Message-Input.
/// Eine einzelne lange, abgerundete Eingabeleiste.
/// Keine extra Container darum — direkt über dem normalen Hintergrund.
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
    return Container(
      // Kein extra Container der um die Eingabeleiste herum liegt — direkt die Leiste
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            // Glas-Look: leicht durchscheinend, mit feinem Rand
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Colors.white.withOpacity(0.12),
                width: 0.5,
              ),
            ),
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Plus-Button — links INNERHALB der Eingabeleiste
                Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
                  child: InkWell(
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Datei-Upload kommt bald')),
                    ),
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.add,
                        color: AppColors.textTertiary.withOpacity(0.7),
                        size: 22,
                      ),
                    ),
                  ),
                ),
                // Textfeld — nimmt den Rest
                Expanded(
                  child: TextField(
                    controller: _controller,
                    enabled: !widget.isSending,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      height: 1.35,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Schreibe...',
                      hintStyle: TextStyle(
                        color: AppColors.textTertiary.withOpacity(0.5),
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
                // Rechte Seite: Send-Button ODER Mic-Button
                _hasText
                    ? _SendButton(onTap: _submit)
                    : _MicButton(
                        isListening: _isListening,
                        onTap: _isListening ? null : _startListening,
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLiveModeInput() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Colors.white.withOpacity(0.12),
                width: 0.5,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _PulsingDot(color: AppColors.success),
                const SizedBox(width: 8),
                Text(
                  'LIVE',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.success,
                    letterSpacing: 1.2,
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
                Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
                  child: InkWell(
                    onTap: widget.onToggleLiveMode ?? () {},
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.stop_circle_outlined,
                        color: AppColors.error.withOpacity(0.8),
                        size: 24,
                      ),
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

/// Dezenter Send-Button ohne Gradient, ohne Glow.
class _SendButton extends StatelessWidget {
  final VoidCallback onTap;
  const _SendButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary.withOpacity(0.85),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          child: const Icon(
            Icons.arrow_upward_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }
}

/// Dezenter Mic-Button.
class _MicButton extends StatelessWidget {
  final bool isListening;
  final VoidCallback? onTap;
  const _MicButton({this.isListening = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          child: Icon(
            isListening ? Icons.mic : Icons.mic_none,
            color: isListening
                ? AppColors.error.withOpacity(0.8)
                : AppColors.textTertiary.withOpacity(0.7),
            size: 22,
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
                color: widget.color.withOpacity(0.2 * (1 - _ctrl.value)),
                blurRadius: 6,
                spreadRadius: 1,
              ),
            ],
          ),
        );
      },
    );
  }
}
