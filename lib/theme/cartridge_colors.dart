import 'package:flutter/material.dart';

/// The bespoke Cartridge color tokens that Material's [ColorScheme] has no slot
/// for, carried as a theme-aware [ThemeExtension] read via
/// `Theme.of(context).extension<CartridgeColors>()!`.
///
/// WHY an extension and not `ColorScheme`: the design has *four* strictly
/// separate color jobs (DESIGN "four color jobs, kept strictly separate") —
/// chrome, brand primaries, the 4-value tier-status system, and the 18-value
/// type palette. `ColorScheme` only models chrome + brand. Cramming the tier
/// colors into `ColorScheme.error`/`tertiary` would (a) lose them when a
/// Material widget recolors those slots and (b) blur the rule that brand
/// primaries and tier *status* are different jobs. So tier (and chrome that
/// Material doesn't need) live here; `ColorScheme` carries only the chrome
/// Material widgets legitimately consume. One class, two const instances =
/// light/dark parity for free.
@immutable
class CartridgeColors extends ThemeExtension<CartridgeColors> {
  const CartridgeColors({
    // ----- chrome (differs by brightness) -----
    required this.paper,
    required this.surface,
    required this.ink,
    required this.inkMuted,
    required this.hairline,
    required this.shadow,
    required this.primaryRed,
    required this.primaryBlue,
    required this.primaryYellow,
    required this.placeholder1,
    required this.placeholder2,
    // ----- tier status (identical in light & dark) -----
    required this.tierSafe,
    required this.tierGood,
    required this.tierEven,
    required this.tierRisky,
    required this.tierRiskyAccent,
  });

  /// Warm paper / near-black ground (`scaffoldBackgroundColor`).
  final Color paper;

  /// White / dark-olive card ground.
  final Color surface;

  /// Deep-olive / phosphor-green text. Also the universal border + shadow color
  /// in this design — "the hard outline IS the design" (DESIGN colors).
  final Color ink;

  /// Muted ink for sublines.
  final Color inkMuted;

  /// Hairline border color (equals [ink] in light; a dimmer olive in dark).
  final Color hairline;

  /// Block-shadow color (offset, zero-blur). Tracks [ink] in light, near-black
  /// in dark.
  final Color shadow;

  /// DS-era brand accents (title dot, focal punctuation) — NOT status signals.
  final Color primaryRed;
  final Color primaryBlue;
  final Color primaryYellow;

  /// Empty-tile placeholder fills.
  final Color placeholder1;
  final Color placeholder2;

  // The four tier fills + the decorative RISKY accent. DESIGN: badge fills are
  // identical in light & dark (the badge carries its own fill), so both
  // instances below share these values — but every component reads them off the
  // extension uniformly, never as a hard-coded literal. Status is the tier
  // system's job; never confuse these with `ColorScheme.primary/error`.
  final Color tierSafe;
  final Color tierGood;
  final Color tierEven;
  final Color tierRisky;

  /// Decorative ONLY — the RISKY hatch/stripe accent. Never placed behind text.
  final Color tierRiskyAccent;

  /// Light palette — "DS bright paper". Hex copied verbatim from DESIGN colors.
  static const CartridgeColors light = CartridgeColors(
    paper: Color(0xFFF4ECD8),
    surface: Color(0xFFFFFFFF),
    ink: Color(0xFF20300F),
    inkMuted: Color(0xFF5C6B3A),
    hairline: Color(0xFF20300F),
    shadow: Color(0xFF20300F),
    primaryRed: Color(0xFFE03C28),
    primaryBlue: Color(0xFF2B6CB0),
    primaryYellow: Color(0xFFF6C700),
    placeholder1: Color(0xFFCDD6B0),
    placeholder2: Color(0xFFAEBB86),
    tierSafe: Color(0xFF2E7D33),
    tierGood: Color(0xFF2B6CB0),
    tierEven: Color(0xFFF6C700),
    tierRisky: Color(0xFFC2410C),
    tierRiskyAccent: Color(0xFFE0531C),
  );

  /// Dark palette — "Game Boy at night". Same tier fills, dark chrome.
  static const CartridgeColors dark = CartridgeColors(
    paper: Color(0xFF14180F),
    surface: Color(0xFF1F261A),
    ink: Color(0xFFD8E8B0),
    inkMuted: Color(0xFF8BA05E),
    hairline: Color(0xFF3A472A),
    shadow: Color(0xFF05070A),
    primaryRed: Color(0xFFF25140),
    primaryBlue: Color(0xFF4A8FD6),
    primaryYellow: Color(0xFFFFD61F),
    placeholder1: Color(0xFF2C3622),
    placeholder2: Color(0xFF3E4C2D),
    tierSafe: Color(0xFF2E7D33),
    tierGood: Color(0xFF2B6CB0),
    tierEven: Color(0xFFF6C700),
    tierRisky: Color(0xFFC2410C),
    tierRiskyAccent: Color(0xFFE0531C),
  );

  @override
  CartridgeColors copyWith({
    Color? paper,
    Color? surface,
    Color? ink,
    Color? inkMuted,
    Color? hairline,
    Color? shadow,
    Color? primaryRed,
    Color? primaryBlue,
    Color? primaryYellow,
    Color? placeholder1,
    Color? placeholder2,
    Color? tierSafe,
    Color? tierGood,
    Color? tierEven,
    Color? tierRisky,
    Color? tierRiskyAccent,
  }) {
    return CartridgeColors(
      paper: paper ?? this.paper,
      surface: surface ?? this.surface,
      ink: ink ?? this.ink,
      inkMuted: inkMuted ?? this.inkMuted,
      hairline: hairline ?? this.hairline,
      shadow: shadow ?? this.shadow,
      primaryRed: primaryRed ?? this.primaryRed,
      primaryBlue: primaryBlue ?? this.primaryBlue,
      primaryYellow: primaryYellow ?? this.primaryYellow,
      placeholder1: placeholder1 ?? this.placeholder1,
      placeholder2: placeholder2 ?? this.placeholder2,
      tierSafe: tierSafe ?? this.tierSafe,
      tierGood: tierGood ?? this.tierGood,
      tierEven: tierEven ?? this.tierEven,
      tierRisky: tierRisky ?? this.tierRisky,
      tierRiskyAccent: tierRiskyAccent ?? this.tierRiskyAccent,
    );
  }

  @override
  CartridgeColors lerp(ThemeExtension<CartridgeColors>? other, double t) {
    if (other is! CartridgeColors) return this;
    // These are hard, stamped tokens and v1 has no animated theme switch
    // (OS-follow swaps instantly), so snapping is correct and avoids muddy
    // half-interpolated chrome. Interpolation would only matter for an animated
    // ThemeData transition, which this app never performs.
    return t < 0.5 ? this : other;
  }
}
