import 'package:flutter/material.dart';
import '../../core/theme/buddy_colors.dart';

/// Collapsible settings section header rendered as a tappable card with a
/// coloured icon chip — same visual language as the entries inside each
/// section, so the whole settings screen reads as one consistent list of
/// buttons.
class SectionHeader extends StatelessWidget {
  final String text;
  final IconData icon;
  final bool expanded;
  final VoidCallback onTap;

  const SectionHeader(
    this.text, {
    super.key,
    required this.icon,
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.buddy;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: c.card.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border),
        boxShadow: c.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: c.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: c.accent, size: 21),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      color: c.t1,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: c.t2,
                    size: 24,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
