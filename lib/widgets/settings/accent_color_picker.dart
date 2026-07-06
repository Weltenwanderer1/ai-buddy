import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/theme/buddy_colors.dart';
import '../../services/settings_service.dart';

class AccentColorPicker extends StatelessWidget {
  const AccentColorPicker({super.key});

  static const _presets = <Color>[
    Color(0xFF6B8DD6), // Periwinkle (default)
    Color(0xFF5B9BD5), // Blue
    Color(0xFF34C759), // Green
    Color(0xFFFF9500), // Orange
    Color(0xFFFF3B30), // Red
    Color(0xFFFF6B9D), // Pink
    Color(0xFFA855F7), // Purple
    Color(0xFF64D2FF), // Cyan
    Color(0xFFD4AF37), // Gold
    Color(0xFF9BA0A3), // Gray
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
                      color: isSelected ? c.t1 : Colors.transparent,
                      width: 2.5,
                    ),
                    boxShadow: isSelected
                        ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 6)]
                        : null,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 16)
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
