import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/stt_service.dart';
import '../services/live_voice_service.dart';
import '../models/chat_message.dart';
import '../core/theme/app_colors.dart';

/// Telegram-style Message Input.
/// Eine einzelne lange, abgerundete "Pille" mit Glas-Effekt.
/// Keine Container drumherum — direkt über dem normalen Hintergrund.
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
        color: const Color(0xFF1C1C22).withOpacity(0.85),
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Plus-Button (links)
          _IconButton(
            icon: Icons.add,
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Datei-Upload kommt bald')),
            ),
          ),
          // Textfeld mit Abstand zu den Buttons
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
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
                  contentPadding: const EdgeInsets.fromLTRB(4, 10, 4, 10),
                  isDense: true,
                ),
                textInputAction: TextInputAction.newline,
                maxLines: 6,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
              ),
            ),
          ),
          // Rechte Seite mit Abstand
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: _hasText
                ? _SendButton(onTap: _submit)
                : _IconButton(
                    icon: _isListening ? Icons.mic : Icons.mic_none,
                    onTap: _isListening ? null : _startListening,
                    color: _isListening ? AppColors.error : null,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveModeInput() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C22).withOpacity(0.85),
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
          _IconButton(
            icon: Icons.stop_circle_outlined,
            onTap: widget.onToggleLiveMode ?? () {},
            color: AppColors.error,
          ),
        ],
      ),
    );
  }
}

/// Send-Button: dezenter Pfeil auf semitransparentem Primary.
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

/// Icon-Button für Plus und Mic — dezent, ohne Hintergrund.
class _IconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color? color;

  const _IconButton({required this.icon, this.onTap, this.color});

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
            icon,
            color: color ?? AppColors.textTertiary.withOpacity(0.6),
            size: 22,
          ),
        ),
      ),
    );
  }
}
