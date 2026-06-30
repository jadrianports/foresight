// Data-contract tests for the DB bootstrap (Story 1.4 Task 8). These run host-side via
// sqflite_common_ffi — no device/emulator, fully offline (AD-1). The priority here is the
// CONTRACT: copy-on-first-launch, version reconcile, and loud-on-violation. That is where
// silently-wrong advice would ship, so these paths get real coverage (project-context
// "match effort to risk").

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:foresight/data/data_contract_violation.dart';
import 'package:foresight/data/foresight_database.dart';
import 'package:foresight/data/schema_version.dart';

void main() {
  // The real schema text the prebake hashes; expected version is computed from it.
  final schemaSql = File('prebake/schema.sql').readAsStringSync();
  final expected = computeUserVersion(schemaSql); // 1555704544 for the current schema

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  // --- helpers -------------------------------------------------------------------------

  // Execute a multi-statement SQL script (sqflite has no executescript): strip comments,
  // split on ';', run each statement. Safe for our schema (no ';' inside literals).
  Future<void> executeScript(Database db, String sql) async {
    final stripped = sql
        .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), ' ')
        .replaceAll(RegExp(r'--[^\n]*'), ' ');
    for (final stmt in stripped.split(';')) {
      final s = stmt.trim();
      if (s.isNotEmpty) await db.execute(s);
    }
  }

  // Build a fixture DB file, stamp its user_version, optionally seed rows, and return its
  // raw bytes (to stand in for the bundled asset via the loadDbAsset seam).
  Future<Uint8List> buildFixtureBytes(
    String path, {
    required int userVersion,
    String? sqlToExecute, // defaults to the full real schema
    int pokemonCount = 0,
    List<(String, String, double)> chartRows = const [],
  }) async {
    final f = File(path);
    if (f.existsSync()) f.deleteSync();
    final db = await databaseFactory.openDatabase(path);
    await executeScript(db, sqlToExecute ?? schemaSql);
    await db.execute('PRAGMA user_version = $userVersion');
    for (var i = 1; i <= pokemonCount; i++) {
      await db.insert('pokemon', {
        'id': i,
        'slug': 'mon-$i',
        'name': 'Mon $i',
        'form_label': null,
        'sprite_path': 'assets/sprites/mon-$i.png',
      });
    }
    for (final (atk, def, mult) in chartRows) {
      await db.insert('type_chart', {
        'attacking_type': atk,
        'defending_type': def,
        'multiplier': mult,
      });
    }
    await db.close();
    return f.readAsBytesSync();
  }

  Directory freshTempDir() =>
      Directory.systemTemp.createTempSync('foresight_db_test_');

  // -------------------------------------------------------------------------------------

  test('first launch copies the asset; smoke counts read the bundled data', () async {
    final fixtureDir = freshTempDir();
    final dbDir = freshTempDir();
    addTearDown(() => fixtureDir.deleteSync(recursive: true));
    addTearDown(() => dbDir.deleteSync(recursive: true));

    final bytes = await buildFixtureBytes(
      '${fixtureDir.path}/asset.db',
      userVersion: expected,
      pokemonCount: 3,
      chartRows: [('fire', 'grass', 2.0), ('water', 'fire', 2.0)],
    );

    final target = File('${dbDir.path}/foresight.db');
    expect(target.existsSync(), isFalse, reason: 'no copy before first launch');

    final db = await openForesightDatabase(
      databasesDirOverride: dbDir.path,
      loadDbAsset: () async => bytes,
      schemaTextOverride: schemaSql,
    );
    addTearDown(db.close);

    expect(target.existsSync(), isTrue, reason: 'asset copied on first launch');
    final counts = await smokeCounts(db);
    expect(counts.pokemon, 3);
    expect(counts.chart, 2);
  });

  test('typeMultiplier returns the stored value and throws on a missing pair', () async {
    final fixtureDir = freshTempDir();
    final dbDir = freshTempDir();
    addTearDown(() => fixtureDir.deleteSync(recursive: true));
    addTearDown(() => dbDir.deleteSync(recursive: true));

    final bytes = await buildFixtureBytes(
      '${fixtureDir.path}/asset.db',
      userVersion: expected,
      chartRows: [('fire', 'grass', 2.0), ('water', 'fire', 0.5)],
    );
    final db = await openForesightDatabase(
      databasesDirOverride: dbDir.path,
      loadDbAsset: () async => bytes,
      schemaTextOverride: schemaSql,
    );
    addTearDown(db.close);

    expect(await typeMultiplier(db, 'fire', 'grass'), 2.0);
    expect(await typeMultiplier(db, 'water', 'fire'), 0.5);
    // Missing row must throw, NEVER default to 1.0 (AD-7).
    expect(
      () => typeMultiplier(db, 'fire', 'water'),
      throwsA(isA<DataContractViolation>()),
    );
    // Capitalized key returns zero rows -> same loud throw (lowercase-slug gotcha).
    expect(
      () => typeMultiplier(db, 'Fire', 'grass'),
      throwsA(isA<DataContractViolation>()),
    );
  });

  test('a bundled version differing from the copy triggers a re-copy', () async {
    final fixtureDir = freshTempDir();
    final dbDir = freshTempDir();
    addTearDown(() => fixtureDir.deleteSync(recursive: true));
    addTearDown(() => dbDir.deleteSync(recursive: true));

    // Stale copy already present: valid DB but a DIFFERENT user_version and old content.
    await buildFixtureBytes(
      '${dbDir.path}/foresight.db',
      userVersion: expected - 1,
      pokemonCount: 1,
    );

    // Bundled asset: current version, fresh content.
    final bytes = await buildFixtureBytes(
      '${fixtureDir.path}/asset.db',
      userVersion: expected,
      pokemonCount: 5,
    );

    final db = await openForesightDatabase(
      databasesDirOverride: dbDir.path,
      loadDbAsset: () async => bytes,
      schemaTextOverride: schemaSql,
    );
    addTearDown(db.close);

    // The stale copy (1 pokemon) was replaced by the bundled content (5 pokemon).
    expect((await smokeCounts(db)).pokemon, 5);
  });

  test('a bundled DB whose version != schema hash throws (loud, not defaulted)', () async {
    final fixtureDir = freshTempDir();
    final dbDir = freshTempDir();
    addTearDown(() => fixtureDir.deleteSync(recursive: true));
    addTearDown(() => dbDir.deleteSync(recursive: true));

    // Asset stamped with a wrong version vs the schema the app was built against.
    final bytes = await buildFixtureBytes(
      '${fixtureDir.path}/asset.db',
      userVersion: 999, // != expected
      pokemonCount: 1,
    );

    expect(
      () => openForesightDatabase(
        databasesDirOverride: dbDir.path,
        loadDbAsset: () async => bytes,
        schemaTextOverride: schemaSql,
      ),
      throwsA(isA<DataContractViolation>()),
    );
  });

  test('a DB missing a required table throws', () async {
    final fixtureDir = freshTempDir();
    final dbDir = freshTempDir();
    addTearDown(() => fixtureDir.deleteSync(recursive: true));
    addTearDown(() => dbDir.deleteSync(recursive: true));

    // Execute the schema but omit recent_views; still stamp the full-schema hash so the
    // version checks pass and the missing-table assert is what fires.
    final partialSchema = schemaSql.replaceAll(
      RegExp(r'CREATE TABLE recent_views.*?\);', dotAll: true),
      '',
    );
    final bytes = await buildFixtureBytes(
      '${fixtureDir.path}/asset.db',
      userVersion: expected,
      sqlToExecute: partialSchema,
    );

    expect(
      () => openForesightDatabase(
        databasesDirOverride: dbDir.path,
        loadDbAsset: () async => bytes,
        schemaTextOverride: schemaSql,
      ),
      throwsA(isA<DataContractViolation>()),
    );
  });

  test('subsequent launch opens the existing copy without re-copying', () async {
    final fixtureDir = freshTempDir();
    final dbDir = freshTempDir();
    addTearDown(() => fixtureDir.deleteSync(recursive: true));
    addTearDown(() => dbDir.deleteSync(recursive: true));

    final bytes = await buildFixtureBytes(
      '${fixtureDir.path}/asset.db',
      userVersion: expected,
      pokemonCount: 2,
    );

    final db1 = await openForesightDatabase(
      databasesDirOverride: dbDir.path,
      loadDbAsset: () async => bytes,
      schemaTextOverride: schemaSql,
    );
    await db1.close();

    // Mutate the COPY (keeping its version): now 3 rows. A re-copy would clobber this back
    // to the bundled 2; opening the existing matching copy must preserve it.
    final copy = await databaseFactory.openDatabase('${dbDir.path}/foresight.db');
    await copy.insert('pokemon', {
      'id': 999,
      'slug': 'mon-local',
      'name': 'Local',
      'form_label': null,
      'sprite_path': 'assets/sprites/mon-local.png',
    });
    await copy.close();

    final db2 = await openForesightDatabase(
      databasesDirOverride: dbDir.path,
      loadDbAsset: () async => bytes, // matches the existing copy's version -> no re-copy
      schemaTextOverride: schemaSql,
    );
    addTearDown(db2.close);

    expect((await smokeCounts(db2)).pokemon, 3,
        reason: 'existing matching copy was opened, not overwritten by the asset');
  });
}
