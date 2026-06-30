/// Thrown when an `(attacking, defending)` pair is absent from the injected chart.
///
/// This is engine-local BY DESIGN. `lib/data/` already throws `DataContractViolation`
/// on a missing DB chart row, but importing a `data/` type into `engine/` would break
/// AD-2 ("the engine depends on nothing"). So the two coexist: `data/` guards the DB
/// read, `engine/` guards the in-memory lookup — and NEITHER ever defaults to `1×`
/// (AD-7: a silent `1×` is actively-wrong battle advice, the worst failure for this tool).
class MissingChartEntry implements Exception {
  MissingChartEntry(this.attacking, this.defending);

  /// The attacking slug whose lookup missed.
  final String attacking;

  /// The defending slug whose lookup missed.
  final String defending;

  @override
  String toString() =>
      'MissingChartEntry: no multiplier for attacking "$attacking" vs defending '
      '"$defending". The chart is dense by contract (AD-7) — a miss means a partial '
      'or corrupt chart, or a wrong-case slug, never a 1× default.';
}

/// An injected, in-memory `(attacking, defending) → multiplier` type chart.
///
/// The engine NEVER populates this from literals — that would embed the chart and create
/// the exact drift AD-2 exists to prevent. The caller fills it: a test fixture now, and
/// `lib/data/` reading the dense 324-row bundled DB later (Epic 3). Multipliers are the
/// exact set `{0, 0.5, 1, 2}`. [AD-2; ARCHITECTURE conventions "Chart density"]
class TypeChart {
  /// Build from plain `(attacking, defending) → multiplier` entries. The map is copied
  /// unmodifiable so an injected chart cannot be mutated after construction.
  TypeChart(Map<(String, String), double> entries)
      : _entries = Map.unmodifiable(entries);

  final Map<(String, String), double> _entries;

  /// The stored multiplier for the `(attacking, defending)` pair.
  ///
  /// Throws [MissingChartEntry] when the pair is absent — NEVER `?? 1.0` (AD-7). Keys
  /// are lowercase slugs; a capitalized key is a different (absent) key and so throws.
  double multiplierFor(String attacking, String defending) {
    final value = _entries[(attacking, defending)];
    if (value == null) throw MissingChartEntry(attacking, defending);
    return value;
  }

  /// The distinct attacking slugs present in this chart — the engine's attacking-type
  /// UNIVERSE, derived from the injected data rather than a hand-listed 18 slugs (AD-2).
  ///
  /// `rank(opponentTyping, chart, sortMode)` (Story 2.4) and `candidateAnswers` (Story 2.3)
  /// receive ONLY the chart, so it must be the single source of "all attacking types": for
  /// the dense 324-row bundled chart this yields the 18 canonical types; for a sparse test
  /// fixture, exactly the attacking slugs present. A read-only `Set`, mirroring the
  /// unmodifiable posture of `_entries` — no caching machinery (NFR6).
  Set<String> get attackingTypes =>
      {for (final key in _entries.keys) key.$1};
}
