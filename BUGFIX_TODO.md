# AI-Buddy Bugfix TODO — Stand 2026-07-06

## Was gemacht wurde (COMMITTED):

### Bug 1: Spracheinstellung funktioniert nicht
- `lib/core/i18n/app_localizations.dart` — 216 keys × 5 Sprachen (en/de/es/ja/zh) in translations map
- Neue Getter: `config_openrouter_api_key`, `data_reset_desc`, `config_embedding_testing`
- `settings_screen.dart` — ~80+ hardcoded DE Strings → `t.xxx` Calls
- `chat_screen.dart` — import + i18n für ausgewählte/voice Strings
- `message_input.dart` — `t` als late field, STT/voice strings ersetzt
- `message_bubble.dart` — i18n changes

### Bug 2: Graue Statusbar im Settings-Screen
- `AnnotatedRegion<SystemUiOverlayStyle>` um Scaffold in `settings_screen.dart`
- Import `package:flutter/services.dart` hinzugefügt
- Pattern wie `chat_screen.dart` L534: `statusBarColor: Colors.transparent`, `context.buddy.bg`

### Bug 3: flutter analyze Fehler (alle gefixt)
- `static const` model lists → instance getters (settings_screen.dart)
- `t` scope in allen Methoden: `final t = AppLocalizations.of(context);` am Anfang jeder Methode
- `const Text(t.xxx)` → `Text(t.xxx)` (non-const wegen runtime i18n)
- `t.model_claude_opus` → hardcoded string (Modellname = data, nicht UI)
- Duplicate `t` declaration in build() entfernt
- Unused `t` declarations in StatelessWidget build() methods entfernt

### Version bump
- `lib/core/version.dart`: 1.19.1 → 1.19.2
- `pubspec.yaml`: 1.19.1+181 → 1.19.2+182

## Noch zu tun:
1. `flutter analyze` → 0 issues bestätigen
2. Git commit + tag push → CI baut APK

## i18n Pattern:
```dart
final t = AppLocalizations.of(context);
// dann: t.settings_title, t.config_openrouter_api_key, etc.
```
Lookup: `AppLocalizations.of(context)._t(key)` → `translations[currentLangCode][key]`

## AnnotatedRegion Pattern (from chat_screen.dart L534):
```dart
final brightness = Theme.of(context).brightness;
final isLight = brightness == Brightness.light;
return AnnotatedRegion<SystemUiOverlayStyle>(
  value: SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: isLight ? Brightness.dark : Brightness.light,
    systemNavigationBarColor: context.buddy.bg,
    systemNavigationBarIconBrightness: isLight ? Brightness.dark : Brightness.light,
    systemNavigationBarDividerColor: context.buddy.bg,
  ),
  sized: true,
  child: Scaffold(...),
);
```