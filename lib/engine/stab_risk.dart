import 'effectiveness.dart';
import 'type_chart.dart';
import 'typing.dart';

/// One opponent STAB type and the multiplier it deals into a mono-type proxy defender.
///
/// The pair is the load-bearing unit of [StabRisk]: keeping the [stabType] alongside its
/// [multiplier] (rather than a bare `double`) is what lets a dual-type opponent's two
/// STABs land in DIFFERENT defensive buckets without losing which STAB caused which
/// number (AD-9). Hand-written `==`/`hashCode`/`toString` mirror `Typing` (no `equatable`,
/// no `package:flutter`) and keep test failures readable.
class StabHit {
  StabHit(this.stabType, this.multiplier);

  /// The opponent's STAB type (a lowercase slug) acting as the attacker.
  final String stabType;

  /// How effective [stabType] is into the candidate's mono proxy — exactly one of
  /// `{0, 0.5, 1, 2}` (a single chart lookup, so no product/rounding).
  final double multiplier;

  @override
  bool operator ==(Object other) =>
      other is StabHit &&
      other.stabType == stabType &&
      other.multiplier == multiplier;

  @override
  int get hashCode => Object.hash(stabType, multiplier);

  @override
  String toString() => 'StabHit($stabType → ${multiplier}x)';
}

/// The opponent's per-STAB effectiveness into a mono-type proxy of one candidate
/// attacking type — the DEFENSIVE half of the §4.2 mono-type proxy model.
///
/// This is a *guaranteed-damage floor*, NOT a safety guarantee. It measures the
/// opponent's STAB (same-type) moves ONLY: a Pokémon always carries STAB, so this is the
/// damage you can count on taking back. Coverage moves live OUTSIDE this model and can
/// only make a low number WORSE, never better — so a low result means **low STAB risk**
/// ("resists its STAB"), and NEVER **total safety** ("takes nothing back"). This is the
/// origin of the EXPERIENCE honesty copy and the §4.2 footnote later surfaced on the
/// About screen (Story 4.2). [AC#3; PRD §4.2; AD-9]
///
/// The [hits] list is preserved PER STAB and never collapsed to a single worst/max value
/// — collapsing here would re-introduce the exact bug AD-9 exists to prevent (it would
/// mis-tier Tyranitar-vs-Fairy as EVEN instead of GOOD). The tier *decision* over this
/// list is Story 2.4's job; this object only hands 2.4 the un-collapsed data.
class StabRisk {
  StabRisk(this.candidateType, List<StabHit> hits)
      : hits = List.unmodifiable(hits);

  /// The candidate attacking type, modeled here as the mono proxy DEFENDER.
  final String candidateType;

  /// One entry per opponent STAB type, in the opponent's slot order (primary, secondary).
  /// Unmodifiable so the value object cannot be mutated after construction. A mono
  /// opponent yields one entry; a dual opponent yields two — and a 0× STAB is KEPT here
  /// (the 0× *offense* hard-filter is Story 2.3 and a separate concern).
  final List<StabHit> hits;

  @override
  bool operator ==(Object other) =>
      other is StabRisk &&
      other.candidateType == candidateType &&
      _hitsEqual(other.hits, hits);

  @override
  int get hashCode => Object.hash(candidateType, Object.hashAll(hits));

  @override
  String toString() => 'StabRisk($candidateType, $hits)';
}

/// Ordered element-wise comparison of two per-STAB hit lists (no `package:flutter`
/// collection helpers — `lib/engine/` depends on nothing but `dart:core`; AD-2). Mirrors
/// `Typing`'s slot-ordered equality so two `StabRisk`s match only when their STABs landed
/// in the same buckets in the same order.
bool _hitsEqual(List<StabHit> a, List<StabHit> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Computes, for a [candidateType] attacking pick, how hard the [opponentTyping]'s STABs
/// hit back into a mono proxy of that candidate — preserved per STAB.
///
/// Direction matters and is the correctness crux: STAB risk is the REVERSE of offense.
/// The opponent's STAB type is the ATTACKER; the candidate (as a mono proxy) is the
/// DEFENDER — `typeEffectiveness(opponentStabType, Typing.mono(candidateType), chart)`,
/// NOT `typeEffectiveness(candidateType, opponentTyping, chart)` (which is offense, Story
/// 2.1 / 2.3-2.4). A swapped direction compiles fine and silently computes the wrong
/// defensive math. [PRD §4.2 step 2; AD-9]
///
/// The opponent's STAB types ARE `opponentTyping.types` — every type a Pokémon has grants
/// STAB, so no move data is needed. Each per-STAB value goes through [typeEffectiveness],
/// so a missing `(attacking, defending)` chart row still throws [MissingChartEntry]
/// loudly (AD-7) — the calls are deliberately NOT wrapped in `try/catch` or `?? 1.0`.
StabRisk stabRiskFor(
    String candidateType, Typing opponentTyping, TypeChart chart) {
  final proxy = Typing.mono(candidateType);
  final hits = <StabHit>[
    for (final stabType in opponentTyping.types)
      StabHit(stabType, typeEffectiveness(stabType, proxy, chart)),
  ];
  return StabRisk(candidateType, hits);
}
