import 'package:flutter/material.dart';

import '../../theme/cartridge_colors.dart';
import '../../theme/cartridge_physics.dart';
import '../../theme/cartridge_typography.dart';

/// The small `{components.form-badge}` chip that marks a typing-distinct
/// alternate form (Story 3.3) — the grid `itemBuilder` overhangs it on the tile's
/// top-right, but the badge itself is a plain, position-agnostic primitive.
///
/// Structurally this is [TypeChip] with a FIXED fill: `primaryYellow` ground,
/// `ink` text + 2px border, the `2,2` zero-blur block-shadow, square corners, and
/// the label in [CartridgeTypography.badge] (Press Start 2P). The fill reads off
/// the theme extension so it brightens in dark mode (DESIGN §Color "the form
/// badge… In dark mode they brighten") — unlike a [TypeChip], whose per-type fill
/// is theme-independent.
///
/// THE label is DATA-DRIVEN (AC#3): [label] is whatever `form_label` the row
/// carries — `Alola`, `Galar`, `Hisui`, `Mega X`, `Paldea`, … The badge does NOT
/// know or whitelist the label set; it paints an arbitrary string. Modelling it
/// as an enum/`switch` over the epic's five named labels would silently drop
/// every Hisui/Paldea tile — the exact silently-wrong-output class this project
/// fails loud against. The data, never a Dart constant, decides what shows.
///
/// [label] is the exact `PokemonListItem.formLabel` (AD-4 — never reconstructed
/// from the slug). It is up-cased HERE for display only, the same
/// display-capitalization [TypeChip] applies to a lowercase type slug; the
/// underlying `form_label` is the source of truth. The null-check + overlay
/// decision live at the call site — [FormBadge] receives an already-non-null,
/// non-empty label.
class FormBadge extends StatelessWidget {
  const FormBadge(this.label, {super.key});

  /// The exact `form_label` string (`Alola`/`Mega X`/`Hisui`/…). Up-cased for
  /// display; never derived from the slug (AD-4).
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CartridgeColors>()!;

    // Announce the form once (AC#5c): "Alola form", "Mega X form". The visual
    // chip is up-cased for display only; the spoken label uses the verbatim
    // `form_label` (AD-4).
    return Semantics(
      label: '$label form',
      child: Container(
        // Snug: it's a corner overhang, not a full row — s1 horizontal, a hair
        // vertical (Task 1 spec) keeps the pixel chip tight.
        padding: const EdgeInsets.symmetric(
          horizontal: CartridgePhysics.s1,
          vertical: 2,
        ),
        decoration: BoxDecoration(
          color: colors.primaryYellow,
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
        // Story 3.8 AC#7 (resolves the 3.3 deferral): CLAMP the pixel-text scale
        // so a large OS text setting GROWS the badge but can't inflate "MEGA X"
        // past its overhang. The chip shrink-wraps its content, so with the cap
        // the whole (single-line) label stays inside — no truncated trailing word.
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: CartridgePhysics.maxPixelTextScale,
          child: Text(
            // Display-up-cased only (AC#2). Single line: softWrap:false stops a
            // two-word label (e.g. "Mega X") word-wrapping at the space and
            // losing the trailing word under a narrow constraint (maxLines:1
            // alone would silently render "MEGA" — an AC#2 verbatim violation).
            label.toUpperCase(),
            style: CartridgeTypography.badge.copyWith(color: colors.ink),
            softWrap: false,
            maxLines: 1,
          ),
        ),
      ),
    );
  }
}
