import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/chat_message.dart';
import '../services/tts_playback_service.dart';
import '../core/theme/app_colors.dart';
import 'package:provider/provider.dart';

/// Telegram-style Nachrichten-Bubbles.
/// - User: rechts, abgerundet, dezenter Blau-Gradient
/// - KI: links, abgerundet, dunkle Fläche
/// - Keine Avatars, keine Icons auf Bubbles
/// - Harte untere Kante bei KI (Telegram-Stil: nur eine Seite "schweift")
class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final Animation<double>? animation;

  const MessageBubble({super.key, required this.message, this.animation});

  @override
  Widget build(BuildContext context) {
    Widget content = switch (message.type) {
      MessageType.text => message.isUser ? _userBubble(context) : _aiBubble(context),
      MessageType.system => _systemBubble(),
      MessageType.toolActivity => _toolActivity(context),
      MessageType.error => _errorBubble(context),
      MessageType.voice => message.isUser ? _userBubble(context) : _aiBubble(context),
    };

    if (animation != null) {
      content = SlideTransition(
        position: Tween(begin: const Offset(0, 0.15), end: Offset.zero).animate(
          CurvedAnimation(parent: animation!, curve: Curves.easeOutCubic),
        ),
        child: FadeTransition(
          opacity: animation!,
          child: content,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 2),
      child: content,
    );
  }

  void _showCopyMenu(BuildContext context, Offset position) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => _CopyMenuOverlay(
        position: position,
        onCopySelection: () {
          entry.remove();
          Clipboard.setData(ClipboardData(text: message.text));
          HapticFeedback.mediumImpact();
          _showCopiedSnackBar(context);
        },
        onDismiss: () => entry.remove(),
      ),
    );

    overlay.insert(entry);
  }

  void _showCopiedSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('Kopiert', style: TextStyle(fontSize: 13)),
      duration: const Duration(seconds: 1),
      backgroundColor: AppColors.bgElevated,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
    ));
  }

  // ── User Bubble (rechts, wie Telegram eigene Nachricht) ──
  Widget _userBubble(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (details) => _showCopyMenu(context, details.globalPosition),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              margin: const EdgeInsets.only(left: 64),
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              decoration: BoxDecoration(
                gradient: AppColors.userBubble,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(4), // Harte untere linke Ecke
                ),
              ),
              child: SelectableText(
                message.text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  height: 1.4,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── AI Bubble (links, wie Telegram Fremdnachricht) ──
  Widget _aiBubble(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (details) => _showCopyMenu(context, details.globalPosition),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              margin: const EdgeInsets.only(right: 64),
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              decoration: BoxDecoration(
                gradient: AppColors.assistantBubbleBg,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                  bottomLeft: Radius.circular(4), // Harte untere rechte Ecke
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    message.text,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      height: 1.4,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _TtsPlayButton(message: message),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _systemBubble() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }

  Widget _toolActivity(BuildContext context) {
    final bool isComplete = message.text.contains('✅') || 
                           message.text.contains('gesetzt') || 
                           message.text.contains('erledigt') ||
                           !message.text.contains('wird ausgefuehrt');
    
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primary.withOpacity(0.15)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isComplete ? Icons.check_circle_outline_rounded : Icons.pending_outlined,
              size: 14,
              color: AppColors.primary.withOpacity(0.7),
            ),
            const SizedBox(width: 8),
            Text(
              message.text,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorBubble(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.error.withOpacity(0.15)),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: AppColors.error.withOpacity(0.8),
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

// ── TTS Play Button (dezent, in der Bubble) ──
class _TtsPlayButton extends StatefulWidget {
  final ChatMessage message;
  const _TtsPlayButton({required this.message});

  @override
  State<_TtsPlayButton> createState() => _TtsPlayButtonState();
}

class _TtsPlayButtonState extends State<_TtsPlayButton> {
  bool _isPlaying = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        if (_isPlaying) return;
        setState(() => _isPlaying = true);
        final tts = context.read<TtsPlaybackService>();
        await tts.speak(widget.message.text);
        if (mounted) setState(() => _isPlaying = false);
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _isPlaying ? Icons.volume_up : Icons.volume_up_outlined,
            size: 14,
            color: AppColors.textTertiary,
          ),
          const SizedBox(width: 4),
          Text(
            'Vorlesen',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textTertiary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Copy Menu Overlay ──
class _CopyMenuOverlay extends StatelessWidget {
  final Offset position;
  final VoidCallback onCopySelection;
  final VoidCallback onDismiss;

  const _CopyMenuOverlay({
    required this.position,
    required this.onCopySelection,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onDismiss,
      child: Container(
        color: Colors.transparent,
        child: Stack(
          children: [
            Positioned(
              left: position.dx - 60,
              top: position.dy - 50,
              child: Material(
                color: AppColors.bgElevated,
                borderRadius: BorderRadius.circular(12),
                elevation: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _MenuItem(
                        icon: Icons.copy,
                        label: 'Kopieren',
                        onTap: onCopySelection,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MenuItem({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: AppColors.textPrimary),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }
}
