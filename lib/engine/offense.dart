import 'effectiveness.dart';
import 'type_chart.dart';
import 'typing.dart';

/// One surviving attacking type paired with its OFFENSE multiplier against the opponent —
/// the offense-gated unit the answer set is built from (the OFFENSIVE half of §4.2).
///
/// Carries offense ONLY. No tier label, no `StabRisk`, no defensive value: tiering and the
/// STAB integration are Story 2.4's `rank(...)`, which consumes these picks alongside
/// `stabRiskFor`. Hand-written `==`/`hashCode`/`toString` mirror `StabHit`/`Typing` (no
/// `equatable`, no `package:flutter`) — Story 2.4's `rank` and its tests compare and order
/// these, so structural equality is required (Story 2.2 review: a value object missing `==`
/// silently breaks downstream comparison). [PRD §4.2; NFR6]
class OffensePick {
  OffensePick(this.attackingType, this.offense);

  /// The surviving attacking type — a lowercase slug.
  final String attackingType;

  /// The candidate's forward-direction offense into the opponent's full typing — after the
  /// super-effective gate this is one of the SE values `{2, 4}` (a dual opponent both slots
  /// hit 2× yields 4×). Exact: products of `{0, 0.5, 1, 2}` are exact in IEEE-754.
  final double offense;

  @override
  bool operator ==(Object other) =>
      other is OffensePick &&
      other.attackingType == attackingType &&
      other.offense == offense;

  @override
  int get hashCode => Object.hash(attackingType, offense);

  @override
  String toString() => 'OffensePick($attackingType → ${offense}x)';
}

/// The offense-gated candidate answer set for [opponentTyping]: every attacking type in the
/// chart's universe whose offense is super-effective (≥ 2×), each carrying its multiplier.
///
/// Direction matters and is the correctness crux — this is the FORWARD direction, the
/// REVERSE of Story 2.2's STAB-risk. The candidate is the ATTACKER and the opponent's full
/// [opponentTyping] is the DEFENDER:
/// `typeEffectiveness(candidateType, opponentTyping, chart)` (dual defender → product, so
/// `2×·2× = 4×`), NOT `typeEffectiveness(opponentStabType, Typing.mono(candidate), chart)`
/// (that is 2.2's defensive STAB-risk). A swapped direction compiles and silently computes
/// the wrong thing. [PRD §4.2 step 1; AD-9]
///
/// The single `offense >= 2.0` predicate IS the answer-set definition — neutral-or-worse
/// (< 2×) types are "not answers" (PRD §4.3) — and it arithmetically subsumes the 0×
/// removal. The two rules stay legible on purpose, because they mean different things:
///   - **0× is REMOVED as a load-bearing SAFETY invariant** — a 0× pick deals literally zero
///     damage, so surfacing it (even last) is actively-harmful battle advice. It is filtered
///     out, never ranked low (project-context "0× is a hard filter, not a low rank").
///   - **≥ 2× is the ANSWER-SET definition** — only super-effective types are answers.
/// One clear `>= 2.0` (no redundant `!= 0` clause, the literal not a magic float; `{0,0.5,1,2}`
/// products are exact so `>=` needs no epsilon) plus this note is the right altitude.
///
/// The attacking-type UNIVERSE comes from `chart.attackingTypes` (derived from the injected
/// chart, AD-2) — never an embedded type list. Every offense value goes through
/// `typeEffectiveness` → `TypeChart.multiplierFor`, so a missing `(attacking, defending)`
/// row still throws [MissingChartEntry] loudly through the gate (AD-7) — the calls are NOT
/// wrapped in `try/catch` or `?? 1.0`; a swallowed miss could even slip a non-answer past
/// the gate as a silent 1×.
///
/// Ordering: the survivors are returned in `chart.attackingTypes` iteration order. The final
/// within-tier "offense descending" sort is Story 2.4's `rank` job, NOT baked in here.
List<OffensePick> candidateAnswers(Typing opponentTyping, TypeChart chart) {
  final answers = <OffensePick>[];
  for (final attackingType in chart.attackingTypes) {
    final offense = typeEffectiveness(attackingType, opponentTyping, chart);
    // SE gate (PRD §4.3): keeps only ≥ 2×, which drops 0×/0.5×/1× alike. The 0× drop is
    // the safety invariant; the ≥ 2× threshold is the answer-set definition (see doc above).
    if (offense >= 2.0) {
      answers.add(OffensePick(attackingType, offense));
    }
  }
  return answers;
}
