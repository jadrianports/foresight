// Tests for the recents write/read query functions (Story 3.7 Task 2) — the
// load-bearing, silently-wrong-if-broken bits: upsert-no-dup, newest-first order,
// and cap-10 oldest-eviction. Host-side via sqflite_common_ffi, in-memory only —
// never the real bundled DB (project-context #Testing-Rules).

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:foresight/data/recents_queries.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  // The `recent_views` shape from prebake/schema.sql (PK pokemon_id). We omit the
  // FK to `pokemon` — these tests exercise the write/evict logic in isolation.
  Future<Database> seed() async {
    final db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await db.execute('CREATE TABLE recent_views ('
        'pokemon_id INTEGER NOT NULL, viewed_at INTEGER NOT NULL, '
        'PRIMARY KEY (pokemon_id))');
    return db;
  }

  test('records newest-first by viewed_at (recentViewIds order)', () async {
    final db = await seed();
    addTearDown(db.close);

    await recordRecentView(db, 1, 100);
    await recordRecentView(db, 2, 200);
    await recordRecentView(db, 3, 300);

    // Descending viewed_at → newest (id 3) first.
    expect(await recentViewIds(db), [3, 2, 1]);
  });

  test('re-viewing an existing id REPLACES (no dup), moving it to the front',
      () async {
    final db = await seed();
    addTearDown(db.close);

    await recordRecentView(db, 1, 100);
    await recordRecentView(db, 2, 200);
    await recordRecentView(db, 3, 300);

    // Re-view id 1 with a newer timestamp → one row for it, now newest.
    await recordRecentView(db, 1, 400);

    final ids = await recentViewIds(db);
    expect(ids, [1, 3, 2], reason: 're-viewed id floats to front');
    expect(ids.where((id) => id == 1).length, 1, reason: 'no duplicate row');
    final count = (await db.rawQuery('SELECT COUNT(*) c FROM recent_views'))
        .first['c'];
    expect(count, 3, reason: 'still three distinct rows');
  });

  test('caps at 10 with the OLDEST evicted (insert 11 distinct ids)', () async {
    final db = await seed();
    addTearDown(db.close);

    // Insert ids 1..11 with strictly ascending viewed_at (id 1 is oldest).
    for (var i = 1; i <= 11; i++) {
      await recordRecentView(db, i, i * 10);
    }

    final ids = await recentViewIds(db);
    expect(ids.length, 10, reason: 'capped at 10');
    expect(ids.contains(1), isFalse, reason: 'the oldest (id 1) was evicted');
    expect(ids.first, 11, reason: 'newest is first');
    expect(ids.last, 2, reason: 'oldest surviving is id 2');
  });

  test('the cap override is honored', () async {
    final db = await seed();
    addTearDown(db.close);

    for (var i = 1; i <= 5; i++) {
      await recordRecentView(db, i, i * 10, cap: 3);
    }

    final ids = await recentViewIds(db);
    expect(ids, [5, 4, 3], reason: 'kept the newest 3 under cap:3');
  });
}
