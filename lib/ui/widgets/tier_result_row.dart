import 'package:flutter/material.dart';

import '../../engine/ranking.dart';
import '../../theme/cartridge_colors.dart';
import '../../theme/cartridge_physics.dart';
import '../../theme/cartridge_typography.dart';
import '../../theme/type_colors.dart';
import '../result_subline.dart';

/// One ranked answer row: an attacking TYPE (never a Pokémon) with its
/// multiplier, its AD-9 tier presented via FOUR redundant cues, and an honest
/// subline (Story 3.4 AC#3/#4/#5/#6).
///
/// The tier is read from [RankedPick.tier] VERBATIM — the UI NEVER re-derives a
/// tier from the multiplier (AD-9). This widget is purely presentational: it maps
/// the engine's decision to (color, icon, word), prints `pick.offense` as the
/// multiplier, and hands `pick` to [honestSubline].
///
/// Redundant cues (NFR4 — meaning never relies on color alone): the row carries
/// the tier COLOR (accent bar + badge), the ICON (✅/◆/▲/⚠), the WORD
/// (SAFE/GOOD/EVEN/RISKY), and its RANK (its top-to-bottom position in the
/// safest-first list the caller renders). The RISKY row additionally gets the
/// signature "loudest" treatment (AC#5).
class TierResultRow extends StatelessWidget {
  const TierResultRow(this.pick, {this.isTopPick = false, super.key});

  final RankedPick pick;

  /// Story 3.8 AC#1: the #1 SAFE lead (row index 0 when the list leads with a
  /// SAFE pick). When true this row renders the WIDER 10px accent bar and a
  /// static `#1` pixel marker, and its merged semantics label is prefixed with
  /// "Top pick. ". The engine/`rank(...)` is UNCHANGED — the UI decides top pick;
  /// only ever true for a SAFE row (the caller enforces `picks.first.tier`).
  final bool isTopPick;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CartridgeColors>()!;
    final (word, icon, tierColor) = _present(pick.tier, colors);
    final isRisky = pick.tier == Tier.risky;

    // RISKY is visibly heavier (AC#5): 4px tier border + 5px shadow vs the
    // standard 3px ink + 4px shadow. The recolored type name uses tierRiskyText
    // (theme-correct ≥4.5:1 on surface) — NOT tierRisky directly.
    final border = isRisky
        ? CartridgePhysics.cartridgeBorder(
            colors.tierRisky,
            width: CartridgePhysics.borderWidthRisky,
          )
        : CartridgePhysics.cartridgeBorder(colors.ink);
    final shadow = isRisky
        ? CartridgePhysics.cartridgeShadow(
            colors.shadow,
            offset: CartridgePhysics.offsetLoud,
          )
        : CartridgePhysics.cartridgeShadow(colors.shadow);
    final typeNameColor = isRisky ? colors.tierRiskyText : colors.ink;

