import 'package:flutter/material.dart';
import '../services/stt_service.dart';
import '../services/live_voice_service.dart';
import '../models/chat_message.dart';
import '../core/theme/app_colors.dart';

/// Messaging Input Bar — Referenz-Screenshot Design.
/// Eine einzelne dunkle Pille mit:
/// - Links: blauer Kreis mit Hamburger-Menü
/// - Dann: Smiley-Icon (outline)
/// - Mitte: Textfeld mit "Nachricht" Placeholder
/// - Dann: Paperclip (outline)
/// - Rechts: blauer Kreis mit Mic (oder weißer Send-Pfeil wenn Text da)
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
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF24242A), // Leicht heller als vorher
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Links: blauer Kreis mit Hamburger-Menü
          _BlueCircleButton(
            icon: Icons.menu_rounded,
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Menü kommt bald')),
            ),
          ),
          const SizedBox(width: 8),
          // Textfeld — breiter, mehr Padding links/rechts
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: TextField(
                controller: _controller,
                enabled: !widget.isSending,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  height: 1.35,
                ),
                decoration: InputDecoration(
                  hintText: 'Nachricht',
                  hintStyle: TextStyle(
                    color: AppColors.textTertiary.withValues(alpha: 0.6),
                    fontSize: 15,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.fromLTRB(0, 10, 0, 10),
                  isDense: true,
                  isCollapsed: true,
                ),
                textInputAction: TextInputAction.newline,
                maxLines: 6,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Rechts: blauer Kreis mit Mic oder Send-Pfeil
          _hasText
              ? _BlueCircleButton(
                  icon: Icons.arrow_upward_rounded,
                  onTap: _submit,
                )
              : _BlueCircleButton(
                  icon: _isListening ? Icons.mic : Icons.mic_none,
                  onTap: _isListening ? null : _startListening,
                  color: _isListening ? AppColors.error : null,
                ),
        ],
      ),
    );
  }

  Widget _buildLiveModeInput() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF24242A), // Leicht heller als vorher
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
            ),
          ),
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
          _BlueCircleButton(
            icon: Icons.stop_circle_outlined,
            onTap: widget.onToggleLiveMode ?? () {},
            color: AppColors.error,
          ),
        ],
      ),
    );
  }
}

/// Blauer Kreis-Button (wie im Screenshot: periwinkle/lavender).
/// Für Menü (links) und Mic/Send (rechts).
class _BlueCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color? color;

  const _BlueCircleButton({required this.icon, this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF6B8DD6).withValues(alpha: 0.9), // Periwinkle blau
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          child: Icon(
            icon,
            color: color ?? Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }
}

