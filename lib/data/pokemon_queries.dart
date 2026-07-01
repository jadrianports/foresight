import 'package:sqflite/sqflite.dart';

import '../engine/type_chart.dart';

/// The growing read-side query API for the bundled dex — kept separate from
/// `foresight_database.dart` (which owns open/copy/contract) so the query
/// surface can grow with its consumers without bloating the bootstrap.
///
/// Data access here is PLAIN query functions (AD-2 / PRD §1): no repository
/// interface, no DI container, no abstraction layer. The composition root
/// (`main()`) calls these and injects the results into the widget tree; no
/// widget ever imports `sqflite` or holds a [Database] (AD-6).

/// One grid tile's worth of Pokémon data — an immutable plain value object read
/// from the bundled DB and injected into the UI (AD-6: the UI never queries).
///
/// Everything here is OPAQUE data the prebake owns (AD-4): [spritePath] is a
/// complete `assets/`-rooted forward-slash key used verbatim, and [formLabel]
/// is the exact human badge string (`Alola`/`Galar`/`Mega`/…) or `null` for a
/// base form — never construct either from the slug. [formLabel] is carried now
/// so Story 3.3 can add the badge with no re-query, though this story doesn't
/// render it.
///
/// [types] is the 1–2 **lowercase slugs** in slot order (primary first) — valid
/// keys into `kTypeColors`; they drive the AC#4 degrade chips. Capitalization is
/// display-only and never applies to a type slug.
///
/// Hand-written `==`/`hashCode`/`toString` mirror the engine's value-object
/// discipline (no `equatable`) — tests compare these structurally.
class PokemonListItem {
  PokemonListItem({
    required this.id,
    required this.name,
    required this.formLabel,
    required this.spritePath,
    required List<String> types,
  }) : types = List.unmodifiable(types);

  /// PokeAPI id (also the stable grid order). Not DB-assigned (no AUTOINCREMENT).
  final int id;

  /// Display name, already human-cased by the prebake (e.g. `Ninetales`).
  final String name;

  /// Exact badge string (`Alola`/`Galar`/`Mega`/`Mega X`/`Primal`) or `null`
  /// for base forms — never an empty string (AD-4). Rendered in Story 3.3.
  final String? formLabel;

  /// Complete `assets/`-rooted forward-slash sprite key — pass to `Image.asset`
  /// verbatim, never rebuild from the slug/form (AD-4).
  final String spritePath;

  /// 1–2 lowercase type slugs in slot order (primary first). Copied
  /// unmodifiable at construction so this value object can't be mutated after
  /// the fact (mirrors the engine's `Typing`/`StabRisk` discipline; a shared
  /// mutable list would silently break `==`/`hashCode`).
  final List<String> types;

  @override
  bool operator ==(Object other) =>
      other is PokemonListItem &&
      other.id == id &&
      other.name == name &&
      other.formLabel == formLabel &&
      other.spritePath == spritePath &&
      _listEquals(other.types, types);

  @override
  int get hashCode => Object.hash(
        id,
        name,
        formLabel,
        spritePath,
        Object.hashAll(types),
      );

  @override
  String toString() =>
      'PokemonListItem($id $name${formLabel == null ? '' : ' [$formLabel]'} '
      '${types.join('/')} → $spritePath)';
}

