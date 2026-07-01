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

    return Container(
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
      child: Text(
        // Display-up-cased only (AC#2). maxLines: 1 is the cheap accessibility
        // baseline — the scaled-badge reflow/no-clip audit is Story 3.8.
        label.toUpperCase(),
        style: CartridgeTypography.badge.copyWith(color: colors.ink),
        maxLines: 1,
      ),
    );
  }
}
