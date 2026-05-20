import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Glassmorphism-Container für hochwertige moderne Look.
class GlassCard extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final double blur;
  final Color? glassColor;
  final Color? borderColor;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.radius = 20,
    this.blur = 16,
    this.glassColor,
    this.borderColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          width: width,
          height: height,
          padding: padding ?? const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: glassColor ?? AppColors.glassBg,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: borderColor ?? AppColors.glassBorder,
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );
    if (margin != null) content = Padding(padding: margin!, child: content);
    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: content,
        ),
      );
    }
    return content;
  }
}

/// Gradient-Container for emphasis (CTA buttons, badges, highlights).
class GradientContainer extends StatelessWidget {
  final Widget child;
  final Gradient gradient;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final VoidCallback? onTap;

  const GradientContainer({
    super.key,
    required this.child,
    required this.gradient,
    this.padding,
    this.radius = 16,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Container(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGlow,
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: content,
        ),
      );
    }
    return content;
  }
}

/// Animated scale wrapper for press effects.
class ScaleOnTap extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final double scaleDown;

  const ScaleOnTap({super.key, required this.child, required this.onTap, this.scaleDown = 0.95});

  @override
  State<ScaleOnTap> createState() => _ScaleOnTapState();
}

class _ScaleOnTapState extends State<ScaleOnTap>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppColors.animFast,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) async {
        await _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: Tween(begin: 1.0, end: widget.scaleDown).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeOut),
        ),
        child: widget.child,
      ),
    );
  }
}

/// Floating pill-shaped action button with gradient.
class GradientFAB extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String? label;
  final Gradient? gradient;

  const GradientFAB({super.key, required this.icon, required this.onPressed, this.label, this.gradient});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        decoration: BoxDecoration(
          gradient: gradient ?? AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: (gradient?.colors.first ?? AppColors.primary).withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
              spreadRadius: -4,
            ),
          ],
        ),
        child: label != null
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(icon, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(label!, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.white)),
                ]),
              )
            : Padding(
                padding: const EdgeInsets.all(16),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
      ),
    );
  }
}
