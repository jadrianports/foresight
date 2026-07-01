// Shared test support for the Story 3.7 RecentsController provider ancestor.
// Every host that pumps HomeScreen/ResultScreen or builds ForesightApp now needs
// a RecentsController (AC#11f, mirroring Story 3.6's SettingsController ancestor).
// A real controller over an in-memory sqflite_common_ffi DB is simpler than a
// fake — the private constructor rules out a trivial subclass, and the in-memory
// DB is fast and offline.

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:foresight/data/pokemon_queries.dart';
import 'package:foresight/data/recents_queries.dart';
import 'package:foresight/recents_controller.dart';

/// Point sqflite at the host-side ffi factory (idempotent). Call in setUpAll.
void initRecentsFfi() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
}

/// A [RecentsController] over a fresh in-memory `recent_views` DB, resolving
/// against [dex]. [seededIds] are recorded in list order with ascending
/// timestamps, so the LAST id becomes the newest recent. The controller's own
/// clock is a monotonic counter, so later `recordView`s stay newest.
Future<RecentsController> buildTestRecents({
  List<PokemonListItem> dex = const [],
  List<int> seededIds = const [],
}) async {
  // singleInstance:false so each call gets a FRESH private in-memory DB — the
  // default (true) would reuse one shared ':memory:' handle across every call
  // and the second CREATE TABLE would throw "table already exists".
  final db = await databaseFactory.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(singleInstance: false),
  );
  await db.execute('CREATE TABLE recent_views ('
      'pokemon_id INTEGER NOT NULL, viewed_at INTEGER NOT NULL, '
      'PRIMARY KEY (pokemon_id))');
  var seedClock = 0;
  for (final id in seededIds) {
    await recordRecentView(db, id, seedClock += 1);
  }
  var clock = 1000000;
  return RecentsController.open(db, dex, clock: () => clock += 1);
}
