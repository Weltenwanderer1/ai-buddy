import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/buddy_colors.dart';

/// Polierter Typing-Indicator mit Glass-Effekt und sanften Pulser.
class TypingIndicator extends StatefulWidget {
  final String label;
  final Color? dotColor;
  final double dotRadius;

  const TypingIndicator({
    super.key,
    this.label = 'KI denkt nach',
    this.dotColor,
    this.dotRadius = 4,
  });

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.dotColor ?? AppColors.primary;

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: context.buddy.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.buddy.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: context.buddy.t2,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: widget.dotRadius * 0.6),
                  child: _PulsatingDot(
                    controller: _controller,
                    index: i,
                    color: color,
                    radius: widget.dotRadius,
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _PulsatingDot extends StatelessWidget {
  final AnimationController controller;
  final int index;
  final Color color;
  final double radius;

  static const double _bounceSpan = 0.4;

  const _PulsatingDot({
    required this.controller,
    required this.index,
    required this.color,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    final begin = index * 0.2;
    final end = begin + _bounceSpan;

    final scaleAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(
        parent: controller,
        curve: Interval(begin, end, curve: Curves.easeInOut),
      ),
    );

    final shrinkAnimation = Tween<double>(begin: 1.0, end: 0.4).animate(
      CurvedAnimation(
        parent: controller,
        curve: Interval(end, (end + 0.2).clamp(0.0, 1.0), curve: Curves.easeInOut),
      ),
    );

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        double scale;
        final v = controller.value;
        if (v >= begin && v < end) {
          scale = scaleAnimation.value;
        } else if (v >= end && v < end + 0.2) {
          scale = shrinkAnimation.value;
        } else {
          scale = 0.4;
        }
        return Transform.scale(scale: scale, child: child);
      },
      child: Container(
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
