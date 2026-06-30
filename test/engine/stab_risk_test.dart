import 'package:flutter_test/flutter_test.dart';
import 'package:foresight/engine/stab_risk.dart';
import 'package:foresight/engine/type_chart.dart';
import 'package:foresight/engine/typing.dart';

import 'fixture_chart.dart';

// Story 2.2: the DEFENSIVE half of the §4.2 mono-type proxy model. For a candidate
// attacking type, how hard does each of the opponent's STABs hit back into a mono proxy
// of that candidate — kept PER STAB (AD-9), never collapsed to a worst multiplier.
//
// Multipliers are exactly {0,0.5,1,2}; assert exact equality, NO epsilon (matches the
// effectiveness suite's posture).
void main() {
  final chart = buildFixtureChart();

  group('per-STAB results are preserved, never collapsed (AC#2/#5)', () {
    test('canonical Rock/Dark vs a Fairy proxy → two DIFFERENT buckets', () {
      // Tyranitar (rock/dark) hitting a Fairy proxy: Fairy is neutral to Rock (1×) but
      // resists Dark (0.5×). The two STABs MUST stay distinct (the AD-9 keystone). A
      // worst-multiplier collapse would flatten both to 1× and lose the resisted Dark.
      final risk = stabRiskFor('fairy', Typing.dual('rock', 'dark'), chart);

      expect(risk.candidateType, 'fairy');
      expect(risk.hits.length, 2);
      // Order mirrors the opponent's slot order (primary, secondary).
      expect(risk.hits[0].stabType, 'rock');
      expect(risk.hits[0].multiplier, 1.0);
      expect(risk.hits[1].stabType, 'dark');
      expect(risk.hits[1].multiplier, 0.5);
      // Explicitly assert the two values were NOT collapsed to a single number.
      expect(risk.hits[0].multiplier == risk.hits[1].multiplier, isFalse);
    });
  });

  group('mono-type opponent → a one-entry per-STAB list (AC#5)', () {
    test('grass STAB into a fire proxy is resisted (0.5×)', () {
      final risk = stabRiskFor('fire', Typing.mono('grass'), chart);

      expect(risk.candidateType, 'fire');
      expect(risk.hits.length, 1);
      expect(risk.hits.single.stabType, 'grass');
      expect(risk.hits.single.multiplier, 0.5);
    });
  });

  group('immunity is preserved as 0×, not dropped (AC#5)', () {
    test('ghost STAB into a normal proxy = 0× (Normal is immune to Ghost)', () {
      // The 0× *offense* hard-filter (Story 2.3) does NOT apply here — this is a
      // DEFENSIVE value, and a 0× STAB is genuine information (that STAB does nothing
      // back), so it stays in the list rather than being filtered out.
      final risk = stabRiskFor('normal', Typing.mono('ghost'), chart);

      expect(risk.hits.length, 1);
      expect(risk.hits.single.stabType, 'ghost');
      expect(risk.hits.single.multiplier, 0.0);
    });
  });

  group('a missing chart row still throws — reuse keeps the loud failure (AC#4)', () {
    test('an absent STAB/proxy pair propagates MissingChartEntry, never a silent 1×', () {
      // ('dragon','fairy') is intentionally absent from the fixture. Because stabRiskFor
      // composes typeEffectiveness → TypeChart.multiplierFor, the miss must surface as a
      // throw (AD-7), proving no try/catch or `?? 1.0` was introduced.
      expect(() => stabRiskFor('fairy', Typing.mono('dragon'), chart),
          throwsA(isA<MissingChartEntry>()));
    });
    test('one missing STAB in a dual opponent throws (no partial silent result)', () {
      // rock→fairy is present (1×) but dragon→fairy is absent; the second STAB must throw.
      expect(() => stabRiskFor('fairy', Typing.dual('rock', 'dragon'), chart),
          throwsA(isA<MissingChartEntry>()));
    });
  });

  group('the per-STAB list is an immutable contract', () {
    test('hits cannot be mutated by a caller', () {
      final risk = stabRiskFor('fire', Typing.mono('grass'), chart);
      expect(() => risk.hits.add(risk.hits.first),
          throwsA(isA<UnsupportedError>()));
    });
  });
}
