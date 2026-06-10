import 'package:flutter/material.dart';

/// Telegram-inspirierte Farbpalette für AI-Buddy.
/// Dunkel, reduziert, mit dezenten Akzenten.
class AppColors {
  // ── Core Backgrounds ──
  static const Color bgDarkest  = Color(0xFF0B0B0F);  // Tiefschwarz mit leichtem Blau-Stich
  static const Color bgDark     = Color(0xFF121216);  // Haupt-Hintergrund
  static const Color bgCard     = Color(0xFF1C1C22);  // Karten / Elevated
  static const Color bgElevated = Color(0xFF23232A);  // Dialoge / BottomSheet

  // ── Surfaces (Glass) ──
  static Color glassBg     = Colors.white.withValues(alpha: 0.04);
  static Color glassBorder = Colors.white.withValues(alpha: 0.08);

  // ── Text ──
  static const Color textPrimary   = Color(0xFFF0F0F5);
  static const Color textSecondary = Color(0xFF8E8E93);
  static const Color textTertiary  = Color(0xFF5A5A60);

  // ── Accent: Periwinkle Blau (wie Input-Bar Kreis-Buttons) ──
  static const Color primary      = Color(0xFF6B8DD6);  // Periwinkle
  static const Color primaryDark  = Color(0xFF5B7EC4);
  static Color primaryGlow       = const Color(0xFF6B8DD6).withValues(alpha: 0.25);

  // ── Secondary Accent ──
  static const Color secondary     = Color(0xFF64D2FF);  // Helles Cyan
  static const Color secondaryDark = Color(0xFF52B8E8);

  // ── Sentiment ──
  static const Color success = Color(0xFF34C759);
  static const Color warning = Color(0xFFFF9500);
  static const Color error   = Color(0xFFFF3B30);
  static const Color info    = Color(0xFF5B9BD5);

  // ── Meta-Akzent (Selbstbild etc.) ──
  static const Color accent = Color(0xFFFF6A1A);  // Kräftiges Orange

  // ── Hintergrund-Gradient (anthracite, kein lila) ──
  static const LinearGradient bgGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF121216),
      Color(0xFF0B0B0F),
    ],
  );

  // ── Subtile Akzent-Gradiente ──
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF5B9BD5), Color(0xFF64D2FF)],
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

  // ── Message Bubble Colors ──
  static const LinearGradient userBubble = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6B8DD6), Color(0xFF5B7EC4)],  // Periwinkle — ruhig, passend zum Akzent
  );

  static const LinearGradient assistantBubbleBg = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1E1E24), Color(0xFF2A2A32)],  // Dunkles Anthrazit → Helles Anthrazit
  );
  static Color assistantBubbleBorder = Colors.white.withValues(alpha: 0.04);

  // ── Animation Durations ──
  static const Duration animFast   = Duration(milliseconds: 120);
  static const Duration animNormal = Duration(milliseconds: 220);
  static const Duration animSlow   = Duration(milliseconds: 350);
}
