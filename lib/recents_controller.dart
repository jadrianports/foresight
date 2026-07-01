import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import 'data/pokemon_queries.dart';
import 'data/recents_queries.dart';

/// The app's SECOND root-provided [ChangeNotifier] (AD-6) and the owner of the
/// recents state. Twin of [SettingsController], with ONE difference: recents
/// persist in SQLite (`recent_views`, the only writable table — AD-5), NOT
/// `shared_preferences`. A controller MAY hold a [Database]; a WIDGET may not
/// (AD-6) — so the raw SQL lives in `recents_queries.dart` and no widget ever
/// sees the handle.
///
/// NO SPINNER (AD-7/NFR2): the ONE async read of `recent_views` happens in the
/// static [open] factory, awaited in `main()` under the native splash beside the
/// DB open / `allPokemon` / `loadTypeChart` / prefs awaits. After construction,
/// [recents] is an in-memory list and [recordView] updates it + notifies
/// synchronously, so the Home strip refreshes instantly — there is no
/// `FutureBuilder`, no loading branch.
class RecentsController extends ChangeNotifier {
  RecentsController._(this._db, this._clock, this._recents);

  final Database _db;

  /// Epoch-ms clock, injectable so tests are deterministic (a monotonic counter).
  final int Function() _clock;

  /// Ordered newest-first. Private + mutable; handed out only via [recents] as an
  /// unmodifiable view (mirrors the value-object discipline).
  final List<PokemonListItem> _recents;

  /// Build the controller from the open [db] + the in-memory [dex], reading the
  /// persisted recents ONCE (the cross-launch "sticky" restore). This single
  /// await runs in `main()` under the splash — no in-app spinner (AC#3).
  ///
  /// A recent id absent from [dex] is SKIPPED, not thrown: the FK makes that
  /// unreachable with a consistent DB, but skip-not-throw keeps a stale recents
  /// row from bricking Home. A UI list is not the AD-7 loud-throw data-contract
  /// surface (that posture is for DB/chart violations).
  static Future<RecentsController> open(
    Database db,
    List<PokemonListItem> dex, {
    int Function()? clock,
  }) async {
    final byId = {for (final item in dex) item.id: item};
    final ids = await recentViewIds(db);
    final recents = [
      for (final id in ids)
        if (byId[id] != null) byId[id]!,
    ];
    return RecentsController._(
      db,
      clock ?? () => DateTime.now().millisecondsSinceEpoch,
      recents,
    );
  }

  /// The recents, newest-first. Never hands out the mutable internal list.
  List<PokemonListItem> get recents => List.unmodifiable(_recents);

  /// Record a view of [opponent]: move it to the front of the strip and persist.
  ///
  /// In-memory FIRST (remove any existing same-id entry, insert at index 0,
  /// truncate to 10) + `notifyListeners()` so the strip refreshes instantly; THEN
  /// the durable DB follow-up (upsert + evict). Ordering chosen so the UI updates
  /// immediately and a write failure can't corrupt the in-memory list.
  Future<void> recordView(PokemonListItem opponent) async {
    _recents.removeWhere((item) => item.id == opponent.id);
    _recents.insert(0, opponent);
    if (_recents.length > 10) _recents.removeRange(10, _recents.length);
    notifyListeners();

    // The durable follow-up. `recent_views` is a convenience list, NOT an AD-7
    // loud-throw data contract — so a persistence failure (a transient lock, a
    // disk fault) must not become an uncaught async error or disrupt the session.
    // The in-memory list + notify already happened, so the strip stays correct
    // now; on the (rare) failure we log and no-op, and the next successful
    // `recordView` re-persists. The only cost is losing this one row across a
    // cold restart in that rare case.
    try {
      await recordRecentView(_db, opponent.id, _clock());
    } catch (error, stackTrace) {
      debugPrint('RecentsController: failed to persist recent view '
          '${opponent.id} — $error\n$stackTrace');
    }
  }
}
