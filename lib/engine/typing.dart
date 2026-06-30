/// A defender's typing: an ordered list of 1 or 2 lowercase PokeAPI type slugs
/// (slot order = primary, secondary), mirroring the DB's `pokemon_types(slot, type_name)`.
///
/// This is the engine's foundational vocabulary — reused as `opponentTyping` by the
/// later STAB (Story 2.2) and `rank(...)` (Story 2.4) work. It is a minimal value
/// holder: equality + `toString` for test readability, and NO effectiveness logic
/// (NFR6 — no premature abstraction). [AD-2: `rank(opponentTyping, …)`]
class Typing {
  /// Construct from an ordered slug list. Throws [ArgumentError] unless the count is
  /// 1 or 2; the list is copied unmodifiable so the value object cannot be mutated
  /// after construction. A hard throw (not just an `assert`) so the 1-or-2 contract
  /// holds in release builds too, where asserts are stripped — a malformed `Typing`
  /// must fail loud, never fold to a silent answer (AD-7).
  Typing(List<String> types) : types = List.unmodifiable(types) {
    if (this.types.length != 1 && this.types.length != 2) {
      throw ArgumentError.value(this.types.length, 'types.length',
          'A Typing holds 1 or 2 type slugs (primary, secondary)');
    }
  }

  /// A single-type defender.
  Typing.mono(String type) : this([type]);

  /// A dual-type defender in slot order (primary, secondary).
  Typing.dual(String first, String second) : this([first, second]);

  /// The 1–2 lowercase slugs in slot order.
  ///
  /// Deliberately NOT lowercase-coerced: keys are lowercase slugs by contract, so a
  /// wrong-case slug must MISS the chart and trip [MissingChartEntry] (AD-7 fail-loud)
  /// rather than be silently "fixed" — coercion would mask a caller's casing bug.
  /// Validating that a slug is a real type is the chart's job, not this value object's.
  /// [project-context: "Query/compare on lowercase slugs ONLY"]
  final List<String> types;

  @override
  bool operator ==(Object other) =>
      other is Typing && _slugsEqual(other.types, types);

  @override
  int get hashCode => Object.hashAll(types);

  @override
  String toString() => 'Typing(${types.join(', ')})';
}

/// Ordered element-wise comparison of two slug lists (no `package:flutter` collection
/// helpers — `lib/engine/` depends on nothing but `dart:core`; AD-2).
bool _slugsEqual(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
