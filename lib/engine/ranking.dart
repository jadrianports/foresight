import 'offense.dart';
import 'stab_risk.dart';
import 'type_chart.dart';
import 'typing.dart';

/// The AD-9 safety tier the engine emits for one surviving pick — the abstract LABEL the
/// UI (Epic 3) renders as `SAFE/GOOD/EVEN/RISKY` + icon + word. The UI NEVER re-derives a
/// tier from a multiplier; the engine already decided it here.
///
/// Declaration order IS severity order (safest → riskiest), so `Tier.index` is directly the
/// safest-first ordinal — no separate ordering map (NFR6). No UI concern (color/icon/copy)
/// lives on this enum: those are DESIGN tokens in `lib/ui`/`lib/theme`, and `lib/engine/` is
/// sealed pure Dart with no theme knowledge (AD-2). [AD-9; PRD §4.3 tier table]
enum Tier { safe, good, even, risky }

/// The two orderings the caller can apply to the ONE ranked list (never two lists/screens).
///
/// [safestFirst] (the default) leads with the safest tier; [hardestHitting] leads with raw
/// offense. The enum is the engine's pure ranking vocabulary; PERSISTING the choice is
/// Epic 3's `SettingsController` → `shared_preferences` (Story 3.6), NOT this story. [AD-9]
enum SortMode { safestFirst, hardestHitting }

/// One ranked pick: a surviving attacking type with its offense, its AD-9 tier, and the
/// un-collapsed per-STAB defensive data it was tiered from.
///
/// The whole [stabRisk] rides along (never pre-flattened): the tier is the engine's
/// *decision* over that data, but the UI (Stories 3.4/3.5) still needs the per-STAB hits to
/// write honest sublines ("resists its STAB") and to detect the all-fragile banner
/// condition. Hand-written `==`/`hashCode`/`toString` mirror `OffensePick`/`StabHit`/`Typing`
/// (no `equatable`, no `package:flutter`) — tests compare and order these, so structural
/// equality is required (Story 2.2 review: a value object missing `==` silently breaks
/// downstream comparison). [AD-9; lib/engine/stab_risk.dart; NFR6]
class RankedPick {
  RankedPick(this.attackingType, this.offense, this.tier, this.stabRisk);

  /// The surviving attacking type — a lowercase slug.
  final String attackingType;

  /// Forward-direction offense into the opponent's full typing — one of `{2, 4}` (the
  /// survivor already passed the ≥ 2× gate in `candidateAnswers`).
  final double offense;

  /// The AD-9 safety tier, classified per-STAB from [stabRisk] (never a collapsed value).
  final Tier tier;

  /// The un-collapsed per-STAB defensive result the tier was decided from — carried intact
  /// for the UI's honest subline + all-fragile banner (Epic 3), not flattened to a number.
  final StabRisk stabRisk;

  @override
  bool operator ==(Object other) =>
      other is RankedPick &&
      other.attackingType == attackingType &&
      other.offense == offense &&
      other.tier == tier &&
      other.stabRisk == stabRisk;

  @override
  int get hashCode => Object.hash(attackingType, offense, tier, stabRisk);

  @override
  String toString() =>
      'RankedPick($attackingType → ${offense}x, ${tier.name}, $stabRisk)';
}

/// Classifies a survivor's per-STAB defensive result into one AD-9 [Tier].
///
/// THE AD-9 KEYSTONE: classify from the *list* of per-STAB multipliers, NEVER from a single
/// collapsed worst/max value. The canonical case this protects — Fairy vs Tyranitar
/// (Rock/Dark): Fairy is neutral to Rock (1×) and resists Dark (0.5×) → GOOD; a naive
/// worst-multiplier collapse (max = 1× → EVEN) or an "any resist ⇒ SAFE" shortcut gets it
/// WRONG. Each `StabHit.multiplier` is a SINGLE chart lookup (opponent STAB → mono proxy),
/// so it is exactly one of `{0, 0.5, 1, 2}` — no 4× on defense — and the comparisons are
/// exact literals with no epsilon (products/rounding never enter here). [AD-9; PRD §4.3;
/// lib/engine/stab_risk.dart]
///
/// Decision order (RISKY checked FIRST — a single weakness disqualifies every safer tier):
///   - **RISKY** — any hit `>= 2.0` (weak to ≥ 1 STAB).
///   - **SAFE**  — every hit `<= 0.5` (resists or is immune to ALL STABs; 0× counts).
///   - **GOOD**  — at least one hit `<= 0.5` (resists ≥ 1) with the rest neutral and no
///                 weakness (the `>= 2.0` case is already excluded above).
///   - **EVEN**  — every hit `== 1.0` (neutral to all) — the exhaustive fall-through.
///
/// Fail LOUD on off-contract input instead of silently mislabeling (AD-7): an empty `hits`
/// list makes `every(<= 0.5)` vacuously true → SAFE (safest, from zero data), and an
/// out-of-domain multiplier (NaN, or a bad chart cell like `1.5`) falls through to EVEN —
/// either is silently-wrong battle advice. `stabRiskFor` guarantees 1–2 hits each in
/// `{0, 0.5, 1, 2}`; if that ever slips, throw rather than guess.
Tier _classify(StabRisk risk) {
  final multipliers = [for (final hit in risk.hits) hit.multiplier];
  if (multipliers.isEmpty ||
      multipliers.any((m) => m != 0.0 && m != 0.5 && m != 1.0 && m != 2.0)) {
    throw StateError(
        '_classify: off-contract StabRisk.hits $multipliers (expected 1–2 of {0, 0.5, 1, 2})');
  }
  if (multipliers.any((m) => m >= 2.0)) return Tier.risky;
  if (multipliers.every((m) => m <= 0.5)) return Tier.safe;
  if (multipliers.any((m) => m <= 0.5)) return Tier.good;
  return Tier.even;
}

