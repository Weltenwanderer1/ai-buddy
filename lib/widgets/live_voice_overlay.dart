import 'dart:math';
import 'package:flutter/material.dart';
import '../core/i18n/app_localizations.dart';
import '../core/theme/buddy_colors.dart';
import '../services/live_voice_service.dart';

/// Immersive full-screen live-voice experience: a breathing orb visualizer
/// that reacts to the assistant's state (listening / thinking / speaking),
/// the live transcript, an audio-route toggle and a single clear stop button.
///
/// Replaces the old thin status bar. Fully theme-aware (light & dark) so it
/// matches the rest of the app.
class LiveVoiceOverlay extends StatefulWidget {
  final LiveVoiceService liveVoice;
  final String buddyName;
  final bool useEarpiece;
  final VoidCallback onStop;
  final VoidCallback? onToggleEarpiece;

  const LiveVoiceOverlay({
    super.key,
    required this.liveVoice,
    required this.buddyName,
    required this.useEarpiece,
    required this.onStop,
    this.onToggleEarpiece,
  });

  @override
  State<LiveVoiceOverlay> createState() => _LiveVoiceOverlayState();
}

class _LiveVoiceOverlayState extends State<LiveVoiceOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _pulse; // continuous ring pulse
  late final AnimationController _spin; // rotation for the thinking state

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat();
  }

  @override
  void dispose() {
    _pulse.dispose();
    _spin.dispose();
    super.dispose();
  }

  Color _stateColor(BuildContext context, LiveVoiceState s) {
    final c = context.buddy;
    return switch (s) {
      LiveVoiceState.idle => c.accent,
      LiveVoiceState.listening => c.success,
      LiveVoiceState.thinking => const Color(0xFF64D2FF),
      LiveVoiceState.speaking => c.accent,
      LiveVoiceState.error => c.error,
    };
  }

  String _label(AppLocalizations t, LiveVoiceState s) => switch (s) {
        LiveVoiceState.idle => t.chat_voice_ready,
        LiveVoiceState.listening => t.chat_voice_listening,
        LiveVoiceState.thinking => t.chat_voice_thinking,
        LiveVoiceState.speaking => t.chat_voice_speaking,
        LiveVoiceState.error => t.chat_voice_error,
      };

  IconData _icon(LiveVoiceState s) => switch (s) {
        LiveVoiceState.idle => Icons.graphic_eq_rounded,
        LiveVoiceState.listening => Icons.mic_rounded,
        LiveVoiceState.thinking => Icons.auto_awesome_rounded,
        LiveVoiceState.speaking => Icons.volume_up_rounded,
        LiveVoiceState.error => Icons.error_outline_rounded,
      };

  /// How lively the rings are per state (0..1).
  double _energy(LiveVoiceState s) => switch (s) {
        LiveVoiceState.idle => 0.25,
        LiveVoiceState.listening => 1.0,
        LiveVoiceState.thinking => 0.5,
        LiveVoiceState.speaking => 0.85,
        LiveVoiceState.error => 0.2,
      };

  @override
  Widget build(BuildContext context) {
    final c = context.buddy;
    final t = AppLocalizations.of(context);

    return ListenableBuilder(
      listenable: widget.liveVoice,
      builder: (context, _) {
        final state = widget.liveVoice.state;
        final color = _stateColor(context, state);
        final transcript = widget.liveVoice.lastTranscript;

        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.35),
              radius: 1.1,
              colors: [
                Color.alphaBlend(color.withValues(alpha: 0.14), c.bg),
                c.bg,
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // ── Top row: name + state ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 8),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.buddyName.isEmpty ? 'Buddy' : widget.buddyName,
                          style: TextStyle(
                            color: c.t1,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        t.chat_voice_live_badge,
                        style: TextStyle(
                          color: c.t3,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Orb ──
                Expanded(
                  child: Center(
                    child: _Orb(
                      pulse: _pulse,
                      spin: _spin,
                      color: color,
                      energy: _energy(state),
                      rotating: state == LiveVoiceState.thinking,
                      icon: _icon(state),
                    ),
                  ),
                ),

                // ── State label + transcript ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    children: [
                      Text(
                        _label(t, state),
                        style: TextStyle(
                          color: color,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 12),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: (transcript != null && transcript.isNotEmpty)
                            ? Text(
                                '“$transcript”',
                                key: ValueKey(transcript),
                                textAlign: TextAlign.center,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: c.t2,
                                  fontSize: 15,
                                  height: 1.4,
                                  fontStyle: FontStyle.italic,
                                ),
                              )
                            : Text(
                                t.chat_voice_hint,
                                key: const ValueKey('hint'),
                                textAlign: TextAlign.center,
                                style: TextStyle(color: c.t3, fontSize: 14, height: 1.4),
                              ),
                      ),
                    ],
                  ),
                ),

                // ── Controls ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 36, 24, 32),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.onToggleEarpiece != null) ...[
                        _RoundControl(
                          icon: widget.useEarpiece
                              ? Icons.hearing_rounded
                              : Icons.volume_up_rounded,
                          background: c.card.withValues(alpha: 0.7),
                          border: c.border,
                          iconColor: widget.useEarpiece ? c.accent : c.t2,
                          size: 58,
                          onTap: widget.onToggleEarpiece!,
                        ),
                        const SizedBox(width: 28),
                      ],
                      // Stop — the primary action
                      _RoundControl(
                        icon: Icons.stop_rounded,
                        background: c.error,
                        border: Colors.transparent,
                        iconColor: Colors.white,
                        size: 76,
                        onTap: widget.onStop,
                      ),
                      if (widget.onToggleEarpiece != null)
                        const SizedBox(width: 28 + 58),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Layered breathing orb: expanding rings + a glowing gradient core.
