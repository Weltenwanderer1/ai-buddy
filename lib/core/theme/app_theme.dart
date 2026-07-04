import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'buddy_colors.dart';

/// Globales App-Theme für AI-Buddy.
/// Material3, Inter, Periwinkle-Akzent — in Hell und Dunkel.
///
/// Flächen-/Text-Farben kommen aus der [BuddyColors]-ThemeExtension, damit ein
/// Light-Theme ohne Hardcoding möglich ist. Der Akzent ([AppColors.primary])
/// bleibt in beiden Modi identisch.
class AppTheme {
  static ThemeData dark([Color? accent]) {
    final a = accent ?? AppColors.primary;
    return _build(BuddyColors.dark.copyWith(accent: a), Brightness.dark, a);
  }
  static ThemeData light([Color? accent]) {
    final a = accent ?? AppColors.primary;
    return _build(BuddyColors.light.copyWith(accent: a), Brightness.light, a);
  }

  static ThemeData _build(BuddyColors c, Brightness brightness, Color accent) {
    final isDark = brightness == Brightness.dark;

    final cs = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: brightness,
      surface: c.card,
      surfaceTint: accent.withValues(alpha: 0.1),
      primary: accent,
      secondary: AppColors.secondary,
      error: AppColors.error,
      onSurface: c.t1,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: cs,
      scaffoldBackgroundColor: c.bg,
      fontFamily: 'Inter',
      extensions: [c],

      // ── System UI (Status + Navigation Bar) ──
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness:
              isDark ? Brightness.light : Brightness.dark,
          systemNavigationBarDividerColor: Colors.transparent,
        ),
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: c.t1,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(
          color: c.t2,
          size: 22,
        ),
      ),

      // ── Card ──
      cardTheme: CardThemeData(
        color: c.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
      ),

      // ── Input ──
      inputDecorationTheme: InputDecorationTheme(
        filled: false, // Kein automatischer Hintergrund — TextFields sind transparent
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        hintStyle: TextStyle(
          color: c.t3,
          fontSize: 15,
          fontWeight: FontWeight.w400,
        ),
        labelStyle: TextStyle(
          color: c.t2,
          fontSize: 14,
        ),
        prefixIconColor: c.t3,
      ),

      // ── Button: Filled ──
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),

      // ── Button: Outlined ──
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          side: BorderSide(color: c.chipBorder),
          foregroundColor: c.t1,
        ),
      ),

      // ── Button: Text ──
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          foregroundColor: accent,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),

      // ── Bottom Nav ──
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: accent,
        unselectedItemColor: c.t3,
        selectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
        type: BottomNavigationBarType.fixed,
      ),

      // ── List Tile ──
      listTileTheme: ListTileThemeData(
        tileColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        titleTextStyle: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: c.t1,
        ),
        subtitleTextStyle: TextStyle(
          fontSize: 13,
          color: c.t2,
        ),
        leadingAndTrailingTextStyle: TextStyle(
          fontSize: 14,
          color: c.t2,
        ),
      ),

      // ── Dialog ──
      dialogTheme: DialogThemeData(
        backgroundColor: c.elev,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        elevation: 0,
      ),

      // ── Snackbar ──
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.elev,
        contentTextStyle: TextStyle(fontSize: 14, color: c.t1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
      ),

      // ── Divider ──
      dividerTheme: DividerThemeData(
        color: c.border,
        thickness: 1,
        space: 24,
      ),

      // ── Switches / Sliders ──
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return accent;
          return c.chipBorder;
        }),
        thumbColor: WidgetStateProperty.all(Colors.white),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
    );
  }
}
