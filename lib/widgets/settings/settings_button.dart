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
  final bool nested;

  const SettingsButton({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.color,
    this.trailing,
    required this.onTap,
    this.nested = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.buddy;
    final iconSize = nested ? 36.0 : 42.0;
    final iconRadius = nested ? 11.0 : 13.0;
    final hMargin = nested ? 24.0 : 16.0;
    return Container(
      margin: EdgeInsets.symmetric(horizontal: hMargin, vertical: 4),
      decoration: BoxDecoration(
        color: c.card.withValues(alpha: nested ? 0.4 : 0.6),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(nested ? 4 : 20),
          bottomLeft: Radius.circular(nested ? 4 : 20),
          topRight: Radius.circular(nested ? 16 : 20),
          bottomRight: Radius.circular(nested ? 16 : 20),
        ),
        border: Border.all(color: c.border),
        boxShadow: nested ? null : c.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(nested ? 4 : 20),
          bottomLeft: Radius.circular(nested ? 4 : 20),
          topRight: Radius.circular(nested ? 16 : 20),
          bottomRight: Radius.circular(nested ? 16 : 20),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(nested ? 4 : 20),
            bottomLeft: Radius.circular(nested ? 4 : 20),
            topRight: Radius.circular(nested ? 16 : 20),
            bottomRight: Radius.circular(nested ? 16 : 20),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: nested ? 12 : 16, vertical: nested ? 10 : 14),
            child: Row(
              children: [
                Container(
                  width: iconSize,
                  height: iconSize,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(iconRadius),
                  ),
                  child: Icon(icon, color: color, size: nested ? 18 : 21),
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
