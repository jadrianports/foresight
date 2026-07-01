// Tests for RecentsController (Story 3.7 Task 3): the cross-launch "sticky"
// restore (a fresh controller over an already-written DB rebuilds the list), and
// record semantics (notify once, move-to-front, no-dup, DB reflects the write).
// Host-side via sqflite_common_ffi, in-memory — never the real DB.

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:foresight/data/pokemon_queries.dart';
import 'package:foresight/data/recents_queries.dart';
import 'package:foresight/recents_controller.dart';

PokemonListItem item(int id, String name) => PokemonListItem(
      id: id,
      name: name,
      formLabel: null,
      spritePath: 'assets/sprites/__nope_${id}__.png',
      types: const ['normal'],
    );

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Future<Database> seed(List<Map<String, Object?>> rows) async {
    final db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await db.execute('CREATE TABLE recent_views ('
        'pokemon_id INTEGER NOT NULL, viewed_at INTEGER NOT NULL, '
        'PRIMARY KEY (pokemon_id))');
    for (final r in rows) {
      await db.insert('recent_views', r);
    }
    return db;
  }

  /// A monotonic clock so `recordView`'s viewed_at is deterministic + ascending.
  int Function() monotonic() {
    var t = 1000;
    return () => t += 1;
  }

  final dex = [item(1, 'Bulbasaur'), item(2, 'Charmander'), item(3, 'Squirtle')];

  test('restores recents newest-first from an already-written DB (sticky)',
      () async {
    // id 2 viewed later than id 1 → 2 should come first.
    final db = await seed([
      {'pokemon_id': 1, 'viewed_at': 100},
      {'pokemon_id': 2, 'viewed_at': 200},
    ]);
    addTearDown(db.close);

    final controller = await RecentsController.open(db, dex, clock: monotonic());

    expect(controller.recents.map((i) => i.id), [2, 1]);
    expect(controller.recents.first.name, 'Charmander');
  });

  test('skips a recent id absent from the dex (stale row never bricks Home)',
      () async {
    final db = await seed([
      {'pokemon_id': 2, 'viewed_at': 200},
      {'pokemon_id': 999, 'viewed_at': 300}, // not in dex
    ]);
    addTearDown(db.close);

    final controller = await RecentsController.open(db, dex, clock: monotonic());

    // The unresolvable id 999 is skipped; id 2 resolves.
    expect(controller.recents.map((i) => i.id), [2]);
  });

  test('recordView notifies once, moves to front, and persists', () async {
    final db = await seed([]);
    addTearDown(db.close);
    final controller = await RecentsController.open(db, dex, clock: monotonic());

    var notifications = 0;
    controller.addListener(() => notifications++);

    await controller.recordView(item(1, 'Bulbasaur'));

    expect(notifications, 1, reason: 'exactly one notify per recordView');
    expect(controller.recents.first.id, 1);
    // The write reached the DB (durable follow-up).
    expect(await recentViewIds(db), [1]);
  });

  test('re-viewing an existing item moves it to front without duplicating',
      () async {
    final db = await seed([]);
    addTearDown(db.close);
    final controller = await RecentsController.open(db, dex, clock: monotonic());

    await controller.recordView(item(1, 'Bulbasaur'));
    await controller.recordView(item(2, 'Charmander'));
    await controller.recordView(item(1, 'Bulbasaur')); // re-view

    expect(controller.recents.map((i) => i.id), [1, 2],
        reason: 'id 1 floats to front, no duplicate');
    expect(controller.recents.length, 2);
    expect(await recentViewIds(db), [1, 2]);
  });

  test('recents getter is unmodifiable', () async {
    final db = await seed([]);
    addTearDown(db.close);
    final controller = await RecentsController.open(db, dex, clock: monotonic());

    expect(() => controller.recents.add(item(9, 'X')), throwsUnsupportedError);
  });
}
