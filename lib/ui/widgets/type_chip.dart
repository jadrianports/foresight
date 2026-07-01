import 'package:flutter/material.dart';

import '../../theme/cartridge_colors.dart';
import '../../theme/cartridge_physics.dart';
import '../../theme/cartridge_typography.dart';
import '../../theme/type_colors.dart';

/// A single Pokémon type chip: the all-caps type label on its canonical fill.
///
/// The fill is **theme-independent** (a Fire chip is the same orange in light
/// and dark) — [kTypeColors] and [typeChipTextColor] are fixed tokens, read by
/// lowercase [slug], NOT the brightness `ink`. Only the block-shadow (and border
/// ink) come from the theme extension.
///
/// Cartridge physics: 2px ink border, a small `2,2` zero-blur block-shadow,
/// square corners, label in [CartridgeTypography.badge] (Press Start 2P, 10px
/// floor — the 18 slugs all fit, so no clip-detection here; that polish is
/// Story 3.4/3.8).
class TypeChip extends StatelessWidget {
  const TypeChip(this.slug, {super.key});

  /// A lowercase PokeAPI type slug (`fire`, `dark`, …) — a valid [kTypeColors]
  /// key. Capitalization is display-only; never pass a display string here.
  final String slug;

  @override
  Widget build(BuildContext context) {
    final fill = kTypeColors[slug];
    // The DB guarantees the 18-slug vocabulary, so a miss here only ever means a
    // corrupt row — fail loud rather than silently inking an unknown chip
    // (deferred-work.md hardening note; AD-7 posture).
    if (fill == null) {
      throw ArgumentError.value(slug, 'slug', 'not one of the 18 type slugs');
    }

    final colors = Theme.of(context).extension<CartridgeColors>()!;

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
      child: Text(
        slug.toUpperCase(),
        style: CartridgeTypography.badge.copyWith(color: typeChipTextColor(slug)),
      ),
    );
  }
}
