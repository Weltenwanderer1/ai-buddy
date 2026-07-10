import 'package:flutter/material.dart';
import '../../core/theme/buddy_colors.dart';
import '../../core/theme/app_colors.dart';

class GradientButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const GradientButton({super.key, required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final foreground = AppColors.foregroundFor(context.buddy.accent);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(0, 8, 0, 16),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: context.buddy.accent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: onTap != null ? [
            BoxShadow(
              color: context.buddy.accent.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ] : null,
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 18, color: foreground),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: foreground)),
        ]),
      ),
    );
  }
}
