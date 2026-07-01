import 'package:flutter/material.dart';

import '../data/pokemon_queries.dart';
import '../theme/cartridge_colors.dart';
import '../theme/cartridge_physics.dart';
import '../theme/cartridge_typography.dart';
import 'widgets/sprite_tile.dart';

/// Home's default state (Story 3.1): the app-title wordmark above a full-dex
/// 3-column sprite grid. This is the opening of `lib/ui/` — search (3.2), the
/// form badge (3.3), tap→Result (3.4), the recent strip (3.5/3.7), and the sort
/// toggle (3.6) all layer on later; leave room for them but build none here.
///
/// [pokemon] is already-resolved data injected from the composition root
/// (`main()`) — the UI never queries the DB (AD-6). So there is NO
/// `FutureBuilder`, spinner, or loading branch anywhere (NFR2): the grid renders
/// synchronously on the first frame under the native splash.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.pokemon});

  /// The full bundled dex (~1100 items), ordered by id, injected by `main()`.
  final List<PokemonListItem> pokemon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CartridgeColors>()!;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(CartridgePhysics.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Home wordmark — "FORESIGHT" with the primary-red dot accent
              // (DESIGN app-title). This is the brand-shout at the top of Home.
              Padding(
                padding: const EdgeInsets.only(bottom: CartridgePhysics.s4),
                child: Text.rich(
                  TextSpan(
                    text: 'FORESIGHT',
                    children: [
                      TextSpan(
                        text: '.',
                        style: TextStyle(color: colors.primaryRed),
                      ),
                    ],
                  ),
                  style: CartridgeTypography.appTitle.copyWith(color: colors.ink),
                ),
              ),
              // GridView.builder lazily builds only visible tiles — mandatory for
              // the ~1100-item dex so first paint and scroll stay instant (NFR2).
              Expanded(
                child: GridView.builder(
                  padding: EdgeInsets.zero,
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: CartridgePhysics.s3,
                    crossAxisSpacing: CartridgePhysics.s3,
                    childAspectRatio: 0.82,
                  ),
                  itemCount: pokemon.length,
                  itemBuilder: (context, i) => SpriteTile(pokemon[i]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
