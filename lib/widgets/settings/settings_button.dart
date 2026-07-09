import 'package:flutter/material.dart';
import '../../core/theme/buddy_colors.dart';

/// A standalone, tappable settings entry rendered as its own rounded card —
/// same visual language as the "Konfiguration" section's expandable headers
/// (coloured icon chip, title, subtitle, trailing). Used across all settings
/// sections so every entry looks like a consistent button.
class SettingsButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color color;
  final Widget? trailing;
  final VoidCallback onTap;

  const SettingsButton({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.color,
    this.trailing,
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: color, size: 21),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title,
                          style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              color: c.t1)),
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(subtitle!,
                            style: TextStyle(fontSize: 12.5, color: c.t3),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                trailing ??
                    Icon(Icons.chevron_right_rounded,
                        color: c.t3.withValues(alpha: 0.7), size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