/// Ranks the offense survivors against [opponentTyping] into an ordered, per-STAB-tiered
/// list — the pure public entry point of `lib/engine/` (FR10 capstone).
///
/// Pure Dart: no `ChangeNotifier`, controller, widget, DB access, or `Future`. It COMPOSES
/// the existing primitives and adds ONLY tier classification + ordering:
///   1. `candidateAnswers(opponentTyping, chart)` — the offense-gated survivors (0× removed,
///      ≥ 2× only). Do NOT re-derive or re-gate the universe here (AD-2, single source).
///   2. per survivor, `stabRiskFor(...)` → its un-collapsed per-STAB defense → `_classify`.
///   3. order per [sortMode] with a TOTAL, deterministic comparator (`List.sort` is not
///      stable, so ties are broken by `attackingType` slug ascending → byte-stable output).
///
/// - `SortMode.safestFirst`: tier asc (SAFE→RISKY), then offense **desc**, then slug asc.
/// - `SortMode.hardestHitting`: offense **desc**, then slug asc — tier is IGNORED for
///   ordering, but every `RankedPick` STILL carries its correct `tier` + `stabRisk` (AC#4).
///
/// No survivors → returns `[]` (a legitimate empty *state*, NOT a data-contract violation —
/// Epic 3 renders honest copy for it; do NOT throw). A missing `(attacking, defending)`
/// chart row still throws [MissingChartEntry] LOUDLY through the primitives (AD-7) — the
/// calls are deliberately not wrapped in `try/catch` or `?? 1.0`. [AD-9; AD-2; AD-7; NFR7]
List<RankedPick> rank(
    Typing opponentTyping, TypeChart chart, SortMode sortMode) {
  final picks = <RankedPick>[
    for (final survivor in candidateAnswers(opponentTyping, chart))
      _rankOne(survivor, opponentTyping, chart),
  ];
  picks.sort(_comparatorFor(sortMode));
  return picks;
}

RankedPick _rankOne(
    OffensePick survivor, Typing opponentTyping, TypeChart chart) {
  final risk = stabRiskFor(survivor.attackingType, opponentTyping, chart);
  return RankedPick(
      survivor.attackingType, survivor.offense, _classify(risk), risk);
}

/// A total comparator for [sortMode], deterministic down to a slug tiebreak so equal-key
/// picks come out in a fixed order (`List.sort` gives no stability guarantee).
int Function(RankedPick, RankedPick) _comparatorFor(SortMode sortMode) {
  switch (sortMode) {
    case SortMode.safestFirst:
      // Tier asc (SAFE #1), then the bigger hit leads within a tier (PRD §4.3 "privilege
      // offense"), then slug asc as the stable tiebreak.
      return (a, b) {
        final byTier = a.tier.index.compareTo(b.tier.index);
        if (byTier != 0) return byTier;
        final byOffense = b.offense.compareTo(a.offense);
        if (byOffense != 0) return byOffense;
        return a.attackingType.compareTo(b.attackingType);
      };
    case SortMode.hardestHitting:
      // Offense desc across all picks (tier ignored for ORDERING but still attached), then
      // slug asc as the stable tiebreak.
      return (a, b) {
        final byOffense = b.offense.compareTo(a.offense);
        if (byOffense != 0) return byOffense;
        return a.attackingType.compareTo(b.attackingType);
      };
  }
}
