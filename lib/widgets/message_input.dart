import 'package:flutter/material.dart';
import '../services/live_voice_service.dart';
import '../core/theme/app_colors.dart';

/// Messaging Input Bar — Live-Voice-first Design.
/// - Links: Menü-Button
/// - Mitte: Textfeld
/// - Rechts: Live-Voice-Button (Mic = Live starten/stoppen)
class MessageInput extends StatefulWidget {
  final void Function(String text) onSend;
  final bool isLiveModeActive;
  final VoidCallback? onToggleLiveMode;
  final LiveVoiceState liveVoiceState;
  final bool isSending;

  const MessageInput({
    super.key,
    required this.onSend,
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
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final has = _controller.text.isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
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

  /// Live-Voice button color based on state.
  Color _liveButtonColor() {
    switch (widget.liveVoiceState) {
      case LiveVoiceState.listening:
        return AppColors.success;
      case LiveVoiceState.thinking:
        return AppColors.secondary;
      case LiveVoiceState.speaking:
        return AppColors.primary;
      case LiveVoiceState.error:
        return AppColors.error;
      case LiveVoiceState.idle:
        return const Color(0xFF6B8DD6); // Periwinkle
    }
  }

  IconData _liveButtonIcon() {
    if (!widget.isLiveModeActive) {
      return Icons.mic_rounded;
    }
    switch (widget.liveVoiceState) {
      case LiveVoiceState.listening:
        return Icons.hearing_rounded;
      case LiveVoiceState.thinking:
        return Icons.psychology_rounded;
      case LiveVoiceState.speaking:
        return Icons.volume_up_rounded;
      case LiveVoiceState.error:
        return Icons.error_outline_rounded;
      case LiveVoiceState.idle:
        return Icons.mic_rounded;
    }
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
        color: const Color(0xFF24242A),
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Links: Menü
          _CircleButton(
            icon: Icons.menu_rounded,
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Menü kommt bald')),
            ),
          ),
          const SizedBox(width: 8),
          // Textfeld
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: TextField(
                controller: _controller,
                enabled: !widget.isSending && !widget.isLiveModeActive,
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
                onSubmitted: (_) => _submit(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Rechts: Senden oder Live-Voice starten
          _hasText
              ? _CircleButton(
                  icon: Icons.arrow_upward_rounded,
                  onTap: _submit,
                )
              : _CircleButton(
                  icon: _liveButtonIcon(),
                  onTap: widget.onToggleLiveMode ?? () {},
                  color: _liveButtonColor(),
                  size: _isPulsing() ? 44 : 40,
                  glow: !widget.isLiveModeActive, // subtle glow hint
                ),
        ],
      ),
    );
  }

  bool _isPulsing() => false; // Could animate later

  Widget _buildLiveModeInput() {
    final state = widget.liveVoiceState;
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

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF24242A),
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Pulsierender Punkt
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              color: stateColor,
              shape: BoxShape.circle,
              boxShadow: state != LiveVoiceState.idle
                  ? [BoxShadow(color: stateColor.withValues(alpha: 0.5), blurRadius: 6)]
                  : null,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            stateLabel,
            style: TextStyle(
              fontSize: 13,
              color: stateColor,
              fontWeight: state != LiveVoiceState.idle ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          const Spacer(),
          // Stop-Button
          _CircleButton(
            icon: Icons.stop_circle_outlined,
            onTap: widget.onToggleLiveMode ?? () {},
            color: AppColors.error,
          ),
        ],
      ),
    );
  }
}

/// Kreis-Button (Periwinkle-Blau oder custom Farbe).
class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color? color;
  final double size;
  final bool glow;

  const _CircleButton({
    required this.icon,
    this.onTap,
    this.color,
    this.size = 40,
    this.glow = false,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = color ?? const Color(0xFF6B8DD6).withValues(alpha: 0.9);

    return Material(
      color: bgColor,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: glow ? BoxDecoration(
            shape: BoxShape.circle,
            color: bgColor,
            boxShadow: [
              BoxShadow(
                color: bgColor.withValues(alpha: 0.3),
                blurRadius: 8,
              ),
            ],
          ) : null,
          child: Icon(
            icon,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }
}