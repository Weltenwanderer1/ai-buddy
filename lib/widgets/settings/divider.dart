import 'package:flutter/material.dart';
import '../../core/theme/buddy_colors.dart';

class SettingsDivider extends StatelessWidget {
  const SettingsDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Divider(
        color: context.buddy.border,
        height: 1,
      ),
    );
  }
}
