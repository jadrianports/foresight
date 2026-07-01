import 'package:flutter/material.dart';

import '../../data/pokemon_queries.dart';
import '../../theme/cartridge_colors.dart';
import '../../theme/cartridge_physics.dart';
import '../../theme/cartridge_typography.dart';
import 'type_chip.dart';

/// One recent-strip tile: a 64px pixel sprite above the Pokémon name.
///
/// Deliberately LIGHTER than [SpriteTile] — the DESIGN `recent-tile` token
/// declares ONLY sprite-height / name-font / name-color (no border/shadow keys,
/// unlike `sprite-tile`), so this is a bare sprite+name `Column`, not a bordered
/// Cartridge card.
///
/// Pure display — no `onTap`/navigation (HomeScreen wires the tap, AC#5). THE
/// degrade contract (AD-7), same as [SpriteTile]: a missing/undecodable sprite
/// swaps the sprite slot for the opponent's type chips (the name already shows
/// below) — never a broken tile or thrown exception. Only sprites degrade.
class RecentTile extends StatelessWidget {
  const RecentTile(this.item, {super.key});

  final PokemonListItem item;

  /// The DESIGN `recent-tile` sprite height (64px).
  static const double spriteHeight = 64;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CartridgeColors>()!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: spriteHeight,
          // sprite_path is used VERBATIM (AD-4). FilterQuality.none = pixelated.
          child: Image.asset(
            item.spritePath,
            filterQuality: CartridgePhysics.spriteFilterQuality,
            fit: BoxFit.contain,
            semanticLabel: item.name,
            errorBuilder: (context, error, stackTrace) => _degrade(),
          ),
        ),
        const SizedBox(height: CartridgePhysics.s1),
        // Story 3.8 AC#7: this tile lives in a FIXED-height strip (92px), so the
        // name's scale is CLAMPED (the documented fixed-frame option) — it grows
        // with the OS setting but can't push the sprite+name Column past the
        // strip and clip. maxLines:1 ellipsis handles the horizontal axis.
        MediaQuery.withClampedTextScaling(
          maxScaleFactor: CartridgePhysics.maxPixelTextScale,
          child: Text(
            item.name,
            style: CartridgeTypography.tileName.copyWith(color: colors.ink),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  /// AD-7 soft-fallback: name is already shown below; replace the sprite slot
  /// with the opponent's type chips so the tile still identifies the mon.
  Widget _degrade() {
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
