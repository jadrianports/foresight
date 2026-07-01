// Tests for the grid read-model (Story 3.1 Task 1). Host-side via
// sqflite_common_ffi — no device, fully offline (AD-1). The value here is the
// JOIN correctness: slot order (primary first), stable id ordering, nullable
// form_label, and verbatim lowercase type slugs. Plus PokemonListItem's
// structural equality (the codebase's value-object discipline — no equatable).

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:foresight/data/pokemon_queries.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  // Minimal shape mirroring prebake/schema.sql (pokemon + pokemon_types only).
  Future<Database> seed(List<Map<String, Object?>> pokemon,
      List<Map<String, Object?>> types) async {
    final db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await db.execute('CREATE TABLE pokemon ('
        'id INTEGER PRIMARY KEY, slug TEXT NOT NULL UNIQUE, name TEXT NOT NULL, '
        'form_label TEXT, sprite_path TEXT NOT NULL)');
    await db.execute('CREATE TABLE pokemon_types ('
        'pokemon_id INTEGER NOT NULL, slot INTEGER NOT NULL, '
        'type_name TEXT NOT NULL, PRIMARY KEY (pokemon_id, slot))');
    for (final p in pokemon) {
      await db.insert('pokemon', p);
    }
    for (final t in types) {
      await db.insert('pokemon_types', t);
    }
    return db;
  }

  test('returns rows ordered by id with types in slot order (primary first)',
      () async {
    // Insert out of id order and with slot 2 before slot 1 to prove ordering.
    final db = await seed(
      [
        {
          'id': 3,
          'slug': 'venusaur',
          'name': 'Venusaur',
          'form_label': null,
          'sprite_path': 'assets/sprites/venusaur.png',
        },
        {
          'id': 1,
          'slug': 'bulbasaur',
          'name': 'Bulbasaur',
          'form_label': null,
          'sprite_path': 'assets/sprites/bulbasaur.png',
        },
      ],
      [
        {'pokemon_id': 1, 'slot': 2, 'type_name': 'poison'},
        {'pokemon_id': 1, 'slot': 1, 'type_name': 'grass'},
        {'pokemon_id': 3, 'slot': 1, 'type_name': 'grass'},
        {'pokemon_id': 3, 'slot': 2, 'type_name': 'poison'},
      ],
    );
    addTearDown(db.close);

    final list = await allPokemon(db);

    expect(list.map((p) => p.id), [1, 3], reason: 'ordered by id ASC');
    expect(list[0].types, ['grass', 'poison'],
        reason: 'primary (slot 1) before secondary (slot 2)');
    expect(list[0].name, 'Bulbasaur');
    expect(list[0].spritePath, 'assets/sprites/bulbasaur.png');
  });

  test('carries a nullable form_label verbatim and a single type', () async {
    final db = await seed(
      [
        {
          'id': 10,
          'slug': 'ninetales-alola',
          'name': 'Ninetales',
          'form_label': 'Alola',
          'sprite_path': 'assets/sprites/ninetales-alola.png',
        },
        {
          'id': 11,
          'slug': 'pikachu',
          'name': 'Pikachu',
          'form_label': null,
          'sprite_path': 'assets/sprites/pikachu.png',
        },
      ],
      [
        {'pokemon_id': 10, 'slot': 1, 'type_name': 'ice'},
        {'pokemon_id': 10, 'slot': 2, 'type_name': 'fairy'},
        {'pokemon_id': 11, 'slot': 1, 'type_name': 'electric'},
      ],
    );
    addTearDown(db.close);

    final list = await allPokemon(db);

    expect(list[0].formLabel, 'Alola');
    expect(list[0].types, ['ice', 'fairy']);
    expect(list[1].formLabel, isNull);
    expect(list[1].types, ['electric']);
  });

  test('PokemonListItem has structural equality (==, hashCode)', () {
    PokemonListItem make() => PokemonListItem(
          id: 1,
          name: 'Bulbasaur',
          formLabel: null,
          spritePath: 'assets/sprites/bulbasaur.png',
          types: ['grass', 'poison'],
        );

    expect(make(), equals(make()));
    expect(make().hashCode, make().hashCode);

    final differentType = PokemonListItem(
      id: 1,
      name: 'Bulbasaur',
      formLabel: null,
      spritePath: 'assets/sprites/bulbasaur.png',
      types: ['poison', 'grass'], // order matters
    );
    expect(make(), isNot(equals(differentType)));
  });

  // ----- Story 3.4: loadTypeChart (the bulk chart read the engine consumes) -----

  // Seed just the type_chart table (mirrors prebake/schema.sql: REAL NOT NULL).
  Future<Database> seedChart(List<Map<String, Object?>> rows) async {
    final db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await db.execute('CREATE TABLE type_chart ('
        'attacking_type TEXT NOT NULL, defending_type TEXT NOT NULL, '
        'multiplier REAL NOT NULL, PRIMARY KEY (attacking_type, defending_type))');
    for (final r in rows) {
      await db.insert('type_chart', r);
    }
    return db;
  }

  test('loadTypeChart builds a TypeChart whose lookups match the seeded cells',
      () async {
    final db = await seedChart([
      {'attacking_type': 'fire', 'defending_type': 'grass', 'multiplier': 2.0},
      {'attacking_type': 'fire', 'defending_type': 'water', 'multiplier': 0.5},
      {'attacking_type': 'normal', 'defending_type': 'ghost', 'multiplier': 0.0},
      // A whole-number cell stored as REAL: sqflite hands back an int for 1 —
      // loadTypeChart must .toDouble() it so it matches the engine's double.
      {'attacking_type': 'fire', 'defending_type': 'fire', 'multiplier': 1},
    ]);
    addTearDown(db.close);

    final chart = await loadTypeChart(db);

    expect(chart.multiplierFor('fire', 'grass'), 2.0);
    expect(chart.multiplierFor('fire', 'water'), 0.5);
    expect(chart.multiplierFor('normal', 'ghost'), 0.0);
    expect(chart.multiplierFor('fire', 'fire'), 1.0);
    expect(chart.multiplierFor('fire', 'fire'), isA<double>());
    // Lowercase-slug keys only: a capitalized key is a different (absent) key.
    expect(() => chart.multiplierFor('Fire', 'grass'), throwsA(anything));
  });

  test('loadTypeChart fails LOUD on a non-numeric multiplier (never defaults)',
      () async {
    // Force a corrupt cell past the REAL NOT NULL guard by declaring the column
    // permissively — mirrors a corrupt DB the loader must reject, not swallow.
    final db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    addTearDown(db.close);
    await db.execute('CREATE TABLE type_chart ('
        'attacking_type TEXT NOT NULL, defending_type TEXT NOT NULL, '
        'multiplier, PRIMARY KEY (attacking_type, defending_type))');
    await db.insert('type_chart', {
      'attacking_type': 'fire',
      'defending_type': 'grass',
      'multiplier': 'not-a-number',
    });

    expect(loadTypeChart(db), throwsA(isA<StateError>()));
  });
}
