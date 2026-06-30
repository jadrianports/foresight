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
      // NOTE: ('fighting', 'steel') is intentionally ABSENT → drives the MissingChartEntry tests.
    });
