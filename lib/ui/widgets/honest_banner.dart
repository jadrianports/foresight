import 'package:flutter/material.dart';

import '../../theme/cartridge_colors.dart';
import '../../theme/cartridge_physics.dart';
import '../../theme/cartridge_typography.dart';

/// The all-fragile honest banner (Story 3.5): when EVERY super-effective pick is
/// RISKY, this single "loudest" card LEADS the answer instead of a wall of ⚠
/// rows — carrying the heading "NO CLEAN ANSWER" and the exact honest line
/// "No clean answer — you're trading blows. Lead with the hardest hit."
///
/// PURELY PRESENTATIONAL: it renders FIXED copy + theme tokens and takes NO
/// engine data — it does not re-run, re-filter, or re-classify the picks. The
/// caller ([ResultScreen]) owns the all-fragile decision (`isAllFragile`) and
/// only inserts this widget above the still-shown rows (AC#7). The copy is
/// load-bearing/verbatim (UX-DR9) — a real em-dash (U+2014), straight
/// apostrophe, trailing period — do not paraphrase.
///
/// Signature "loudest" treatment (AC#5): a 4px `tierRisky` border
/// (`borderWidthRisky`) + 5px block-shadow (`offsetLoud`) over `surface`.
///
/// ACCESSIBILITY (AC#5): the heading uses `tierRiskyText`, NOT `tierRisky` —
/// #C2410C at 10px on the near-white surface is 3.87:1 and FAILS WCAG small-text
/// contrast; `tierRiskyText` is the ratified ≥4.5:1-on-surface token whose doc
/// names "the honest-banner heading" as a consumer (the same fix already applied
/// to the RISKY row's type name). `tierRisky` is kept for the border + icon
/// (non-text signals, where the 4.5:1 floor does not apply). The message is
/// carried by WORDS at ≥4.5:1, never color alone; the ⚠ is decorative (NFR4).
class HonestBanner extends StatelessWidget {
  const HonestBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CartridgeColors>()!;

    return Container(
      padding: const EdgeInsets.all(CartridgePhysics.s3),
      decoration: BoxDecoration(
        color: colors.surface,
        border: CartridgePhysics.cartridgeBorder(
          colors.tierRisky,
          width: CartridgePhysics.borderWidthRisky,
        ),
        boxShadow: [
          CartridgePhysics.cartridgeShadow(
            colors.shadow,
            offset: CartridgePhysics.offsetLoud,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Decorative ⚠ — its OWN Text so it never concatenates into the
          // asserted heading/body strings; renders via platform font fallback
          // (not PS2P), so tests match the WORDS, never this glyph (NFR4).
          Text('⚠',
              style: CartridgeTypography.badge.copyWith(color: colors.tierRisky)),
          const SizedBox(width: CartridgePhysics.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Heading color is tierRiskyText (≥4.5:1), NOT tierRisky (AC#5).
                Text(
                  'NO CLEAN ANSWER',
                  style: CartridgeTypography.badge
                      .copyWith(color: colors.tierRiskyText),
                ),
                const SizedBox(height: CartridgePhysics.s2),
                Text(
                  "No clean answer — you're trading blows. Lead with the hardest hit.",
                  style: CartridgeTypography.body.copyWith(color: colors.ink),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
