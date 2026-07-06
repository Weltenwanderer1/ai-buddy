import 'package:flutter/material.dart';
import '../core/i18n/app_localizations.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import '../services/live_voice_service.dart';
import '../services/stt_service.dart';
import '../services/settings_service.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/buddy_colors.dart';

/// Messaging Input Bar — Live-Voice + Dictation + Send.
/// - Links: Menü-Button
/// - Mitte: Textfeld
/// - Rechts daneben: Diktier-Button (Mic → Text ins Feld)
/// - Ganz rechts: Live-Sprech-Modus (AI-Sterne) ODER Senden-Button
class MessageInput extends StatefulWidget {
  final void Function(String text) onSend;
  final VoidCallback? onMenuTap;
  final bool isLiveModeActive;
  final VoidCallback? onToggleLiveMode;
  final LiveVoiceState liveVoiceState;
  final bool isSending;
  final SttService? sttService;
  final bool useEarpiece;
  final VoidCallback? onToggleEarpiece;

  const MessageInput({
    super.key,
    required this.onSend,
    this.onMenuTap,
    this.isLiveModeActive = false,
    this.onToggleLiveMode,
    this.liveVoiceState = LiveVoiceState.idle,
    this.isSending = false,
    this.sttService,
    this.useEarpiece = false,
    this.onToggleEarpiece,
  });

  @override
  State<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput> {
  final _controller = TextEditingController();
  late AppLocalizations t;
  bool _hasText = false;
  bool _isDictating = false;

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
      widget.onSend(t.chat_initial_prompt);
      return;
    }

    _controller.clear();
    widget.onSend(text);
  }

  /// Start dictation: STT listens → recognized text goes into text field.
  Future<void> _startDictation() async {
    if (_isDictating) return;
    final stt = widget.sttService;
    if (stt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.stt_not_available)),
      );
      return;
    }
    // App-Sprache VOR dem ersten await lesen (context danach unsicher).
    final locale = SttService.localeFor(context.read<SettingsService>().appLanguage);

    setState(() => _isDictating = true);
    try {
      // Initialize if needed
      if (!stt.isAvailable) {
        final ok = await stt.init();
        if (!ok) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(t.stt_permission_needed)),
            );
          }
          return;
        }
      }

      // Add placeholder while listening
      final currentText = _controller.text;
      final result = await stt.listenonce(localeId: locale);
      // Diktat kann bis zu 120s laufen — Widget kann längst disposed sein,
      // dann wäre der Controller-Zugriff ein Use-after-dispose.
      if (!mounted) return;
      if (result != null && result.isNotEmpty) {
        final separator = currentText.isNotEmpty ? ' ' : '';
        _controller.text = currentText + separator + result;
        // Move cursor to end
        _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
      }
    } finally {
      if (mounted) setState(() => _isDictating = false);
    }
  }

  void _stopDictation() {
    final stt = widget.sttService;
    if (stt == null) return;
    stt.stop();
    setState(() => _isDictating = false);
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

  @override
  Widget build(BuildContext context) {
    t = AppLocalizations.of(context);
    return widget.isLiveModeActive ? _buildLiveModeInput() : _buildNormalInput();
  }

  Widget _buildNormalInput() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: context.buddy.pill.withValues(alpha: 0.60),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: context.buddy.border,
                width: 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Links: Menü-Button (dunkel, eingelassen)
                _CircleButton(
                  icon: Icons.menu_rounded,
                  onTap: widget.onMenuTap ?? () {},
                  color: context.buddy.elev,
                  size: 36,
                  iconSize: 18,
                ),
                const SizedBox(width: 4),
                // Textfeld
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: TextField(
                      controller: _controller,
                      enabled: !widget.isLiveModeActive,
                      style: TextStyle(
                        color: context.buddy.t1,
                        fontSize: 15,
                        height: 1.35,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Nachricht',
                        hintStyle: TextStyle(
                          color: context.buddy.t3,
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
                const SizedBox(width: 4),
                // Rechts: Mikrofon (Diktat) oder Senden bei Text.
                // Während des Diktats bleibt der Stopp-Button sichtbar —
                // sonst gäbe es keine Möglichkeit mehr, das Mikro zu
                // stoppen, sobald Text im Feld steht.
                _hasText && !_isDictating
                    ? _CircleButton(
                        icon: Icons.arrow_upward_rounded,
                        onTap: _submit,
                        size: 36,
                        iconSize: 18,
                      )
                    : _CircleButton(
                        icon: _isDictating ? Icons.hearing_rounded : Icons.mic_rounded,
                        onTap: _isDictating ? _stopDictation : _startDictation,
                        color: _isDictating ? AppColors.success : null, // null → Periwinkle default
                        size: 36,
                        iconSize: 18,
                      ),
                const SizedBox(width: 4),
                // Ganz rechts: Live-Modus Stern (nur wenn kein Text)
                if (!_hasText)
                  _CircleButton(
                    icon: Icons.auto_awesome_rounded,
                    onTap: widget.onToggleLiveMode ?? () {},
                    color: _liveButtonColor(),
                    size: 36,
                    iconSize: 18,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLiveModeInput() {
    final state = widget.liveVoiceState;
    final stateLabel = switch (state) {
      LiveVoiceState.idle => 'Bereit',
      LiveVoiceState.listening => t.chat_voice_listening,
      LiveVoiceState.thinking => 'Denkt nach…',
      LiveVoiceState.speaking => 'Spricht…',
      LiveVoiceState.error => 'Fehler',
    };
    final stateColor = switch (state) {
      LiveVoiceState.idle => context.buddy.t3,
      LiveVoiceState.listening => AppColors.success,
      LiveVoiceState.thinking => AppColors.secondary,
      LiveVoiceState.speaking => AppColors.primary,
      LiveVoiceState.error => AppColors.error,
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
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
          // Audio-Routing Button (Speaker ↔ Earpiece)
          if (widget.onToggleEarpiece != null)
            _CircleButton(
              icon: widget.useEarpiece ? Icons.headset_rounded : Icons.volume_up_rounded,
              onTap: widget.onToggleEarpiece,
              color: widget.useEarpiece ? AppColors.primary : context.buddy.t3.withValues(alpha: 0.5),
              size: 36,
              iconSize: 18,
            ),
          const SizedBox(width: 8),
          // Stop-Button
          _CircleButton(
            icon: Icons.stop_circle_outlined,
            onTap: widget.onToggleLiveMode ?? () {},
            color: AppColors.error,
            size: 36,
            iconSize: 18,
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
  final double iconSize;

  const _CircleButton({
    required this.icon,
    this.onTap,
    this.color,
    this.size = 40,
    this.iconSize = 20,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = color ?? const Color(0xFF6B8DD6).withValues(alpha: 0.9);

    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: bgColor,
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: iconSize,
          ),
        ),
      ),
    );
  }
}