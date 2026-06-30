import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' show dirname, join;
import 'package:sqflite/sqflite.dart';
// Prefixed alias only to reach the default global `databaseFactory`, which the same-named
// optional parameter below shadows inside openForesightDatabase.
import 'package:sqflite/sqflite.dart' as sqflite;

import 'data_contract_violation.dart';
import 'schema_version.dart';

/// Phase 2 — the Data layer (BUILD-ORDER §2). The app-side half of the AD-3 contract:
/// copy the bundled read-only DB into the writable databases dir on first launch, reconcile
/// it against the bundled version on every launch, and assert the running schema hash equals
/// the opened DB's `user_version`. Any contract violation throws [DataContractViolation] —
/// loud failure, never silently-wrong advice (AD-7).
///
/// Data access here is PLAIN query functions — no repository interfaces, no DI container
/// (AD-2 / PRD §1). The test seams below are plain optional params with production defaults,
/// NOT a DI framework.

/// The bundled read-only DB asset (prebake-owned, Story 1.3).
const String _dbAssetKey = 'assets/db/foresight.db';

/// File name of the writable copy inside the databases directory.
const String _dbFileName = 'foresight.db';

/// SQLite file-format: the "user version" is a big-endian int32 at byte offset 60 of the
/// header. Reading it straight from the asset bytes lets us compare the bundled version
/// without first copying the file. https://www.sqlite.org/fileformat.html
const int _userVersionHeaderOffset = 60;

/// Tables the contract requires to exist. A missing one is a loud violation (AD-7).
const List<String> _requiredTables = [
  'pokemon',
  'pokemon_types',
  'type_chart',
  'recent_views',
];

/// Open the bundled Foresight DB, performing copy-on-first-launch + version reconcile +
/// hash assert. See the canonical flow in the Story 1.4 Dev Notes.
///
/// Test seams (production defaults shown): [databaseFactory] (the real sqflite factory),
/// [databasesDirOverride] (else `getDatabasesPath()`), [loadDbAsset] (else the bundled
/// `assets/db/foresight.db`), and [schemaTextOverride] (else the bundled `prebake/schema.sql`,
/// hashed for the expected version). These let host-side ffi tests drive the flow without a
/// device — they are NOT a dependency-injection container.
Future<Database> openForesightDatabase({
  DatabaseFactory? databaseFactory,
  String? databasesDirOverride,
  Future<Uint8List> Function()? loadDbAsset,
  String? schemaTextOverride,
}) async {
  final factory = databaseFactory ?? sqflite.databaseFactory;

  // 1. Expected version = hash of the schema TEXT the app was built against (AD-3:
  //    computed, never hard-coded, so a forgotten prebake re-run fails loud).
  final expected = schemaTextOverride != null
      ? computeUserVersion(schemaTextOverride)
      : await userVersionForBundledSchema();

  // 2. The bundled DB bytes + its stamped version (read from the SQLite header).
  final assetBytes = await (loadDbAsset?.call() ?? _loadBundledDbBytes());
  final bundledVersion = _readHeaderUserVersion(assetBytes);

  // 3. Bundled DB and the schema it ships with MUST agree, or the release itself is broken.
  if (bundledVersion != expected) {
    throw DataContractViolation(
      'Bundled DB user_version does not match the bundled schema hash '
      '(prebake/app schema drift).',
      expected: expected,
      actual: bundledVersion,
    );
  }

  // 4. Resolve the writable copy path.
  final dir = databasesDirOverride ?? await factory.getDatabasesPath();
  final dbPath = join(dir, _dbFileName);

  // 5. Copy-on-first-launch, and reconcile a stale copy against a newer bundled shape.
  if (!await File(dbPath).exists()) {
    await _copyAssetAtomically(assetBytes, dbPath);
  } else {
    final copiedVersion = await _readCopiedUserVersion(factory, dbPath);
    if (copiedVersion != bundledVersion) {
      // An updated prebake/app build shipped a new shape — replace the stale copy so we
      // never serve stale data (AD-3). A data-only refresh keeps the same version by design.
      await _copyAssetAtomically(assetBytes, dbPath);
    }
  }

  // 6. Open the copy read-only (the app writes no table in this story; recent_views writes
  //    arrive in Epic 3) and assert the final contract.
  final db = await factory.openDatabase(
    dbPath,
    options: OpenDatabaseOptions(readOnly: true),
  );
  // Fail loud on any contract violation — but never leak the open handle (it would lock the
  // file). Close, then rethrow so the launch still crashes to a clear message (AD-7).
  try {
    final openedVersion = _firstInt(await db.rawQuery('PRAGMA user_version'));
    if (openedVersion != expected) {
      throw DataContractViolation(
        'Opened DB user_version does not match the running schema hash.',
        expected: expected,
        actual: openedVersion,
      );
    }
    await _assertRequiredTables(db);
  } catch (_) {
    await db.close();
    rethrow;
  }
  return db;
}

