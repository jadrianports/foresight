import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/pokemon_queries.dart';
import '../engine/ranking.dart';
import '../engine/type_chart.dart';
import '../engine/typing.dart';
import '../settings_controller.dart';
import '../theme/cartridge_colors.dart';
import '../theme/cartridge_physics.dart';
import '../theme/cartridge_typography.dart';
import 'result_state.dart';
import 'widgets/honest_banner.dart';
import 'widgets/opponent_card.dart';
import 'widgets/sort_toggle.dart';
import 'widgets/tier_result_row.dart';

/// Result: tap an opponent → lead with the ranked attacking-type answer
/// (Story 3.4). The first engine-consuming screen — opponent header card → sort
/// toggle → "USE THESE TYPES" → ranked tier rows.
///
/// Renders SYNCHRONOUSLY on the first frame from already-injected data (NFR2):
/// `rank(...)` is a pure function and the [chart] was read once in `main()`, so
/// there is NO `FutureBuilder`, spinner, or loading branch. The UI is purely
/// presentational — it renders the engine's order and tier labels verbatim and
/// never re-sorts, re-filters, or re-derives a tier (AD-9).
///
/// Sticky sort (Story 3.6): the row order is driven by the live `SortMode` read
/// from the root [SettingsController] (`context.watch`). Tapping the [SortToggle]
/// writes the new mode (`context.read...setSortMode`), which notifies → this
/// `build` re-runs → `rank(...)` re-orders the SAME list in place (no new route).
/// The mode persists across launches via `shared_preferences` (AD-5).
///
/// All-fragile (Story 3.5): when EVERY pick is RISKY (`isAllFragile`), the screen
/// LEADS with one honest [HonestBanner] instead of a wall of ⚠ rows. The rows
/// then follow in the live `SortMode`. The Story 3.5 special-case hardest-hitting
/// re-rank is SUBSUMED here: an all-RISKY list is ONE tier, and within one tier
/// `safestFirst ≡ hardestHitting` (`_comparatorFor` reduces both to offense-desc →
/// slug-asc), so the banner's "lead with the hardest hit" intent holds under
/// EITHER toggle position (Story 3.5 AC#2 preserved) with a single `rank(...)`.
///
/// Scope fence: no recents write (3.7), no top-pick pulse / `Semantics` /
/// dynamic-type / ≥44pt audit (3.8), no breakdown link (4.1), no theme slice /
/// Settings screen (4.2), no new dep beyond `provider`. An empty `rank` result
/// (no super-effective survivor) is NOT the all-fragile case (`isAllFragile([])`
/// is false): it keeps Story 3.4's header + zero-rows + no-banner behavior and
/// shows NO toggle (nothing to re-sort — AC#6).
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

    // The live sort choice — `watch` so a toggle notify rebuilds this screen and
    // re-orders in place (AC#1/#4). The engine owns BOTH orderings; the UI only
    // chooses one and never sorts itself.
    final sortMode = context.watch<SettingsController>().sortMode;

    // Pure, synchronous — the whole point of injecting the chart (NFR2). A []
    // result is a legitimate empty state (rank never throws for no survivors);
    // a corrupt chart cell still throws MissingChartEntry LOUDLY (AD-7).
    final picks = rank(Typing(opponent.types), chart, sortMode);
    // Order-independent: `isAllFragile` uses `every`, so it is the same for
    // either sort position (AC#5).
    final allFragile = isAllFragile(picks);

    return Scaffold(
      appBar: AppBar(title: const Text('FORESIGHT')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(CartridgePhysics.s4),
          children: [
            OpponentCard(opponent),
            const SizedBox(height: CartridgePhysics.s4),
            // The sort toggle sits directly under the card, its spec'd home
            // (EXPERIENCE.md:74). Shown ONLY when there are rows — the degenerate
            // empty result has nothing to re-sort (AC#6).
            if (picks.isNotEmpty) ...[
              SortToggle(
                mode: sortMode,
                onChanged: (m) =>
                    context.read<SettingsController>().setSortMode(m),
              ),
              const SizedBox(height: CartridgePhysics.s4),
            ],
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
            // The list order IS the engine's order for the live `sortMode` —
            // rendered, never re-sorted by the UI.
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
