import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The DESIGN typography roles, 1:1 as named [TextStyle]s.
///
/// COLOR IS DELIBERATELY ABSENT — these styles carry family / size / weight /
/// height / letterSpacing only. Components apply the brightness-correct ink at
/// the use-site via `.copyWith(color: cartridgeColors.ink)`. Keeping color out
/// lets ONE typography table serve both themes (parity by construction).
///
/// Fonts resolve OFFLINE: `google_fonts` auto-uses the bundled `.ttf`s under
/// `assets/fonts/` (Story 1.1) and `main()` sets `allowRuntimeFetching = false`
/// (AD-1), so these never hit the network. Press Start 2P ships a single
/// Regular (weight 400) — every pixel role is weight 400.
class CartridgeTypography {
  CartridgeTypography._();

  // ----- Press Start 2P: display / accent only (short, loud, all-caps) -----
  // The pixel font is NEVER assigned to a sentence/body role; its floor is 10px
  // except the documented 9px `miniLabel` ("RECENT") exception.

  /// Home wordmark "FORESIGHT". PS2P 22 / 1.1 / +1.
  static TextStyle get appTitle => GoogleFonts.pressStart2p(
        fontSize: 22,
        height: 1.1,
        letterSpacing: 1,
      );

  /// Nav-bar title. PS2P 15 / 1.2 / +1.
  static TextStyle get appbarTitle => GoogleFonts.pressStart2p(
        fontSize: 15,
        height: 1.2,
        letterSpacing: 1,
      );

  /// Ranked type name. PS2P 15 / 1.2 / +1.
  static TextStyle get typeName => GoogleFonts.pressStart2p(
        fontSize: 15,
        height: 1.2,
        letterSpacing: 1,
      );

  /// Multiplier "4×". PS2P 16 / 1.0.
  static TextStyle get multiplier => GoogleFonts.pressStart2p(
        fontSize: 16,
        height: 1.0,
      );

  /// Section header "USE THESE TYPES". PS2P 10 / 1.4 / +1.
  static TextStyle get sectionHeader => GoogleFonts.pressStart2p(
        fontSize: 10,
        height: 1.4,
        letterSpacing: 1,
      );

  /// Tier badge / type chip / form badge. PS2P 10 (the pixel floor) / 1.2 / +0.5.
  static TextStyle get badge => GoogleFonts.pressStart2p(
        fontSize: 10,
        height: 1.2,
        letterSpacing: 0.5,
      );

  /// "RECENT" mini-label — the one documented sub-10px (9px) pixel exception.
  static TextStyle get miniLabel => GoogleFonts.pressStart2p(
        fontSize: 9,
        height: 1.4,
        letterSpacing: 1,
      );

  // ----- Nunito: body / data (everything a human reads at speed) -----

  /// Type-chip fallback when a type name won't fit legibly in the pixel font at
  /// 10px. Nunito 800 11 / 1.2 / +0.3. (WHEN to fall back is an Epic 3 chip
  /// concern; this story only supplies the style.)
  static TextStyle get chipFallback => GoogleFonts.nunito(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        height: 1.2,
        letterSpacing: 0.3,
      );

  /// Opponent name. Nunito 800 24 / 1.05.
  static TextStyle get bodyLg => GoogleFonts.nunito(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        height: 1.05,
      );

  /// Sublines, breakdown link, honest-call sentence, search input. Nunito 700
  /// 15 / 1.45.
  static TextStyle get body => GoogleFonts.nunito(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        height: 1.45,
      );

  /// Tier sublines, about footnote. Nunito 700 13 / 1.4.
  static TextStyle get bodySm => GoogleFonts.nunito(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        height: 1.4,
      );

  /// Grid / recent tile label. Nunito 800 12 / 1.2.
  static TextStyle get tileName => GoogleFonts.nunito(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        height: 1.2,
      );
}
