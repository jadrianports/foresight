import 'package:flutter_test/flutter_test.dart';
import 'package:foresight/engine/type_chart.dart';

import 'fixture_chart.dart';

void main() {
  final chart = buildFixtureChart();

  test('multiplierFor returns the stored multiplier (AC#1)', () {
    expect(chart.multiplierFor('fire', 'grass'), 2.0);
    expect(chart.multiplierFor('fire', 'water'), 0.5);
    expect(chart.multiplierFor('fire', 'electric'), 1.0);
    expect(chart.multiplierFor('normal', 'ghost'), 0.0);
  });

  test('multiplierFor throws MissingChartEntry for an absent pair — never 1× (AC#4)', () {
    expect(() => chart.multiplierFor('fighting', 'steel'),
        throwsA(isA<MissingChartEntry>()));
  });

  test('a wrong-case slug misses the chart and throws (no lowercase coercion)', () {
    // Capitalization is UI-only; the engine keys on lowercase slugs. 'Fire' is a
    // different key → loud miss, surfacing the caller's bug rather than a silent 1×.
    expect(() => chart.multiplierFor('Fire', 'grass'),
        throwsA(isA<MissingChartEntry>()));
  });

  test('MissingChartEntry carries the offending slugs in its message', () {
    final err = MissingChartEntry('fighting', 'steel');
    expect(err.attacking, 'fighting');
    expect(err.defending, 'steel');
    expect(err.toString(), contains('fighting'));
    expect(err.toString(), contains('steel'));
  });
}