    // ONE merged screen-reader announcement per row (AC#4, NFR4): the words
    // carry the meaning once — type, multiplier ("N times"), tier WORD, honest
    // subline — with the decorative icon/×/accent-bar excluded. `excludeSemantics`
    // silences the child a11y nodes but KEEPS the child `Text` widgets, so the
    // existing `find.text('SAFE'|'FIGHTING'|'4×'…)` finders still pass.
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: _semanticLabel(word),
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          border: border,
          boxShadow: [shadow],
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left tier-colored accent bar — 8px standard, 10px for the #1 SAFE
              // top pick (AC#1), 12px striped for the RISKY row (decorative accent
              // ONLY — never behind text).
              _AccentBar(
                color: tierColor,
                isRisky: isRisky,
                isTopPick: isTopPick,
                accent: colors.tierRiskyAccent,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(CartridgePhysics.s3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // The pixel header strip (badge + #1 marker + type name +
                      // multiplier) CLAMP-scales so a large OS text setting grows
                      // it but can't overflow the row (AC#7). The Nunito subline
                      // below scales FREELY — it's outside this clamp.
                      MediaQuery.withClampedTextScaling(
                        maxScaleFactor: CartridgePhysics.maxPixelTextScale,
                        child: Row(
                          children: [
                            _TierBadge(word: word, icon: icon, fill: tierColor),
                            if (isTopPick) ...[
                              const SizedBox(width: CartridgePhysics.s2),
                              _TopPickMarker(colors: colors),
                            ],
                            const SizedBox(width: CartridgePhysics.s3),
                            Expanded(
                              child: Text(
                                pick.attackingType.toUpperCase(),
                                style: CartridgeTypography.typeName
                                    .copyWith(color: typeNameColor),
                              ),
                            ),
                            const SizedBox(width: CartridgePhysics.s2),
                            Text(
                              // offense is exactly 2 or 4 (SE gate), so .toInt()
                              // is safe and yields "2×"/"4×".
                              '${pick.offense.toInt()}×',
                              style: CartridgeTypography.multiplier
                                  .copyWith(color: colors.ink),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: CartridgePhysics.s2),
                      Text(
                        honestSubline(pick),
                        style: CartridgeTypography.bodySm
                            .copyWith(color: colors.inkMuted),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Composes the merged row announcement (AC#4). Reuses `honestSubline(pick)`
  /// and the tier [word] VERBATIM (never a second source of truth), lower-casing
  /// the subline's lead so it flows mid-sentence, e.g.
  /// "Fighting, 4 times, SAFE, resists both its STABs". The #1 SAFE lead prefixes
  /// "Top pick. " (AC#1/#3 — the spoken rank cue).
  String _semanticLabel(String word) {
    final type = _capitalize(pick.attackingType);
    final subline = _lowerFirst(honestSubline(pick));
    final base = '$type, ${pick.offense.toInt()} times, $word, $subline';
    return isTopPick ? 'Top pick. $base' : base;
  }

  /// Maps the engine's [Tier] to its (word, icon, color) presentation. This is
  /// the ONLY place the label/glyph is chosen, and it switches on `pick.tier`
  /// verbatim — never on a multiplier (AD-9).
  (String, String, Color) _present(Tier tier, CartridgeColors colors) {
    switch (tier) {
      case Tier.safe:
        return ('SAFE', '✅', colors.tierSafe);
      case Tier.good:
        return ('GOOD', '◆', colors.tierGood);
      case Tier.even:
        return ('EVEN', '▲', colors.tierEven);
      case Tier.risky:
        return ('RISKY', '⚠', colors.tierRisky);
    }
  }
}

/// The left-edge tier accent. Standard rows get an 8px solid bar; the #1 SAFE
/// top pick gets a WIDER 10px solid bar (AC#1); the RISKY row gets a 12px striped
/// bar in the decorative `tierRiskyAccent` (Story 3.4 AC#5) — all decorative,
/// kept off any text.
class _AccentBar extends StatelessWidget {
  const _AccentBar({
    required this.color,
    required this.isRisky,
    required this.isTopPick,
    required this.accent,
  });

  final Color color;
  final bool isRisky;
  final bool isTopPick;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    if (!isRisky) {
      final width = isTopPick
          ? CartridgePhysics.accentBarWidthTopPick
          : CartridgePhysics.accentBarWidth;
      return Container(width: width, color: color);
    }
    // Striped RISKY accent: a solid tier bar with decorative accent stripes
    // painted over it. A CustomPaint 45° hatch is nice-to-have; a striped bar
    // already reads as "loudest" (do not gold-plate — match effort to risk).
    return SizedBox(
      width: CartridgePhysics.accentBarWidthRisky,
      child: CustomPaint(painter: _HatchPainter(base: color, stripe: accent)),
    );
  }
}

/// The static `#1` rank marker for the top pick (AC#1) — the NON-motion,
/// NON-color rank cue that carries the top pick when Reduce Motion is on (AC#3;
/// review-accessibility.md:82-85). A tiny pixel pill on the SAFE fill, beside the
/// tier badge. Purely decorative for the screen reader (the row's merged label
/// already says "Top pick.") — the parent `excludeSemantics` silences it.
class _TopPickMarker extends StatelessWidget {
  const _TopPickMarker({required this.colors});

  final CartridgeColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: CartridgePhysics.s1,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: colors.tierSafe,
        border: CartridgePhysics.cartridgeBorder(
          colors.ink,
          width: CartridgePhysics.borderWidthChip,
        ),
      ),
      child: Text(
        '#1',
        style: CartridgeTypography.badge.copyWith(color: colors.paper),
      ),
    );
  }
}

/// Capitalize a lowercase type slug's first letter for the spoken label
/// (`fighting` → `Fighting`). Display/announce-only — the canonical key stays the
/// lowercase slug (AD-4).
String _capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// Lower-case a sentence's first letter so a reused subline flows mid-announce
/// (`Resists both its STABs` → `resists both its STABs`).
String _lowerFirst(String s) =>
    s.isEmpty ? s : s[0].toLowerCase() + s.substring(1);

/// Decorative 45° hatch for the RISKY accent bar (decorative ONLY — never behind
/// text). Cheap: a solid base fill plus a few diagonal stripes.
class _HatchPainter extends CustomPainter {
  _HatchPainter({required this.base, required this.stripe});

  final Color base;
  final Color stripe;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = base);
    final stripePaint = Paint()
      ..color = stripe
      ..strokeWidth = 3;
    canvas.save();
    canvas.clipRect(rect);
    // Diagonal stripes every 8px across the bar's height span.
    for (double d = -size.height; d < size.width + size.height; d += 8) {
      canvas.drawLine(
        Offset(d, size.height),
        Offset(d + size.height, 0),
        stripePaint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_HatchPainter oldDelegate) =>
      oldDelegate.base != base || oldDelegate.stripe != stripe;
}

/// The tier badge: icon + word on the tier fill, text color from
/// [tierBadgeTextColor] (white for SAFE/GOOD/RISKY; fixed olive ink for EVEN).
class _TierBadge extends StatelessWidget {
  const _TierBadge({required this.word, required this.icon, required this.fill});

  final String word;
  final String icon;
  final Color fill;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CartridgeColors>()!;
    final textColor = tierBadgeTextColor(word);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: CartridgePhysics.s2,
        vertical: CartridgePhysics.s1,
      ),
      decoration: BoxDecoration(
        color: fill,
        border: CartridgePhysics.cartridgeBorder(
          colors.ink,
          width: CartridgePhysics.borderWidthChip,
        ),
        boxShadow: [
          CartridgePhysics.cartridgeShadow(
            colors.shadow,
            offset: CartridgePhysics.offsetSmall,
          ),
        ],
      ),
      // Icon + word are SEPARATE Text widgets on purpose: the emoji renders via
      // platform font fallback (not PS2P) and is brittle to assert, so tests
      // match the WORD alone (`find.text('RISKY')`) — which only works if the
      // word is its own Text, not concatenated with the glyph.
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: CartridgeTypography.badge.copyWith(color: textColor)),
          const SizedBox(width: CartridgePhysics.s1),
          Text(word, style: CartridgeTypography.badge.copyWith(color: textColor)),
        ],
      ),
    );
  }
}
