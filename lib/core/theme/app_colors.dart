import 'package:flutter/material.dart';

/// Konsistente Farbpalette für AI-Buddy.
/// Dunkles Theme mit Akzent-Farben, die je nach Persona leicht anpasstbar sind.
class AppColors {
  // ── Backgrounds ──
  static const Color bgDarkest  = Color(0xFF060614);
  static const Color bgDark     = Color(0xFF0C0C1D);
  static const Color bgCard     = Color.fromARGB(255, 17, 17, 36);
  static const Color bgElevated = Color(0xFF1A1A30);
  static const Color bgSurface  = Color.fromARGB(255, 23, 23, 48);

  // ── Surfaces with opacity ──
  static Color glassBg = Colors.white.withOpacity(0.05);
  static Color glassBorder = Colors.white.withOpacity(0.08);

  // ── Text ──
  static const Color textPrimary   = Colors.white;
  static const Color textSecondary = Color(0xFF8B8FA3);
  static const Color textTertiary  = Color(0xFF5E6278);

  // ── Accent Colors (Primary) ──
  static const Color primary = Color(0xFF8B5CF6);       // Vivid violet
  static const Color primaryDark = Color(0xFF6D28D9);
  static Color primaryGlow = const Color(0xFF8B5CF6).withOpacity(0.3);

  // ── Secondary Accent ──
  static const Color secondary = Color(0xFF06B6D4);     // Cyan
  static const Color secondaryDark = Color(0xFF0891B2);

  // ── Sentiment Colors ──
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error   = Color(0xFFEF4444);
  static const Color info    = Color(0xFF3B82F6);

  // ── Accent ──
  static const Color accent  = Color(0xFFEC4899);  // Pink - für Selbstbild / Meta-UI

  // ── Gradient Definitions ──
  static const LinearGradient bgGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0C0C1D), Color(0xFF060614), Color(0xFF1A1034)],
  );

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF8B5CF6), Color(0xFFD946EF)],
  );

  static const LinearGradient secondaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF06B6D4), Color(0xFF3B82F6)],
  );

  // ── Message Bubble Colors ──
  static LinearGradient userBubble = const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
  );

  static Color assistantBubbleBg = const Color(0xFF2D2D35);
  static Color assistantBubbleBorder = Colors.white.withOpacity(0.06);

  // ── Animations ──
  static const Duration animFast = Duration(milliseconds: 150);
  static const Duration animNormal = Duration(milliseconds: 250);
  static const Duration animSlow = Duration(milliseconds: 400);
}
