import 'package:flutter_test/flutter_test.dart';
import 'package:foresight/engine/ranking.dart';
import 'package:foresight/engine/stab_risk.dart';
import 'package:foresight/engine/type_chart.dart';
import 'package:foresight/engine/typing.dart';

// Story 2.4: the CAPSTONE of lib/engine/ — compose Story 2.3's `candidateAnswers`
// (offense-gated survivors) with Story 2.2's `stabRiskFor` (per-STAB defense), classify
// each survivor into an AD-9 tier, and order the one list by the chosen SortMode.
//
// The tier is per-STAB, NEVER a collapsed worst-multiplier (AD-9). Both sort modes order
// the SAME list; every RankedPick always carries its (correct) tier + un-collapsed
// StabRisk, whether or not the tier is used for ordering. Multipliers are exactly
// {0,0.5,1,2}; assert exact equality, NO epsilon. Plain Dart `test()` — no Flutter binding.

/// The canonical Tyranitar (Rock/Dark) fixture — a hand-built, ILLUSTRATIVE sparse chart
/// (like `fixture_chart.dart`), chosen to exercise all four tier branches, NOT a replica
/// of the shipping 324-row chart (AD-2). Every attacking slug present in the chart becomes
/// a `candidateAnswers` candidate, so the two STAB slugs (rock, dark) also need offense
/// rows against the opponent — given non-surviving 1× values so they filter out cleanly.
TypeChart buildRankingFixture() => TypeChart({
      // --- Offense rows (candidate → each opponent STAB); product decides survival ---
      // fighting: 2×·2× = 4× → survives (SAFE below).
      ('fighting', 'rock'): 2.0,
      ('fighting', 'dark'): 2.0,
      // fairy: 1×·2× = 2× → survives (GOOD below).
      ('fairy', 'rock'): 1.0,
      ('fairy', 'dark'): 2.0,
      // bug: 1×·2× = 2× → survives (RISKY below).
      ('bug', 'rock'): 1.0,
      ('bug', 'dark'): 2.0,
      // steel: 2×·1× = 2× → survives (RISKY below).
      ('steel', 'rock'): 2.0,
      ('steel', 'dark'): 1.0,
      // ground: 2×·1× = 2× → survives (EVEN below — added so all four Tier branches run).
      ('ground', 'rock'): 2.0,
      ('ground', 'dark'): 1.0,
      // rock/dark are attackers in the defense rows below, so they enter the universe;
      // give them non-surviving 1× offense so they filter out (not answers).
      ('rock', 'rock'): 1.0,
      ('rock', 'dark'): 1.0,
      ('dark', 'rock'): 1.0,
      ('dark', 'dark'): 1.0,
      // --- Defense rows (opponent STAB → mono proxy of the candidate) — single lookups ---
      // fighting: resists both STABs → SAFE.
      ('rock', 'fighting'): 0.5,
      ('dark', 'fighting'): 0.5,
      // fairy: neutral to Rock (1×), resists Dark (0.5×), no weakness → GOOD.
      // (The AD-9 keystone: a naive collapse mis-yields EVEN/SAFE.)
      ('rock', 'fairy'): 1.0,
      ('dark', 'fairy'): 0.5,
      // bug: weak to Rock (2×) → RISKY.
      ('rock', 'bug'): 2.0,
      ('dark', 'bug'): 1.0,
      // steel: weak to Dark (2×) in this illustrative chart → RISKY (see Dev Notes: the
      // real-chart Steel resists Rock/neutral Dark; the fixture is chart-agnostic).
      ('rock', 'steel'): 1.0,
      ('dark', 'steel'): 2.0,
      // ground: neutral to both STABs → EVEN.
      ('rock', 'ground'): 1.0,
      ('dark', 'ground'): 1.0,
    });

/// Find the ranked pick for [slug] (tests assert by identity, order-independent).
RankedPick _pick(List<RankedPick> ranked, String slug) =>
    ranked.firstWhere((p) => p.attackingType == slug);