class _Orb extends StatelessWidget {
  final AnimationController pulse;
  final AnimationController spin;
  final Color color;
  final double energy;
  final bool rotating;
  final IconData icon;

  const _Orb({
    required this.pulse,
    required this.spin,
    required this.color,
    required this.energy,
    required this.rotating,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    const coreSize = 150.0;
    return SizedBox(
      width: 300,
      height: 300,
      child: AnimatedBuilder(
        animation: pulse,
        builder: (context, _) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // Expanding rings (read pulse.value every frame)
              for (int i = 0; i < 3; i++)
                _ring(i, coreSize),
              // Core also breathes on pulse.value, so build it here too.
              _core(coreSize),
            ],
          );
        },
      ),
    );
  }

  Widget _ring(int i, double coreSize) {
    final phase = (pulse.value + i / 3) % 1.0;
    final scale = 1.0 + phase * (0.5 + energy * 0.7);
    final opacity = (1.0 - phase) * (0.10 + energy * 0.30);
    return Transform.scale(
      scale: scale,
      child: Container(
        width: coreSize,
        height: coreSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: opacity * 0.5),
          border: Border.all(color: color.withValues(alpha: opacity)),
        ),
      ),
    );
  }

  Widget _core(double coreSize) {
    // Gentle breathing on the core itself.
    final breathe = 1.0 + sin(pulse.value * pi * 2) * 0.03 * (0.4 + energy);
    final coreChild = Container(
      width: coreSize,
      height: coreSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            Color.alphaBlend(Colors.white.withValues(alpha: 0.25), color),
            color,
            color.withValues(alpha: 0.85),
          ],
          stops: const [0.0, 0.6, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.45),
            blurRadius: 40,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 52),
    );

    return Transform.scale(
      scale: breathe,
      child: rotating
          ? RotationTransition(turns: spin, child: _sweep(coreSize, coreChild))
          : coreChild,
    );
  }

  /// Rotating highlight sweep used during the "thinking" state.
  Widget _sweep(double coreSize, Widget child) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: coreSize + 14,
          height: coreSize + 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: SweepGradient(
              colors: [
                color.withValues(alpha: 0.0),
                color.withValues(alpha: 0.7),
                color.withValues(alpha: 0.0),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _RoundControl extends StatelessWidget {
  final IconData icon;
  final Color background;
  final Color border;
  final Color iconColor;
  final double size;
  final VoidCallback onTap;

  const _RoundControl({
    required this.icon,
    required this.background,
    required this.border,
    required this.iconColor,
    required this.size,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: background,
            shape: BoxShape.circle,
            border: Border.all(color: border),
            boxShadow: [
              BoxShadow(
                color: background.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, color: iconColor, size: size * 0.42),
        ),
      ),
    );
  }
}
