import 'package:flutter/material.dart';
import '../../core/theme/buddy_colors.dart';

class SettingsListTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? color;
  final Widget? trailing;
  final VoidCallback onTap;

  const SettingsListTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.color,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(children: [
        Expanded(
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(24),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 0),
                child: Row(children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: context.buddy.border,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.buddy.border),
                    ),
                    child: Icon(icon, size: 20, color: context.buddy.t2),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.buddy.t1)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!,
                        style: TextStyle(fontSize: 13, color: context.buddy.t2),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ])),
                ]),
              ),
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ]),
    );
  }
}
