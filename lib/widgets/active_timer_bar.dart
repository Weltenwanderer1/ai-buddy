import 'dart:async';
import 'package:flutter/material.dart';
import '../services/timer_service.dart';
import '../core/theme/app_colors.dart';

/// Shows active timers as a floating bar above the input field.
/// Each timer: name + live countdown + tap to cancel.
class ActiveTimerBar extends StatefulWidget {
  final List<TimerEntry> timers;
  final void Function(String timerId)? onCancel;

  const ActiveTimerBar({
    super.key,
    required this.timers,
    this.onCancel,
  });

  @override
  State<ActiveTimerBar> createState() => _ActiveTimerBarState();
}

class _ActiveTimerBarState extends State<ActiveTimerBar> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.timers.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        alignment: WrapAlignment.center,
        children: widget.timers.map((t) => _TimerChip(
          timer: t,
          onCancel: widget.onCancel != null
              ? () => widget.onCancel!(t.id)
              : null,
        )).toList(),
      ),
    );
  }
}

class _TimerChip extends StatelessWidget {
  final TimerEntry timer;
  final VoidCallback? onCancel;

  const _TimerChip({required this.timer, this.onCancel});

  @override
  Widget build(BuildContext context) {
    final remaining = timer.remainingSeconds;
    final mins = remaining ~/ 60;
    final secs = remaining % 60;
    final urgent = remaining < 60;

    final timeText = mins > 0
        ? '$mins:${secs.toString().padLeft(2, '0')}'
        : '${secs}s';

    final color = urgent ? AppColors.error : AppColors.primary;

    return GestureDetector(
      onTap: onCancel,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timer, size: 14, color: color.withValues(alpha: 0.8)),
            const SizedBox(width: 5),
            Text(
              '${timer.label}: $timeText',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color.withValues(alpha: 0.9),
              ),
            ),
            if (onCancel != null) ...[
              const SizedBox(width: 6),
              Icon(Icons.close, size: 13, color: color.withValues(alpha: 0.5)),
            ],
          ],
        ),
      ),
    );
  }
}
