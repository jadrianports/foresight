import 'package:foresight/engine/type_chart.dart';

/// A small hand-built chart covering only the pairs the engine tests touch.
///
/// The full 324-row chart is DATA — injected from the bundled DB at runtime (Epic 3),
/// never embedded in `lib/engine/` and never duplicated wholesale here (AD-2). This
/// fixture is deliberately SPARSE: pairs left out (e.g. `fighting→steel`) exist so the
/// tests can exercise the [MissingChartEntry] throw (AC#4).
TypeChart buildFixtureChart() => TypeChart({
      // Single-type cases (AC#1).
      ('fire', 'grass'): 2.0, // super-effective
      ('fire', 'water'): 0.5, // resisted
      ('fire', 'electric'): 1.0, // neutral
      ('normal', 'ghost'): 0.0, // immune
      // Dual-type 4×: Fighting vs Tyranitar (rock/dark) — 2× · 2× (AC#2).
      ('fighting', 'rock'): 2.0,
      ('fighting', 'dark'): 2.0,
      // Neutralizing 1×: fire vs grass/water — 2× · 0.5× reuses the single-type rows above.
      // ×0 immunity dual: electric vs ground/water — 0× · 2× (AC#2).
      ('electric', 'ground'): 0.0,
      ('electric', 'water'): 2.0,
      // STAB-into-proxy direction (Story 2.2): the opponent's STAB type ATTACKS a
      // mono proxy of the candidate type. Canonical Rock/Dark-vs-Fairy case — the two
      // STABs land in DIFFERENT defensive buckets, so they must NOT collapse (AD-9):
      ('dark', 'fairy'): 0.5, // Fairy resists Dark
      ('rock', 'fairy'): 1.0, // Fairy is neutral to Rock
      // Mono-opponent STAB (grass) into a fire proxy — resisted (Story 2.2 mono case).
      ('grass', 'fire'): 0.5,
      // Immunity STAB: a ghost STAB into a normal proxy — Normal is immune to Ghost.
      ('ghost', 'normal'): 0.0,
      // NOTE: ('fighting', 'steel') is intentionally ABSENT → drives the MissingChartEntry tests.
      // NOTE: ('dragon', 'fairy') is intentionally ABSENT → drives the Story 2.2 missing-entry test.
    });
