import 'package:flutter/material.dart';

import '../data/pokemon_queries.dart';
import '../engine/ranking.dart';
import '../engine/type_chart.dart';
import '../engine/typing.dart';
import '../theme/cartridge_colors.dart';
import '../theme/cartridge_physics.dart';
import '../theme/cartridge_typography.dart';
import 'result_state.dart';
import 'widgets/honest_banner.dart';
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
/// All-fragile (Story 3.5): when EVERY pick is RISKY (`isAllFragile`), the screen
/// LEADS with one honest [HonestBanner] instead of a wall of ⚠ rows, and orders
/// the (still-shown) rows hardest-hitting. The order is an AUTOMATIC consequence
/// of all-RISKY — NOT a user sort control (that is Story 3.6).
///
/// Scope fence: no sort toggle / persisted sort (3.6), no recents write (3.7), no
/// top-pick pulse / `Semantics` / dynamic-type pass (3.8), no breakdown link
/// (4.1), no Provider/controller, no new dep. An empty `rank` result (no
/// super-effective survivor) is NOT the all-fragile case (`isAllFragile([])` is
/// false): it keeps Story 3.4's header + zero-rows + no-banner behavior (AC#4).
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
    final safest = rank(Typing(opponent.types), chart, SortMode.safestFirst);
    final allFragile = isAllFragile(safest);
    // When all-fragile, order the (still-shown) rows hardest-hitting (AC#2). The
    // second rank runs ONLY in the rare all-fragile case and is pure/cheap (≤18
    // candidates). Since an all-RISKY list is one tier, safestFirst and
    // hardestHitting are provably the same order — the re-rank makes the intent
    // explicit and is robust to any future within-tier ordering change. It is
    // NOT a sort control (that is Story 3.6).
    final picks = allFragile
        ? rank(Typing(opponent.types), chart, SortMode.hardestHitting)
        : safest;

    return Scaffold(
      appBar: AppBar(title: const Text('FORESIGHT')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(CartridgePhysics.s4),
          children: [
            OpponentCard(opponent),
            const SizedBox(height: CartridgePhysics.s4),
            // The honest banner LEADS the answer when every pick is fragile
            // (AC#1) — it does not suppress the rows; they still follow below.
            if (allFragile) ...[
              const HonestBanner(),
              const SizedBox(height: CartridgePhysics.s4),
            ],
            Text(
              'USE THESE TYPES',
              style: CartridgeTypography.sectionHeader
                  .copyWith(color: colors.ink),
            ),
            const SizedBox(height: CartridgePhysics.s3),
            // The list order IS the engine's order — rendered, never re-sorted.
            // Normal: safest-first (#1 = safest tier). All-fragile: hardest-
            // hitting (#1 = the biggest hit — lead with it).
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
