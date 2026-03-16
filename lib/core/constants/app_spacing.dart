/// Klexi spacing system
/// Use these constants everywhere — no magic numbers.
class AppSpacing {
  // ── Base scale (4pt grid) ──────────────────────────
  static const double xs  = 4.0;
  static const double sm  = 8.0;
  static const double md  = 12.0;
  static const double lg  = 16.0;
  static const double xl  = 20.0;
  static const double x2l = 24.0;
  static const double x3l = 32.0;
  static const double x4l = 40.0;
  static const double x5l = 48.0;

  // ── Screen edge padding ───────────────────────────
  /// Standard horizontal screen margin
  static const double screenH = 20.0;
  /// Generous horizontal screen margin (detail screens)
  static const double screenHWide = 24.0;

  // ── Card internals ────────────────────────────────
  /// Padding inside cards
  static const double cardPad    = 20.0;
  static const double cardPadLg  = 24.0;
  /// Gap between elements inside a card
  static const double cardGap    = 14.0;
  static const double cardGapLg  = 18.0;

  // ── List/grid spacing ─────────────────────────────
  /// Gap between sibling cards in a vertical list
  static const double listGap    = 12.0;
  static const double listGapLg  = 16.0;
  /// Gap between quick-action buttons
  static const double buttonGap  = 10.0;
  static const double buttonGapLg = 12.0;

  // ── Section spacing ───────────────────────────────
  /// Space between major sections on a screen
  static const double sectionGap = 20.0;
  static const double sectionTop = 8.0;

  // ── Corner radii ──────────────────────────────────
  static const double radiusSm  = 8.0;
  static const double radiusMd  = 12.0;
  static const double radiusLg  = 16.0;
  static const double radiusXl  = 20.0;
  static const double radiusCard = 20.0;
  static const double radiusPill = 100.0;

  // ── Component heights ─────────────────────────────
  static const double buttonH    = 48.0;
  static const double buttonHSm  = 36.0;
  static const double inputH     = 48.0;
  static const double chipH      = 32.0;
  static const double tabBarH    = 80.0;
  static const double appBarH    = 56.0;

  // ── Sentence card (core learning UI) ─────────────
  static const double sentenceCardPad = 24.0;
  static const double sentenceCardGap = 18.0;
  static const double sentenceLineH   = 1.8; // lineHeight multiplier

  // ── Word chip ─────────────────────────────────────
  static const double chipPadH   = 14.0;
  static const double chipPadV   =  7.0;
  static const double chipGap    =  8.0;
}
