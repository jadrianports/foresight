import 'package:flutter/material.dart';

import '../../data/pokemon_queries.dart';
import '../../theme/cartridge_colors.dart';
import '../../theme/cartridge_physics.dart';
import '../../theme/cartridge_typography.dart';
import 'type_chip.dart';

/// The Result screen's header card: the opponent's pixel sprite, its name, and
/// its type chips — the "who am I fighting" anchor above the ranked answer
/// (Story 3.4 AC#2).
///
/// Composes the same primitives as [SpriteTile] but does NOT reuse it (the grid
/// tile is name-below-sprite, square, 3.1-shaped; the header is a larger card).
/// The sprite is used VERBATIM from [spritePath] (AD-4) and degrades SOFT: a
/// missing/undecodable PNG swaps to name + chips via `errorBuilder`, never a
/// broken tile or thrown exception (AD-7). Type chips are the canonical
/// [TypeChip] (18-type palette at ≥4.5:1) — never re-implemented here (AC#7).
class OpponentCard extends StatelessWidget {
  const OpponentCard(this.opponent, {super.key});

  final PokemonListItem opponent;

  /// Sprite edge in logical px (DESIGN opponent-card "sprite 74px").
  static const double _spriteSize = 74;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CartridgeColors>()!;

    return Container(
      padding: const EdgeInsets.all(CartridgePhysics.s4),
      decoration: BoxDecoration(
        color: colors.surface,
        border: CartridgePhysics.cartridgeBorder(colors.ink),
        boxShadow: [CartridgePhysics.cartridgeShadow(colors.shadow)],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: _spriteSize,
            height: _spriteSize,
            child: Image.asset(
              opponent.spritePath,
              filterQuality: CartridgePhysics.spriteFilterQuality,
              fit: BoxFit.contain,
              semanticLabel: opponent.name,
              // The sprite is the ONE thing that fails soft (AD-7): a missing PNG
              // collapses the sprite slot, leaving name + chips to identify the
              // mon — this is the degrade path the widget test exercises.
              errorBuilder: (context, error, stackTrace) =>
                  const SizedBox.shrink(),
            ),
          ),
          const SizedBox(width: CartridgePhysics.s4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  opponent.name,
                  style:
                      CartridgeTypography.bodyLg.copyWith(color: colors.ink),
                ),
                const SizedBox(height: CartridgePhysics.s2),
                Wrap(
                  spacing: CartridgePhysics.s1,
                  runSpacing: CartridgePhysics.s1,
                  children: [
                    for (final slug in opponent.types) TypeChip(slug),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
