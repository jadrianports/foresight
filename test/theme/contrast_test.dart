// Locks the WCAG AA contrast floor for every load-bearing color token pairing
// (NFR4). A single mistyped hex in a token would silently ship a chip or badge
// whose label fails contrast — invisible in a screenshot, caught here. We
// re-derive the ratio from first principles rather than trusting the DESIGN
// table's stated numbers, so the test fails if a token drifts from the table.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foresight/theme/cartridge_colors.dart';
import 'package:foresight/theme/type_colors.dart';

/// sRGB channel (0..1) → linear-light, per WCAG 2.x.
double _linearize(double channel) {
  return channel <= 0.03928
      ? channel / 12.92
      : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();
}

/// Relative luminance L = 0.2126R + 0.7152G + 0.0722B (linearized channels).
/// Flutter's `Color.r/.g/.b` are already normalized sRGB doubles in [0, 1].
double _relativeLuminance(Color c) {
  return 0.2126 * _linearize(c.r) +
      0.7152 * _linearize(c.g) +
      0.0722 * _linearize(c.b);
}

/// WCAG contrast ratio (lighter + 0.05) / (darker + 0.05), in [1, 21].
double contrastRatio(Color a, Color b) {
  final la = _relativeLuminance(a);
  final lb = _relativeLuminance(b);
  final lighter = math.max(la, lb);
  final darker = math.min(la, lb);
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  const aaNormal = 4.5;

  group('WCAG AA contrast floor (NFR4)', () {
    test('all 18 type-chip labels clear 4.5:1 on their canonical fill', () {
      expect(kTypeColors, hasLength(18));
      for (final entry in kTypeColors.entries) {
        final fill = entry.value;
        final text = typeChipTextColor(entry.key);
        final ratio = contrastRatio(fill, text);
        expect(
          ratio,
          greaterThanOrEqualTo(aaNormal),
          reason: 'type "${entry.key}" label contrast ${ratio.toStringAsFixed(2)}:1 '
              'is below the 4.5:1 floor',
        );
      }
    });

    test('the five dark fills take white text, the rest ink', () {
      const c = CartridgeColors.light;
      for (final slug in kTypeColors.keys) {
        final expected =
            kWhiteTextTypeFills.contains(slug) ? Colors.white : c.ink;
        expect(typeChipTextColor(slug), expected,
            reason: 'wrong label color rule for "$slug"');
      }
      expect(kWhiteTextTypeFills,
          <String>{'fighting', 'poison', 'ghost', 'dragon', 'dark'});
    });

    test('all 4 tier badges clear 4.5:1 with their production badge text color', () {
      const c = CartridgeColors.light;
      // Fills are theme-independent; drive the text color through the SAME
      // production rule Epic 3 will use (`tierBadgeTextColor`) so the test
      // catches a regression in that rule, not just hand-typed literals.
      final fills = <String, Color>{
        'SAFE': c.tierSafe,
        'GOOD': c.tierGood,
        'EVEN': c.tierEven,
        'RISKY': c.tierRisky,
      };
      fills.forEach((label, fill) {
        final ratio = contrastRatio(fill, tierBadgeTextColor(label));
        expect(
          ratio,
          greaterThanOrEqualTo(aaNormal),
          reason: '$label badge contrast ${ratio.toStringAsFixed(2)}:1 '
              'is below the 4.5:1 floor',
        );
      });
    });

    test('EVEN badge text is the FIXED ink — the brightness ink would fail dark', () {
      // The whole reason `tierEvenText` is fixed: the theme-correct dark ink on
      // the (theme-independent) yellow fill is a hard contrast fail. Lock both
      // the pass (fixed ink) and the trap (dark ink) so no one "simplifies"
      // EVEN's text back to `Theme...ink`.
      const even = CartridgeColors.light; // tierEven is identical light/dark.
      expect(tierBadgeTextColor('EVEN'), CartridgeColors.tierEvenText);
      expect(contrastRatio(even.tierEven, CartridgeColors.tierEvenText),
          greaterThanOrEqualTo(aaNormal));
      expect(contrastRatio(even.tierEven, CartridgeColors.dark.ink),
          lessThan(aaNormal),
          reason: 'dark theme ink on the yellow EVEN fill must NOT be used');
    });

    test('RISKY-as-text clears 4.5:1 on the surface in BOTH themes', () {
      // DESIGN result-row-risky/honest-banner render the tier-risky color as
      // load-bearing TEXT on `surface`, required ≥4.5:1 in both themes. The fill
      // is theme-independent but the surface is not, so the text token differs.
      for (final c in <CartridgeColors>[
        CartridgeColors.light,
        CartridgeColors.dark,
      ]) {
        final ratio = contrastRatio(c.tierRiskyText, c.surface);
        expect(
          ratio,
          greaterThanOrEqualTo(aaNormal),
          reason: 'RISKY text-on-surface contrast ${ratio.toStringAsFixed(2)}:1 '
              'is below the 4.5:1 floor',
        );
      }
    });

    test('chrome text (ink, inkMuted) clears 4.5:1 on paper + surface, both themes',
        () {
      // The everyday body/subline pairings DESIGN flags ≥4.5:1: primary ink and
      // muted ink (sublines/footnotes/empty-state) on both grounds. `inkMuted`
      // on light paper is the tightest at ~4.9:1 — guard it so a future paper or
      // ink-muted tweak can't silently regress it.
      for (final c in <CartridgeColors>[
        CartridgeColors.light,
        CartridgeColors.dark,
      ]) {
        for (final text in <Color>[c.ink, c.inkMuted]) {
          for (final ground in <Color>[c.paper, c.surface]) {
            final ratio = contrastRatio(text, ground);
            expect(
              ratio,
              greaterThanOrEqualTo(aaNormal),
              reason: 'chrome text contrast ${ratio.toStringAsFixed(2)}:1 '
                  'is below the 4.5:1 floor',
            );
          }
        }
      }
    });
  });
}
