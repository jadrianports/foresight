import 'package:flutter_test/flutter_test.dart';
import 'package:foresight/engine/effectiveness.dart';
import 'package:foresight/engine/type_chart.dart';
import 'package:foresight/engine/typing.dart';

import 'fixture_chart.dart';

// The engine is the project's priority test target (project-context #Testing-Rules):
// the §4 matchup math is the one provably-correct part. Multipliers are exactly
// {0,0.5,1,2} and products are exactly {0,0.25,0.5,1,2,4} — all exact in IEEE-754, so
// assert exact equality, NO epsilon tolerance.
void main() {
  final chart = buildFixtureChart();

  group('single-type defender → the chart multiplier (AC#1)', () {
    test('2× super-effective: fire vs grass', () {
      expect(typeEffectiveness('fire', Typing.mono('grass'), chart), 2.0);
    });
    test('0.5× resisted: fire vs water', () {
      expect(typeEffectiveness('fire', Typing.mono('water'), chart), 0.5);
    });
    test('1× neutral: fire vs electric', () {
      expect(typeEffectiveness('fire', Typing.mono('electric'), chart), 1.0);
    });
    test('0× immune: normal vs ghost', () {
      expect(typeEffectiveness('normal', Typing.mono('ghost'), chart), 0.0);
    });
  });

  group('dual-type defender → the PRODUCT of both slots (AC#2)', () {
    test('4×: fighting vs Tyranitar (rock/dark) = 2× · 2×', () {
      expect(typeEffectiveness('fighting', Typing.dual('rock', 'dark'), chart), 4.0);
    });
    test('neutralizing 1×: fire vs grass/water = 2× · 0.5× (product, not max/min)', () {
      expect(typeEffectiveness('fire', Typing.dual('grass', 'water'), chart), 1.0);
    });
    test('×0 dominates: electric vs ground/water = 0× · 2× = 0×', () {
      expect(typeEffectiveness('electric', Typing.dual('ground', 'water'), chart), 0.0);
    });
    test('slot order is irrelevant to the product: water/grass == grass/water', () {
      expect(typeEffectiveness('fire', Typing.dual('water', 'grass'), chart), 1.0);
    });
  });

  group('a missing entry throws, never defaults to 1× (AC#4)', () {
    test('mono defender with an absent pair throws MissingChartEntry', () {
      expect(() => typeEffectiveness('fighting', Typing.mono('steel'), chart),
          throwsA(isA<MissingChartEntry>()));
    });
    test('dual defender whose SECOND slot is missing throws (no silent 1×)', () {
      // fighting→rock = 2× is present but fighting→steel is absent. An impl that
      // swallowed the miss would return 2.0; assert it throws loudly instead.
      expect(() => typeEffectiveness('fighting', Typing.dual('rock', 'steel'), chart),
          throwsA(isA<MissingChartEntry>()));
    });
    test('dual defender whose FIRST slot is missing throws', () {
      expect(() => typeEffectiveness('fighting', Typing.dual('steel', 'rock'), chart),
          throwsA(isA<MissingChartEntry>()));
    });
  });
}
