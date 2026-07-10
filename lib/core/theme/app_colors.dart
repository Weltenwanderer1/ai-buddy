import 'package:flutter/material.dart';

/// Telegram-inspirierte Farbpalette fuer AI-Buddy.
/// Dunkel, reduziert, mit dezenten Akzenten.
class AppColors {
  // -- Core Backgrounds --
  static const Color bgDarkest  = Color(0xFF0B0B0F);  // Tiefschwarz mit leichtem Blau-Stich
  static const Color bgDark     = Color(0xFF121216);  // Haupt-Hintergrund
  static const Color bgCard     = Color(0xFF1C1C22);  // Karten / Elevated
  static const Color bgElevated = Color(0xFF23232A);  // Dialoge / BottomSheet

  // -- Surfaces (Glass) --
  static Color glassBg     = Colors.white.withValues(alpha: 0.04);
  static Color glassBorder = Colors.white.withValues(alpha: 0.08);

  // -- Text --
  static const Color textPrimary   = Color(0xFFF0F0F5);
  static const Color textSecondary = Color(0xFF8E8E93);
  static const Color textTertiary  = Color(0xFF5A5A60);

  // -- Accent: Periwinkle Blau (wie Input-Bar Kreis-Buttons) --
  static Color primary      = const Color(0xFF6B8DD6);  // Periwinkle - mutable for accent override
  static Color primaryDark  = const Color(0xFF5B7EC4);

  static Color get primaryGlow => primary.withValues(alpha: 0.25);

  /// Readable foreground for user-selectable accent colors. Light accents such
  /// as Warm Cream need dark content; white remains clearer on dark accents.
  static Color foregroundFor(Color background) =>
      background.computeLuminance() > 0.5
          ? const Color(0xFF14151A)
          : Colors.white;

  static Color get onPrimary => foregroundFor(primary);

  // -- Secondary Accent --
  static const Color secondary     = Color(0xFF64D2FF);  // Helles Cyan
  static const Color secondaryDark = Color(0xFF52B8E8);

  // -- Sentiment --
  static const Color success = Color(0xFF34C759);
  static const Color warning = Color(0xFFFF9500);
  static const Color error   = Color(0xFFFF3B30);
  static const Color info    = Color(0xFF5B9BD5);

  // -- Meta-Akzent (Selbstbild etc.) --
  static const Color accent = Color(0xFFFF6A1A);  // Kraeftiges Orange

  // -- Hintergrund-Gradient (anthracite, kein lila) --
  static const LinearGradient bgGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF121216),
      Color(0xFF0B0B0F),
    ],
  );

  // -- Subtile Akzent-Gradiente --
  static LinearGradient get primaryGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryDark, primary.withValues(alpha: 1.0)],
  );

  static const LinearGradient secondaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF64D2FF), Color(0xFF5B9BD5)],
  );

  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF34D399), Color(0xFF059669)],
  );

  // -- Message Bubble Colors --
  static Color get userBubbleSolid => primary;  // mutable - follows primary

  // -- Animation Durations --
  static const Duration animFast   = Duration(milliseconds: 120);
  static const Duration animNormal = Duration(milliseconds: 220);
  static const Duration animSlow   = Duration(milliseconds: 350);
}