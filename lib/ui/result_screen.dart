import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/pokemon_queries.dart';
import '../engine/ranking.dart';
import '../engine/type_chart.dart';
import '../engine/typing.dart';
import '../recents_controller.dart';
import '../settings_controller.dart';
import '../theme/cartridge_colors.dart';
import '../theme/cartridge_physics.dart';
import '../theme/cartridge_typography.dart';
import 'result_state.dart';
import 'widgets/honest_banner.dart';
import 'widgets/opponent_card.dart';
import 'widgets/sort_toggle.dart';
import 'widgets/tier_result_row.dart';
import 'widgets/top_pick_halo.dart';

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
/// Recents (Story 3.7): viewing this screen RECORDS the opponent to
/// `recent_views` via the root [RecentsController] (AD-5/AD-6). It fires exactly
/// ONCE per mount — scheduled from `initState` via a post-frame callback, NOT in
/// `build` — because `build` re-runs on every sort toggle (`context.watch`
/// above), and recording there would bump `viewed_at` and churn the strip on
/// each toggle. Post-frame so the controller's `notifyListeners` fires AFTER the
/// first frame (a notify DURING build throws). `context.read` — an action, not a
/// listen.
///
/// Top pick (Story 3.8): when the ranked list LEADS with a SAFE pick
/// (`picks.first.tier == Tier.safe`), row index 0 gets the top-pick treatment —
/// a wider accent bar + a static `#1` marker (`isTopPick`) and a single
/// SAFE-colored [TopPickHalo] pulse (the app's ONE animation, reduce-motion
/// gated). Position-based: it marks the LEAD the user is looking at, so in
/// hardest-hitting it appears only if the hardest hitter is itself SAFE (no
/// "first SAFE anywhere" scan). No SAFE lead → no row gets it.
///
/// Scope fence: no breakdown link (4.1), no theme slice / Settings screen (4.2),
/// no new dep beyond `provider`. An empty `rank` result (no super-effective survivor) is
/// NOT the all-fragile case (`isAllFragile([])` is false): it keeps Story 3.4's
/// header + zero-rows + no-banner behavior and shows NO toggle (nothing to
/// re-sort — AC#6). The recents write still fires for such an opponent — the user
/// DID view it.
class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key, required this.opponent, required this.chart});

  /// The tapped opponent, carried verbatim from the grid — its `types` ARE the
  /// `rank` input; we never re-query the DB (AD-6).
  final PokemonListItem opponent;

  /// The injected in-memory type chart `rank` runs against.
  final TypeChart chart;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  @override
  void initState() {
    super.initState();
    // Record ONCE per mount (AC#8). Post-frame so the controller notify lands
    // after the first frame (never notify-during-build → no "setState called
    // during build" throw), and so it never repeats on a sort-toggle rebuild.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<RecentsController>().recordView(widget.opponent);
    });
  }

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
    final picks = rank(Typing(widget.opponent.types), widget.chart, sortMode);
    // Order-independent: `isAllFragile` uses `every`, so it is the same for
    // either sort position (AC#5).
    final allFragile = isAllFragile(picks);
    // Top pick (Story 3.8 AC#1/#2): the treatment marks row 0 exactly when the
    // LEAD is SAFE. Position-based — never a "first SAFE anywhere" scan — so in
    // hardestHitting it shows only if the hardest hitter is itself SAFE.
    final hasTopPick = picks.isNotEmpty && picks.first.tier == Tier.safe;

    return Scaffold(
      appBar: AppBar(title: const Text('FORESIGHT')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(CartridgePhysics.s4),
          children: [
            OpponentCard(widget.opponent),
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
            // The section header is a semantics HEADER so a screen reader can jump
            // to it (AC#4). `excludeSemantics` false — it keeps its own Text node.
            Semantics(
              header: true,
              child: Text(
                'USE THESE TYPES',
                style: CartridgeTypography.sectionHeader
                    .copyWith(color: colors.ink),
              ),
            ),
            const SizedBox(height: CartridgePhysics.s3),
            // The list order IS the engine's order for the live `sortMode` —
            // rendered, never re-sorted by the UI. Row 0 gets the top-pick
            // treatment when the lead is SAFE (AC#1): `isTopPick` (wider bar + #1
            // marker) plus the single SAFE-colored [TopPickHalo] pulse.
            for (var i = 0; i < picks.length; i++) ...[
              if (hasTopPick && i == 0)
                TopPickHalo(child: TierResultRow(picks[i], isTopPick: true))
              else
                TierResultRow(picks[i]),
              const SizedBox(height: CartridgePhysics.s3),
            ],
          ],
        ),
      ),
    );
  }
}
