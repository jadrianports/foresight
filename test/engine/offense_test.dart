import 'package:flutter_test/flutter_test.dart';
import 'package:foresight/engine/offense.dart';
import 'package:foresight/engine/type_chart.dart';
import 'package:foresight/engine/typing.dart';

// Story 2.3: the OFFENSIVE half of §4.2 — assemble each attacking type's offense against
// the opponent (the FORWARD direction, candidate ATTACKS opponent), then HARD-FILTER 0×
// and GATE to ≥ 2×. Only super-effective types survive as answers, each carrying its
// multiplier; tiering/ranking is Story 2.4.
//
// Each test builds its own SPARSE chart so `chart.attackingTypes` (the universe
// candidateAnswers iterates) is exactly the slugs under test — never the full chart (AD-2).
// Multipliers are exactly {0,0.5,1,2}; assert exact equality, NO epsilon.
void main() {
  group('0× offense is a HARD filter — removed entirely (AC#2/#5)', () {
    test('a Ghost opponent drops Normal AND Fighting (both 0×)', () {
      // Normal and Fighting are both immune-against (0×) into Ghost; an SE attacker (Dark,
      // Ghost) survives. The PRD §4.3 canonical immunity example.
      final chart = TypeChart({
        ('normal', 'ghost'): 0.0, // immune → must be removed
        ('fighting', 'ghost'): 0.0, // immune → must be removed
        ('dark', 'ghost'): 2.0, // SE survivor
        ('ghost', 'ghost'): 2.0, // SE survivor
      });

      final answers = candidateAnswers(Typing.mono('ghost'), chart);
      final survivors = answers.map((a) => a.attackingType).toSet();

      expect(survivors, containsAll(<String>['dark', 'ghost']));
      expect(survivors, isNot(contains('normal')));
      expect(survivors, isNot(contains('fighting')));
    });

    test('a Flying opponent drops Ground (0×)', () {
      final chart = TypeChart({
        ('ground', 'flying'): 0.0, // immune → must be removed
        ('rock', 'flying'): 2.0, // SE survivor
        ('electric', 'flying'): 2.0, // SE survivor
      });

      final answers = candidateAnswers(Typing.mono('flying'), chart);
      final survivors = answers.map((a) => a.attackingType).toSet();

      expect(survivors, containsAll(<String>['rock', 'electric']));
      expect(survivors, isNot(contains('ground')));
    });
  });

  group('super-effective gate — only ≥ 2× are answers (AC#2/#3)', () {
    test('a 1× (neutral) and a 0.5× (resisted) type never appear', () {
      // Proves the gate drops neutral-or-worse, not just 0×: only the SE attacker survives.
      final chart = TypeChart({
        ('fighting', 'steel'): 2.0, // SE → survives
        ('water', 'steel'): 1.0, // neutral → excluded
        ('grass', 'steel'): 0.5, // resisted → excluded
      });

      final answers = candidateAnswers(Typing.mono('steel'), chart);
      final survivors = answers.map((a) => a.attackingType).toSet();

      expect(survivors, <String>{'fighting'});
      expect(survivors, isNot(contains('water')));
      expect(survivors, isNot(contains('grass')));
    });
  });

  group('a ≥ 2× survivor keeps its multiplier (AC#1)', () {
    test('a 2× survivor carries offense 2×', () {
      final chart = TypeChart({('fire', 'grass'): 2.0});

      final answers = candidateAnswers(Typing.mono('grass'), chart);

      expect(answers, <OffensePick>[OffensePick('fire', 2.0)]);
      expect(answers.single.offense, 2.0);
    });

    test('a dual opponent both slots hit 2× yields a 4× survivor (forward product)', () {
      // Fighting vs Tyranitar (rock/dark): 2× · 2× = 4×, exercising the forward-direction
      // dual product — the OPPOSITE direction of Story 2.2's STAB-risk.
      final chart = TypeChart({
        ('fighting', 'rock'): 2.0,
        ('fighting', 'dark'): 2.0,
      });

      final answers = candidateAnswers(Typing.dual('rock', 'dark'), chart);

      expect(answers, <OffensePick>[OffensePick('fighting', 4.0)]);
      expect(answers.single.offense, 4.0);
    });
  });

  group('fail-loud carries through the gate (AC#4/#5)', () {
    test('a candidate whose offense row is absent propagates MissingChartEntry', () {
      // `fire` is in the universe (via fire→grass) but ('fire','ghost') is deliberately
      // absent. The miss must throw through the gate, never default to a silent 1× that
      // could slip a non-answer past the ≥ 2× threshold (AD-7).
      final chart = TypeChart({
        ('fire', 'grass'): 2.0, // puts `fire` in attackingTypes
        // ('fire','ghost') intentionally ABSENT.
      });

      expect(() => candidateAnswers(Typing.mono('ghost'), chart),
          throwsA(isA<MissingChartEntry>()));
    });
  });

  group('OffensePick is a structural value (Story 2.4 compares/orders these)', () {
    test('== and hashCode are by (attackingType, offense)', () {
      expect(OffensePick('dark', 2.0), OffensePick('dark', 2.0));
      expect(OffensePick('dark', 2.0).hashCode, OffensePick('dark', 2.0).hashCode);
      expect(OffensePick('dark', 2.0) == OffensePick('dark', 4.0), isFalse);
      expect(OffensePick('dark', 2.0) == OffensePick('ghost', 2.0), isFalse);
    });
  });
}
