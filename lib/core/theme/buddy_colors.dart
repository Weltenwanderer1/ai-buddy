import 'package:flutter/material.dart';

/// Theme-abhängige Flächen-, Text- und Linienfarben für AI-Buddy.
///
/// Die Akzentfarben (Periwinkle, Cyan, Grün, Orange) bleiben in beiden Modi
/// identisch und leben weiterhin in [AppColors]. Hier stehen nur die Rollen,
/// die sich zwischen Hell und Dunkel unterscheiden.
///
/// Die Werte stammen 1:1 aus dem Redesign-Mockup (Phone.dc.html):
///   dark  → Telegram-Dark
///   light → ruhiges Hellgrau/Weiß
@immutable
class BuddyColors extends ThemeExtension<BuddyColors> {
  /// Scaffold-Hintergrund (`--bg`).
  final Color bg;

  /// Chat-Wallpaper hinter den Bubbles (`--wall`).
  final Color wall;

  /// Karten / Surface (`--card`).
  final Color card;

  /// Erhöhte Flächen: Dialoge, BottomSheets (`--elev`).
  final Color elev;

  /// Eingabe-Pille (`--pill`).
  final Color pill;

  /// Text primär (`--t1`).
  final Color t1;

  /// Text sekundär (`--t2`).
  final Color t2;

  /// Text tertiär (`--t3`).
  final Color t3;

  /// Feine Trennlinien / Karten-Rand (`--border`).
  final Color border;

  /// Etwas kräftigerer Rand für Chips / Toggle-Tracks (`--gbd`).
  final Color chipBorder;

  /// Akzentfarbe (Periwinkle) — in beiden Modi gleich.
  final Color accent;

  /// Erfolgsfarbe (Grün) — unverändert.
  final Color success;

  /// Fehlerfarbe (Rot) — unverändert.
  final Color error;

  /// Pin-Farbe (Orange) — unverändert.
  final Color pin;

  /// Fläche der KI-Bubble (`--aib`).
  final Color aiBubble;

  /// Rand der KI-Bubble (`--aibd`).
  final Color aiBubbleBorder;

  /// Sanfter Schatten unter Karten/KI-Bubbles. Im Dark-Mode leer (`--shadow`).
  final List<BoxShadow> cardShadow;

  const BuddyColors({
    required this.bg,
    required this.wall,
    required this.card,
    required this.elev,
    required this.pill,
    required this.t1,
    required this.t2,
    required this.t3,
    required this.border,
    required this.chipBorder,
    required this.accent,
    required this.success,
    required this.error,
    required this.pin,
    required this.aiBubble,
    required this.aiBubbleBorder,
    required this.cardShadow,
  });

  static const BuddyColors dark = BuddyColors(
    bg: Color(0xFF0B0B0F),
    wall: Color(0xFF0B0B0F),
    card: Color(0xFF1C1C22),
    elev: Color(0xFF23232A),
    pill: Color(0xFF24242A),
    t1: Color(0xFFF0F0F5),
    t2: Color(0xFF8E8E93),
    t3: Color(0xFF5A5A60),
    border: Color(0x12FFFFFF),
    chipBorder: Color(0x24FFFFFF),
    accent: Color(0xFF6B8DD6),
    success: Color(0xFF34C759),
    error: Color(0xFFFF3B30),
    pin: Color(0xFFFF9500),
    aiBubble: Color(0xFF22222A),
    aiBubbleBorder: Color(0x1AFFFFFF),
    cardShadow: [],
  );

  static const BuddyColors light = BuddyColors(
    bg: Color(0xFFF4F5F7),
    wall: Color(0xFFE9ECF1),
    card: Color(0xFFFFFFFF),
    elev: Color(0xFFF1F3F6),
    pill: Color(0xFFFFFFFF),
    t1: Color(0xFF14151A),
    t2: Color(0xFF6E727A),
    t3: Color(0xFF9AA0A8),
    border: Color(0x14000000),
    chipBorder: Color(0x24000000),
    accent: Color(0xFF6B8DD6),
    success: Color(0xFF34C759),
    error: Color(0xFFFF3B30),
    pin: Color(0xFFFF9500),
    aiBubble: Color(0xFFFFFFFF),
    aiBubbleBorder: Color(0x0F000000),
    cardShadow: [
      BoxShadow(
        color: Color(0x0F000000),
        blurRadius: 2,
        offset: Offset(0, 1),
      ),
    ],
  );

  /// Bequemer Zugriff: `BuddyColors.of(context)`.
  static BuddyColors of(BuildContext context) =>
      Theme.of(context).extension<BuddyColors>() ?? dark;

  @override
  BuddyColors copyWith({
    Color? bg,
    Color? wall,
    Color? card,
    Color? elev,
    Color? pill,
    Color? t1,
    Color? t2,
    Color? t3,
    Color? border,
    Color? chipBorder,
    Color? accent,
    Color? success,
    Color? error,
    Color? pin,
    Color? aiBubble,
    Color? aiBubbleBorder,
    List<BoxShadow>? cardShadow,
  }) {
    return BuddyColors(
      bg: bg ?? this.bg,
      wall: wall ?? this.wall,
      card: card ?? this.card,
      elev: elev ?? this.elev,
      pill: pill ?? this.pill,
      t1: t1 ?? this.t1,
      t2: t2 ?? this.t2,
      t3: t3 ?? this.t3,
      border: border ?? this.border,
      chipBorder: chipBorder ?? this.chipBorder,
      accent: accent ?? this.accent,
      success: success ?? this.success,
      error: error ?? this.error,
      pin: pin ?? this.pin,
      aiBubble: aiBubble ?? this.aiBubble,
      aiBubbleBorder: aiBubbleBorder ?? this.aiBubbleBorder,
      cardShadow: cardShadow ?? this.cardShadow,
    );
  }

  @override
  BuddyColors lerp(ThemeExtension<BuddyColors>? other, double t) {
    if (other is! BuddyColors) return this;
    return BuddyColors(
      bg: Color.lerp(bg, other.bg, t)!,
      wall: Color.lerp(wall, other.wall, t)!,
      card: Color.lerp(card, other.card, t)!,
      elev: Color.lerp(elev, other.elev, t)!,
      pill: Color.lerp(pill, other.pill, t)!,
      t1: Color.lerp(t1, other.t1, t)!,
      t2: Color.lerp(t2, other.t2, t)!,
      t3: Color.lerp(t3, other.t3, t)!,
      border: Color.lerp(border, other.border, t)!,
      chipBorder: Color.lerp(chipBorder, other.chipBorder, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      success: Color.lerp(success, other.success, t)!,
      error: Color.lerp(error, other.error, t)!,
      pin: Color.lerp(pin, other.pin, t)!,
      aiBubble: Color.lerp(aiBubble, other.aiBubble, t)!,
      aiBubbleBorder: Color.lerp(aiBubbleBorder, other.aiBubbleBorder, t)!,
      cardShadow: t < 0.5 ? cardShadow : other.cardShadow,
    );
  }
}

/// Kurzschreibweise: `context.buddy.card` statt
/// `Theme.of(context).extension<BuddyColors>()!.card`.
extension BuddyColorsContext on BuildContext {
  BuddyColors get buddy => BuddyColors.of(this);
}
