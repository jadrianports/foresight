import 'type_chart.dart';
import 'typing.dart';

/// The raw type effectiveness of [attackingType] against the [defender] typing.
///
/// - Mono defender → the single chart multiplier.
/// - Dual defender → the PRODUCT of both slot lookups, so `2×·2× = 4×`,
///   `2×·0.5× = 1×`, and `anything·0 = 0×`.
///
/// No rounding or clamping: the product of `{0, 0.5, 1, 2}` values is exactly
/// `{0, 0.25, 0.5, 1, 2, 4}`, all exactly representable in IEEE-754. A miss in EITHER
/// slot propagates [MissingChartEntry] (via [TypeChart.multiplierFor]) rather than
/// silently contributing a `1×` — do not catch or short-circuit it (AC#4 / AD-7).
///
/// A top-level function (not a method) keeps the engine surface minimal (NFR6). This is
/// the exact primitive Stories 2.2 (STAB proxy) and 2.4 (`rank`) reuse — kept symmetric
/// (`String` attacker + `Typing` defender) and forward-compatible, NOT forward-built.
double typeEffectiveness(
    String attackingType, Typing defender, TypeChart chart) {
  // Defense-in-depth: `Typing` already forbids an empty slug list, but guard here too —
  // an empty fold would return a silent `1×` ("neutral"), the exact wrong answer AD-7
  // forbids. Fail loud rather than let a degenerate defender produce confident advice.
  if (defender.types.isEmpty) {
    throw ArgumentError.value(defender, 'defender',
        'typeEffectiveness needs a defender with at least one type (AD-7).');
  }
  var product = 1.0;
  for (final defendingType in defender.types) {
    product *= chart.multiplierFor(attackingType, defendingType);
  }
  return product;
}
