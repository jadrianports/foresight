import 'package:flutter/material.dart';

import '../../data/pokemon_queries.dart';
import '../../theme/cartridge_colors.dart';
import '../../theme/cartridge_physics.dart';
import '../../theme/cartridge_typography.dart';
import 'type_chip.dart';

/// One grid tile: a pixel sprite above the Pokémon's name, in a Cartridge card.
///
/// Pure display — no `onTap`/navigation (Story 3.4 wraps it) and no form badge
/// (Story 3.3 wraps it). Keeping it un-tapped now avoids a dead tap target.
///
/// THE degrade contract (AC#4 / AD-7): the sprite is the ONE thing that fails
/// soft. `Image.asset`'s `errorBuilder` swaps a missing/undecodable PNG for the
/// name + type chips — never a broken tile, grey box, or thrown exception. Data
/// violations still fail loud elsewhere; only sprites degrade.
class SpriteTile extends StatelessWidget {
  const SpriteTile(this.item, {super.key});

  final PokemonListItem item;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CartridgeColors>()!;

    return Container(
      padding: const EdgeInsets.all(CartridgePhysics.s2),
      decoration: BoxDecoration(
        color: colors.surface,
        border: CartridgePhysics.cartridgeBorder(colors.ink),
        borderRadius: BorderRadius.circular(CartridgePhysics.radiusTile),
        boxShadow: [
          CartridgePhysics.cartridgeShadow(colors.shadow),
        ],
      ),
      // The Column fills the grid cell's (bounded) height: Expanded flexes the
      // sprite slot to fill the space above the name. No mainAxisSize.min — it
      // would contradict the Expanded (which forces max) and read as a promise
      // this tile shrink-wraps, which it doesn't.
      child: Column(
        children: [
          Expanded(
            child: Center(
              // sprite_path is used VERBATIM (AD-4) — never rebuilt from the
              // slug/form. FilterQuality.none = the pixelated rule.
              child: Image.asset(
                item.spritePath,
                filterQuality: CartridgePhysics.spriteFilterQuality,
                fit: BoxFit.contain,
                semanticLabel: item.name,
                errorBuilder: (context, error, stackTrace) => _degrade(colors),
              ),
            ),
          ),
          const SizedBox(height: CartridgePhysics.s1),
          Text(
            item.name,
            style: CartridgeTypography.tileName.copyWith(color: colors.ink),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// AC#4 soft-fallback: name is already shown below; here we replace the sprite
  /// slot with the opponent's type chips so the tile still identifies the mon.
  Widget _degrade(CartridgeColors colors) {
    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: CartridgePhysics.s1,
        runSpacing: CartridgePhysics.s1,
        children: [
          for (final slug in item.types) TypeChip(slug),
        ],
      ),
    );
  }
}
