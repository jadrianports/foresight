import 'package:sqflite/sqflite.dart';

/// The write/read query surface for `recent_views` — the app's ONE writable
/// table (AD-5). Kept beside the read-only dex/chart queries in
/// `pokemon_queries.dart`, but SEPARATE because this is the sole place the app
/// mutates the DB.
///
/// Data access here is PLAIN query functions (AD-2 / PRD §1): no repository
/// interface, no DI container. [RecentsController] calls these and owns the
/// recents STATE; the SQL lives here so the controller never embeds raw SQL and
/// no widget ever holds a [Database] (AD-6).
///
/// Semantics (AC#4): `recent_views` PK is `pokemon_id`, so re-viewing an existing
/// opponent REPLACES its row (bumping `viewed_at`) instead of duplicating — free
/// "move to newest" via [ConflictAlgorithm.replace]. `viewed_at` is epoch
/// milliseconds, supplied by the caller so tests stay deterministic. The list is
/// capped at ~10 with the OLDEST evicted — the app-side enforcement the schema
/// comment (schema.sql:50-51) defers to Epic 3.

/// Record a view of [pokemonId] at [viewedAt] (epoch ms), then evict everything
/// past the newest [cap] rows — BOTH in one transaction so a kill mid-write can't
/// leave a half-evicted list.
///
/// Uses [ConflictAlgorithm.replace]: the PK is `pokemon_id`, so re-recording an
/// existing opponent removes the pre-existing row before inserting — one row,
/// newer `viewed_at`, never a duplicate. Everything runs on `txn` inside the
/// callback, NEVER the outer [db] (using `db` inside a `transaction` deadlocks).
Future<void> recordRecentView(
  Database db,
  int pokemonId,
  int viewedAt, {
  int cap = 10,
}) async {
  await db.transaction((txn) async {
    await txn.insert(
      'recent_views',
      {'pokemon_id': pokemonId, 'viewed_at': viewedAt},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    // Keep only the newest `cap` rows; delete the rest (oldest-eviction). The
    // subquery picks the survivors by `viewed_at DESC`; NOT IN removes the rest.
    await txn.rawDelete(
      'DELETE FROM recent_views WHERE pokemon_id NOT IN '
      '(SELECT pokemon_id FROM recent_views ORDER BY viewed_at DESC LIMIT ?)',
      [cap],
    );
  });
}

/// The recorded `pokemon_id`s, newest-first (`viewed_at DESC`). The controller
/// resolves these ids to display items against the in-memory dex (AC#3).
Future<List<int>> recentViewIds(Database db) async {
  final rows = await db.rawQuery(
    'SELECT pokemon_id FROM recent_views ORDER BY viewed_at DESC',
  );
  return [for (final r in rows) r['pokemon_id'] as int];
}