void main() {
  group('Tier vocabulary is severity-ordered (AC#2)', () {
    test('enum declaration order is SAFE < GOOD < EVEN < RISKY by index', () {
      expect(Tier.safe.index, 0);
      expect(Tier.good.index, 1);
      expect(Tier.even.index, 2);
      expect(Tier.risky.index, 3);
    });
  });

  group('Canonical Tyranitar (Rock/Dark): all four tiers (AC#1/#6)', () {
    final chart = buildRankingFixture();
    final opponent = Typing.dual('rock', 'dark');

    test('safestFirst tiers each survivor per-STAB and ranks Fighting #1', () {
      final ranked = rank(opponent, chart, SortMode.safestFirst);

      // Fighting (4×, resists both) is SAFE and is element [0] — safest AND hardest-hitting.
      expect(ranked.first.attackingType, 'fighting');
      expect(ranked.first.tier, Tier.safe);
      expect(ranked.first.offense, 4.0);

      // Each survivor's tier, classified per-STAB (never a collapsed worst-multiplier).
      expect(_pick(ranked, 'fighting').tier, Tier.safe);
      expect(_pick(ranked, 'fairy').tier, Tier.good);
      expect(_pick(ranked, 'ground').tier, Tier.even);
      expect(_pick(ranked, 'bug').tier, Tier.risky);
      expect(_pick(ranked, 'steel').tier, Tier.risky);

      // Exactly the five survivors (rock/dark filtered as non-answers).
      expect(ranked.map((p) => p.attackingType).toSet(),
          <String>{'fighting', 'fairy', 'ground', 'bug', 'steel'});
    });

    test('AD-9 keystone: Fairy is GOOD (not EVEN/SAFE) and keeps both STABs un-collapsed',
        () {
      final ranked = rank(opponent, chart, SortMode.safestFirst);
      final fairy = _pick(ranked, 'fairy');

      expect(fairy.tier, Tier.good);
      // The un-collapsed per-STAB data rides along in opponent slot order (rock, dark).
      expect(fairy.stabRisk.hits, <StabHit>[
        StabHit('rock', 1.0),
        StabHit('dark', 0.5),
      ]);
    });
  });

  group('Two sort modes over the SAME list (AC#4)', () {
    final chart = buildRankingFixture();
    final opponent = Typing.dual('rock', 'dark');

    test('safestFirst: tier asc, then offense desc, then slug asc (deterministic)', () {
      final ranked = rank(opponent, chart, SortMode.safestFirst);

      // SAFE(4×) → GOOD(2×) → EVEN(2×) → RISKY(2×, bug<steel by slug tiebreak).
      expect(ranked.map((p) => p.attackingType).toList(),
          <String>['fighting', 'fairy', 'ground', 'bug', 'steel']);
      // Non-decreasing tier severity across the whole list.
      final indices = ranked.map((p) => p.tier.index).toList();
      final sorted = [...indices]..sort();
      expect(indices, sorted);
    });

    test('hardestHitting: offense desc regardless of tier, tiers STILL attached', () {
      final ranked = rank(opponent, chart, SortMode.hardestHitting);

      // Fighting 4× leads; the four 2× picks follow by the slug tiebreak — tier ignored
      // for ORDERING but every row still carries its correct tier.
      expect(ranked.map((p) => p.attackingType).toList(),
          <String>['fighting', 'bug', 'fairy', 'ground', 'steel']);
      // Offense is non-increasing down the list.
      final offenses = ranked.map((p) => p.offense).toList();
      final desc = [...offenses]..sort((a, b) => b.compareTo(a));
      expect(offenses, desc);
      // Tiers remain correct even though unused for ordering.
      expect(_pick(ranked, 'fighting').tier, Tier.safe);
      expect(_pick(ranked, 'fairy').tier, Tier.good);
      expect(_pick(ranked, 'ground').tier, Tier.even);
      expect(_pick(ranked, 'bug').tier, Tier.risky);
      expect(_pick(ranked, 'steel').tier, Tier.risky);
    });
  });

  group('All-RISKY opponent — the Story 3.5 all-fragile precondition (AC#6)', () {
    test('every survivor is RISKY; list is non-empty and ordered by offense desc', () {
      // Both survivors are weak to ≥1 STAB → all RISKY.
      final chart = TypeChart({
        ('bug', 'rock'): 1.0, ('bug', 'dark'): 2.0, // offense 2× → survives
        ('steel', 'rock'): 2.0, ('steel', 'dark'): 1.0, // offense 2× → survives
        ('rock', 'rock'): 1.0, ('rock', 'dark'): 1.0, // filler → filtered
        ('dark', 'rock'): 1.0, ('dark', 'dark'): 1.0, // filler → filtered
        ('rock', 'bug'): 2.0, ('dark', 'bug'): 1.0, // bug weak to Rock → RISKY
        ('rock', 'steel'): 1.0, ('dark', 'steel'): 2.0, // steel weak to Dark → RISKY
      });

      final ranked = rank(Typing.dual('rock', 'dark'), chart, SortMode.safestFirst);

      expect(ranked, isNotEmpty);
      expect(ranked.every((p) => p.tier == Tier.risky), isTrue);
      expect(ranked.map((p) => p.attackingType).toList(), <String>['bug', 'steel']);
    });
  });

  group('No-survivors opponent → empty list, no throw (AC#6)', () {
    test('nothing reaches ≥ 2× → rank returns []', () {
      // Every attacking type is neutral (1×) into the opponent — no answers.
      final chart = TypeChart({
        ('fire', 'normal'): 1.0,
        ('water', 'normal'): 1.0,
      });

      expect(rank(Typing.mono('normal'), chart, SortMode.safestFirst), isEmpty);
      expect(rank(Typing.mono('normal'), chart, SortMode.hardestHitting), isEmpty);
    });
  });

  group('Fail-loud through rank — a missing chart row throws (AC#5)', () {
    test('an absent (attacking, defending) row propagates MissingChartEntry', () {
      // `fire` enters the universe via fire→grass, but ('fire','ghost') is deliberately
      // absent — the miss must throw through rank, never a silent 1× that could mis-tier.
      final chart = TypeChart({
        ('fire', 'grass'): 2.0, // puts `fire` in attackingTypes
        // ('fire','ghost') intentionally ABSENT.
      });

      expect(() => rank(Typing.mono('ghost'), chart, SortMode.safestFirst),
          throwsA(isA<MissingChartEntry>()));
    });
  });

  group('RankedPick is a structural value (tests compare/order these)', () {
    test('== and hashCode are by (attackingType, offense, tier, stabRisk)', () {
      final a = RankedPick(
          'fairy', 2.0, Tier.good, StabRisk('fairy', [StabHit('rock', 1.0)]));
      final b = RankedPick(
          'fairy', 2.0, Tier.good, StabRisk('fairy', [StabHit('rock', 1.0)]));
      final c = RankedPick(
          'fairy', 2.0, Tier.risky, StabRisk('fairy', [StabHit('rock', 1.0)]));

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == c, isFalse);
    });
  });
}