/// Load the bundled DB asset bytes via the Flutter asset bundle (production path).
Future<Uint8List> _loadBundledDbBytes() async {
  final data = await rootBundle.load(_dbAssetKey);
  return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}

/// Read the SQLite `user_version` (big-endian int32 at header offset 60) from raw DB bytes.
int _readHeaderUserVersion(Uint8List bytes) {
  if (bytes.length < _userVersionHeaderOffset + 4) {
    throw DataContractViolation(
      'Bundled DB is too small to be a valid SQLite file '
      '(${bytes.length} bytes).',
    );
  }
  return ByteData.sublistView(bytes, _userVersionHeaderOffset,
          _userVersionHeaderOffset + 4)
      .getInt32(0, Endian.big);
}

/// Open the existing copy read-only just long enough to read its `user_version`, then close.
Future<int> _readCopiedUserVersion(
    DatabaseFactory factory, String dbPath) async {
  final db = await factory.openDatabase(
    dbPath,
    options: OpenDatabaseOptions(readOnly: true),
  );
  try {
    return _firstInt(await db.rawQuery('PRAGMA user_version'));
  } finally {
    await db.close();
  }
}

/// Atomically (re)write the bundled bytes to [dbPath]: write a sibling `*.tmp` then rename
/// over the target. AD-7 hardening (mirrors the Story 1.3 prebake review): a first launch
/// killed mid-copy must not leave a truncated `foresight.db` that the existence gate then
/// trusts forever.
Future<void> _copyAssetAtomically(Uint8List bytes, String dbPath) async {
  await Directory(dirname(dbPath)).create(recursive: true);
  final tmpPath = '$dbPath.tmp';
  await File(tmpPath).writeAsBytes(bytes, flush: true);
  await File(tmpPath).rename(dbPath);
}

/// Assert every required table exists; a missing one is a loud contract violation (AD-7).
Future<void> _assertRequiredTables(Database db) async {
  final rows = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type = 'table'",
  );
  final present = rows.map((r) => r['name'] as String).toSet();
  final missing = _requiredTables.where((t) => !present.contains(t)).toList();
  if (missing.isNotEmpty) {
    throw DataContractViolation(
      'Bundled DB is missing required table(s): ${missing.join(', ')}.',
    );
  }
}

int _firstInt(List<Map<String, Object?>> rows) => Sqflite.firstIntValue(rows)!;

// --- Plain query helpers the ACs need (no more — full query API lands with its consumers) ---

/// Offline smoke check (AC#5): counts that prove the bundled data opens and reads fully.
/// Expected for the current release: ~1100 pokemon, exactly 324 type_chart rows.
Future<({int pokemon, int chart})> smokeCounts(Database db) async {
  final pokemon = _firstInt(await db.rawQuery('SELECT COUNT(*) FROM pokemon'));
  final chart = _firstInt(await db.rawQuery('SELECT COUNT(*) FROM type_chart'));
  return (pokemon: pokemon, chart: chart);
}

/// Look up a single type-effectiveness multiplier.
///
/// Keys are lowercase PokeAPI slugs ONLY (`fire`, `dark`, …). Passing a capitalized key
/// (`'Fire'`) returns ZERO rows with no error — which would then trip the throw below — so
/// callers must never capitalize a query key (capitalization is UI-only). A missing
/// `(attacking, defending)` row throws [DataContractViolation]; it is NEVER defaulted to
/// `1.0` (AD-7: a silent `1×` is the worst failure — actively wrong battle advice).
Future<double> typeMultiplier(
    Database db, String attacking, String defending) async {
  final rows = await db.rawQuery(
    'SELECT multiplier FROM type_chart '
    'WHERE attacking_type = ? AND defending_type = ?',
    [attacking, defending],
  );
  if (rows.isEmpty) {
    throw DataContractViolation(
      'Missing type_chart row for ($attacking, $defending).',
    );
  }
  return (rows.first['multiplier'] as num).toDouble();
}
