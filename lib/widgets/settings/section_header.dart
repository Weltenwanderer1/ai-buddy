import 'package:flutter/material.dart';
import '../../core/theme/buddy_colors.dart';

/// Klickbares Abschnitts-Label mit Chevron (klappbar).
class SectionHeader extends StatelessWidget {
  final String text;
  final bool expanded;
  final VoidCallback onTap;

  const SectionHeader(this.text, {super.key, required this.expanded, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 18, 28, 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: context.buddy.t2,
                ),
              ),
            ),
            AnimatedRotation(
              turns: expanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: context.buddy.t2,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
