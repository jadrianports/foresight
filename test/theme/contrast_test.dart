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

    test('all 4 tier badges clear 4.5:1 with their badge text color', () {
      const c = CartridgeColors.light;
      // SAFE / GOOD / RISKY use white text; EVEN uses ink on yellow.
      final pairings = <String, ({Color fill, Color text})>{
        'SAFE': (fill: c.tierSafe, text: Colors.white),
        'GOOD': (fill: c.tierGood, text: Colors.white),
        'EVEN': (fill: c.tierEven, text: c.ink),
        'RISKY': (fill: c.tierRisky, text: Colors.white),
      };
      pairings.forEach((label, pair) {
        final ratio = contrastRatio(pair.fill, pair.text);
        expect(
          ratio,
          greaterThanOrEqualTo(aaNormal),
          reason: '$label badge contrast ${ratio.toStringAsFixed(2)}:1 '
              'is below the 4.5:1 floor',
        );
      });
    });
  });
}
