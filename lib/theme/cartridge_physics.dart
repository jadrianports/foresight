import 'package:flutter/material.dart';

/// The hard-edged "Cartridge physics" tokens: offset block-shadows, ink
/// borders, square corners, the 4px spacing scale, and the pixelated-sprite
/// rendering convention. These are reusable value producers (not widgets —
/// NFR6) that the Epic 3/4 components consume to stay visually consistent.
///
/// The block-shadow rule (`Nx Ny 0`, ZERO blur, ink/shadow color) is the
/// non-negotiable core of the Cartridge identity — never a soft/blurred/glow/
/// gradient Material shadow (DESIGN elevation).
class CartridgePhysics {
  CartridgePhysics._();

  // ----- block-shadow offsets (DESIGN elevation) -----

  /// Standard raised surface: cards, rows, search bar, sort toggle.
  static const Offset offsetStandard = Offset(4, 4);

  /// Small elements: chips, badges.
  static const Offset offsetSmall = Offset(2, 2);

  /// Back chevron.
  static const Offset offsetChevron = Offset(3, 3);

  /// "Loud" surfaces that must sit visibly higher: the RISKY row + honest banner.
  static const Offset offsetLoud = Offset(5, 5);

  /// A single hard offset block-shadow in [shadow] with **zero blur**. Pass the
  /// theme's `CartridgeColors.shadow`. This is the ONLY shadow shape the design
  /// permits — never set `blurRadius`/`spreadRadius` to soften it.
  static BoxShadow cartridgeShadow(
    Color shadow, {
    Offset offset = offsetStandard,
  }) {
    return BoxShadow(
      color: shadow,
      offset: offset,
      blurRadius: 0,
      spreadRadius: 0,
    );
  }

  // ----- borders (DESIGN shapes) -----

  /// Standard ink border width.
  static const double borderWidth = 3;

  /// Small-element border width — type chips + badges (DESIGN type-chip "2px").
  static const double borderWidthChip = 2;

  /// Emphasised border width — the RISKY row + honest banner only.
  static const double borderWidthRisky = 4;

  /// A square ink (or tier) border in [color]. Defaults to the 3px hairline;
  /// pass [width] = [borderWidthRisky] for the RISKY treatment.
  static Border cartridgeBorder(Color color, {double width = borderWidth}) {
    return Border.all(color: color, width: width);
  }

  // ----- corners (DESIGN rounded) -----

  /// Frames, cards, rows, search bar, sort toggle, buttons — hard square.
  static const double radiusDefault = 0;

  /// Sprite tiles only — the single permitted softening.
  static const double radiusTile = 2;

  /// Small-element softening (alias of the tile radius).
  static const double radiusSm = 2;

  // ----- accent-bar widths (DESIGN result-row / result-row-top-pick) -----

  /// Standard left tier accent bar (DESIGN result-row "8px").
  static const double accentBarWidth = 8;

  /// The #1 SAFE top-pick row's WIDER accent bar (DESIGN `result-row-top-pick`
  /// "Wider accent bar (10px)"; Story 3.8 AC#1). Only ever the SAFE lead.
  static const double accentBarWidthTopPick = 10;

  /// The RISKY row's wider striped accent bar (DESIGN "loudest" — Story 3.4 AC#5).
  static const double accentBarWidthRisky = 12;

  // ----- accessibility floor (Story 3.8 / DESIGN.md:404 / EXPERIENCE.md:94) -----

  /// The minimum interactive-target extent: ≥44pt / 48dp. Only ever GROW a
  /// target to this — never shrink one down to "just" 48 (Story 3.8 AC#6).
  static const double minTouchTarget = 48;

  /// The dynamic-type scaling CAP for Press Start 2P pixel strings that sit in
  /// constrained frames (Story 3.8 AC#7). It is a CAP, NOT an opt-out: pixel text
  /// still scales up to this factor — the body (Nunito) scales freely, but the
  /// pixel font clamps here so a scaled badge/chip/multiplier cannot overflow its
  /// fixed frame. 1.3 is the smallest cap that keeps every pixel string inside
  /// its frame at the largest OS text setting (proved by the AC#10f max-scale
  /// no-overflow test on both Home and Result). [review-accessibility.md:66-69]
  static const double maxPixelTextScale = 1.3;

  /// How far the form badge overhangs the sprite tile's top-right corner
  /// (DESIGN components.form-badge "top-right corner, overhanging -3px"). Applied
  /// negated in a `Clip.none` `Stack` — the badge spills into the grid's s3 (12px)
  /// inter-cell gutter, so 3px never collides with a neighbour.
  static const double badgeOverhang = 3;

  // ----- spacing (DESIGN spacing — 4px base scale, theme-independent) -----

  static const double s1 = 4;
  static const double s2 = 8;
  static const double s3 = 12;
  static const double s4 = 16;
  static const double s5 = 22;
  static const double s6 = 36;

  // ----- sprites (DESIGN shapes "image-rendering: pixelated") -----

  /// Pixel-art sprites render with NO smoothing — Flutter's equivalent of CSS
  /// `image-rendering: pixelated`. Recorded here for Epic 3 (`Story 3.1`) to
  /// apply on every sprite `Image`; no sprite is rendered in this story.
  static const FilterQuality spriteFilterQuality = FilterQuality.none;
}
