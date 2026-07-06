import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/theme/buddy_colors.dart';
import '../../services/settings_service.dart';
import 'accent_color_picker.dart';

class AppearanceSection extends StatelessWidget {
  const AppearanceSection({super.key});

  static const _languages = <(String, String)>[
    ('en', '🇬🇧 English'),
    ('de', '🇩🇪 Deutsch'),
    ('es', '🇪🇸 Español'),
    ('ja', '🇯🇵 日本語'),
    ('zh', '🇨🇳 中文'),
  ];

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final c = context.buddy;
    final settings = context.watch<SettingsService>();
    final current = settings.themeMode;
    final appLang = settings.appLanguage;
    const options = <(ThemeMode, String, IconData)>[
      (ThemeMode.system, 'System', Icons.brightness_auto_rounded),
      (ThemeMode.light, 'Hell', Icons.light_mode_rounded),
      (ThemeMode.dark, 'Dunkel', Icons.dark_mode_rounded),
    ];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: c.card.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border),
        boxShadow: c.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // App-Sprache
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 4, 6, 8),
            child: Row(
              children: [
                Icon(Icons.language, size: 17, color: c.t2),
                const SizedBox(width: 8),
                Text(t.appearance_language,
                    style: TextStyle(color: c.t2, fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final (code, label) in _languages)
                  Padding(
                    padding: const EdgeInsets.only(right: 8, left: 2),
                    child: GestureDetector(
                      onTap: () => context.read<SettingsService>().appLanguage = code,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: appLang == code
                              ? c.accent.withValues(alpha: 0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: appLang == code ? c.accent : c.border,
                            width: appLang == code ? 1.5 : 1,
                          ),
                        ),
                        child: Text(label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: appLang == code ? c.accent : c.t2,
                            )),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (final (value, label, icon) in options)
                Expanded(
                  child: GestureDetector(
                    onTap: () => context.read<SettingsService>().themeMode = value,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: current == value ? context.buddy.accent : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          Icon(icon, size: 20, color: current == value ? Colors.white : c.t2),
                          const SizedBox(height: 4),
                          Text(label, style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: current == value ? Colors.white : c.t2,
                          )),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          // Akzentfarbe Picker
          const AccentColorPicker(),
        ],
      ),
    );
  }
}
