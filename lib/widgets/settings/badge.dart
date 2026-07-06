import 'package:flutter/material.dart';
import '../../core/theme/buddy_colors.dart';

class SettingsBadge extends StatelessWidget {
  final String text;

  const SettingsBadge(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: context.buddy.accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text, style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: context.buddy.accent,
      )),
    );
  }
}
