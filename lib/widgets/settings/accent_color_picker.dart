import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/theme/buddy_colors.dart';
import '../../services/settings_service.dart';

class AccentColorPicker extends StatelessWidget {
  const AccentColorPicker({super.key});

  static const _presets = <Color>[
    Color(0xFF1B1F2E), // Deep Navy
    Color(0xFF2D6B6B), // Dark Teal
    Color(0xFFF5E6CC), // Warm Cream
    Color(0xFFF27A1A), // Vivid Orange
    Color(0xFF6B2D1A), // Dark Rust
  ];

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final c = context.buddy;
    final current = context.watch<SettingsService>().accentColor;
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.palette_outlined, size: 14, color: c.t3),
              const SizedBox(width: 6),
              Text(t.appearance_accent_color, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.t2)),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _presets.map((color) {
              final isSelected = current.toARGB32() == color.toARGB32();
              final isLight = color.computeLuminance() > 0.5;
              return GestureDetector(
                onTap: () => context.read<SettingsService>().accentColor = color,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? (isLight ? Colors.black : c.t1) : Colors.transparent,
                      width: 2.5,
                    ),
                    boxShadow: isSelected
                        ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 6)]
                        : null,
                  ),
                  child: isSelected
                      ? Icon(Icons.check, color: isLight ? Colors.black : Colors.white, size: 16)
                      : null,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
