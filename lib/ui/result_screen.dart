import 'package:flutter/material.dart';

import '../data/pokemon_queries.dart';
import '../engine/ranking.dart';
import '../engine/type_chart.dart';
import '../engine/typing.dart';
import '../theme/cartridge_colors.dart';
import '../theme/cartridge_physics.dart';
import '../theme/cartridge_typography.dart';
import 'widgets/opponent_card.dart';
import 'widgets/tier_result_row.dart';

/// Result: tap an opponent → lead with the ranked attacking-type answer
/// (Story 3.4). The first engine-consuming screen — opponent header card →
/// "USE THESE TYPES" → ranked tier rows, in the engine's safest-first order.
///
/// Renders SYNCHRONOUSLY on the first frame from already-injected data (NFR2):
/// `rank(...)` is a pure function and the [chart] was read once in `main()`, so
/// there is NO `FutureBuilder`, spinner, or loading branch. The UI is purely
/// presentational — it renders the engine's order and tier labels verbatim and
/// never re-sorts, re-filters, or re-derives a tier (AD-9).
///
/// Scope fence (AC#10): FIXED `SortMode.safestFirst` — no sort toggle (3.6), no
/// all-fragile banner (3.5), no recents write (3.7), no top-pick pulse /
/// `Semantics` / dynamic-type pass (3.8), no breakdown link (4.1), no
/// Provider/controller, no new dep. An empty `rank` result (no super-effective
/// survivor) renders the header + section with zero rows and does NOT crash.
class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key, required this.opponent, required this.chart});

  /// The tapped opponent, carried verbatim from the grid — its `types` ARE the
  /// `rank` input; we never re-query the DB (AD-6).
  final PokemonListItem opponent;

  /// The injected in-memory type chart `rank` runs against.
  final TypeChart chart;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CartridgeColors>()!;

    // Pure, synchronous — the whole point of injecting the chart (NFR2). A []
    // result is a legitimate empty state (rank never throws for no survivors);
    // a corrupt chart cell still throws MissingChartEntry LOUDLY (AD-7).
    final picks = rank(Typing(opponent.types), chart, SortMode.safestFirst);

    return Scaffold(
      appBar: AppBar(title: const Text('FORESIGHT')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(CartridgePhysics.s4),
          children: [
            OpponentCard(opponent),
            const SizedBox(height: CartridgePhysics.s4),
            Text(
              'USE THESE TYPES',
              style: CartridgeTypography.sectionHeader
                  .copyWith(color: colors.ink),
            ),
            const SizedBox(height: CartridgePhysics.s3),
            // The list order IS the engine's safest-first order — rendered, never
            // re-sorted. #1 (the top row) is the safest tier, offense-desc within.
            for (final pick in picks) ...[
              TierResultRow(pick),
              const SizedBox(height: CartridgePhysics.s3),
            ],
          ],
        ),
      ),
    );
  }
}
