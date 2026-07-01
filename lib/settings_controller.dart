import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'engine/ranking.dart';

/// The app's FIRST shared/persisted state, at the sanctioned ceiling (AD-6): a
/// root-provided [ChangeNotifier] that owns the persisted SORT preference and
/// reads/writes it through `shared_preferences` (NEVER the DB — AD-5).
///
/// Story 3.6 builds ONLY the sort slice. The architecture says this controller
/// eventually owns theme + sort (ARCHITECTURE-SPINE.md:81); the theme-override
/// `themeMode` field lands in Story 4.2 with its Settings UI. It is deliberately
/// shaped to gain that field then with no rework — do NOT add it now (AC#9): an
/// unwired `themeMode` would be dead, untested code.
///
/// NO SPINNER (AD-7/NFR2): the async `SharedPreferences.getInstance()` is awaited
/// ONCE in `main()` under the native splash, beside the DB open / `allPokemon` /
/// `loadTypeChart` awaits. The already-hydrated instance is handed in here, so
/// every read/write below is synchronous — there is no `FutureBuilder`, no
/// loading branch, no second async hop inside a widget.
class SettingsController extends ChangeNotifier {
  SettingsController(this._prefs) : _sortMode = _readSortMode(_prefs);

  final SharedPreferences _prefs;

  /// The `shared_preferences` key for the persisted sort choice. Stored as the
  /// enum's `.name` (`'safestFirst'` / `'hardestHitting'`).
  static const _kSortModeKey = 'sortMode';

  SortMode _sortMode;

  /// The active sort mode. Defaults to [SortMode.safestFirst] — the opinionated
  /// default (FR13/PRD §4.3) — when nothing (or something unrecognized) is stored.
  SortMode get sortMode => _sortMode;

  /// Sets the sort mode, persists it, and notifies listeners. A no-op (no write,
  /// no notify) when [mode] already equals the current value, so tapping the
  /// already-active toggle segment costs nothing.
  void setSortMode(SortMode mode) {
    if (mode == _sortMode) return;
    _sortMode = mode;
    // Fire-and-forget: the in-memory field is the source of truth for THIS run;
    // the write only has to win before the next cold launch. `notifyListeners`
    // must not wait on disk (AD-7 — no async gate in front of the UI).
    _prefs.setString(_kSortModeKey, mode.name);
    notifyListeners();
  }

  /// Reads the stored sort mode. `'hardestHitting'` maps to that mode; ANY other
  /// value — including `null` (never set) or a corrupt/legacy string — degrades
  /// SILENTLY to the [SortMode.safestFirst] default.
  ///
  /// WHY soft-default and not the AD-7 loud-throw: the loud-throw posture is for
  /// DATA contracts (a bad chart cell → silently-wrong battle advice). A UI
  /// PREFERENCE scalar is not a data contract — a garbage value should never
  /// crash the app; it just falls back to the sensible default. (AD-7 loud-throw
  /// is reserved for DB/chart violations.)
  static SortMode _readSortMode(SharedPreferences prefs) {
    // Read via `get` (Object?), NOT `getString` — the latter casts the stored
    // value to String and THROWS on a wrong-type value (int/bool/etc.), which
    // would crash launch inside this constructor. `get` lets any non-matching
    // value (wrong type, corrupt string, or null) fall through to the default,
    // honoring the "a garbage value should never crash the app" contract above.
    return prefs.get(_kSortModeKey) == SortMode.hardestHitting.name
        ? SortMode.hardestHitting
        : SortMode.safestFirst;
  }
}