bool _listEquals(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Load the entire bundled dex as grid-ready [PokemonListItem]s, ordered by
/// `pokemon.id ASC` (National-Dex order) so the grid layout is deterministic
/// across launches (project-context "SORT rows by a stable key").
///
/// Every `pokemon` row is a tile — the prebake (Story 1.3) already emitted ONLY
/// typing-distinct forms, so there is no form-filtering here. Types are folded
/// in from `pokemon_types` in `slot` order (primary first).
///
/// Keys stay lowercase slugs — `type_name` is read verbatim, never up-cased in
/// a query (capitalization is UI-only). The schema is `NOT NULL` throughout, so
/// a null `name`/`sprite_path`/`type_name` means a corrupt DB; we do NOT default
/// or coerce it — the cast surfaces loudly (AD-7 posture: fail loud on data).
Future<List<PokemonListItem>> allPokemon(Database db) async {
  // Two ordered reads folded in a single pass — kept readable over a grouped
  // GROUP_CONCAT (which would re-introduce string-splitting on the slugs).
  final pokemonRows = await db.rawQuery(
    'SELECT id, name, form_label, sprite_path FROM pokemon ORDER BY id',
  );
  final typeRows = await db.rawQuery(
    'SELECT pokemon_id, type_name FROM pokemon_types ORDER BY pokemon_id, slot',
  );

  // Group type slugs by pokemon_id, preserving the slot order the query imposed.
  final typesById = <int, List<String>>{};
  for (final row in typeRows) {
    final id = row['pokemon_id'] as int;
    (typesById[id] ??= <String>[]).add(row['type_name'] as String);
  }

  return [
    for (final row in pokemonRows)
      PokemonListItem(
        id: row['id'] as int,
        name: row['name'] as String,
        formLabel: row['form_label'] as String?,
        spritePath: row['sprite_path'] as String,
        types: _typesForPokemon(typesById, row['id'] as int),
      ),
  ];
}

/// The 1–2 slugs for [id], or a hard throw. Every `pokemon` row has type rows
/// by contract (schema NOT NULL + prebake emits 1–2 per mon), so a miss here is
/// a corrupt DB. We fail loud rather than default to `[]` — a silent empty list
/// would render a chip-less degrade tile (unidentifiable), exactly the
/// silently-incomplete data AD-7 forbids. Mirrors the engine's release-safe
/// hard throw (not an `assert`, which is stripped in release).
List<String> _typesForPokemon(Map<int, List<String>> typesById, int id) {
  final types = typesById[id];
  if (types == null) {
    throw StateError(
      'pokemon id=$id has no pokemon_types rows — corrupt DB. Every mon must '
      'have 1–2 types (AD-7 fail-loud; never default to an empty list).',
    );
  }
  return types;
}

/// Load the whole dense 324-row type chart ONCE into the engine's in-memory
/// [TypeChart] value object — the single bulk read the composition root injects
/// so the engine's `rank(...)` runs with no per-cell async DB call (AD-6: the UI
/// never holds a [Database]; a plain value object is fine to inject).
///
/// This is the data → engine direction (the sanctioned import): `lib/data`
/// constructs the engine's `TypeChart` from raw rows. Keys stay lowercase slugs,
/// read verbatim — capitalization is UI-only and would silently miss (AD-7).
///
/// Fail LOUD, mirroring `foresight_database.dart`'s `typeMultiplier`: a row whose
/// `multiplier` is not a `num` is a corrupt DB (the schema is `REAL NOT NULL` and
/// the chart is dense by contract), so throw rather than let `as num` surface a
/// bare `TypeError` or — worse — default. NEVER `?? 1.0` (AD-7: a silent `1×` is
/// actively-wrong battle advice). `.toDouble()` coerces the stored `int` sqflite
/// hands back for `0`/`1`/`2` so the engine's exact-`double` comparisons hold.
Future<TypeChart> loadTypeChart(Database db) async {
  final rows = await db.rawQuery(
    'SELECT attacking_type, defending_type, multiplier FROM type_chart',
  );
  final entries = <(String, String), double>{};
  for (final row in rows) {
    final multiplier = row['multiplier'];
    if (multiplier is! num) {
      throw StateError(
        'type_chart row (${row['attacking_type']}, ${row['defending_type']}) '
        'has a non-numeric multiplier — corrupt DB (AD-7 fail-loud; never '
        'default to 1×).',
      );
    }
    entries[(row['attacking_type'] as String, row['defending_type'] as String)] =
        multiplier.toDouble();
  }
  return TypeChart(entries);
}
