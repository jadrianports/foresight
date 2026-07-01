// Pure unit tests for honestSubline (Story 3.4 Task 4). No widget pump, no
// Flutter binding — the file imports engine/ + the pure builder only, so the
// HONESTY INVARIANT is enforceable with plain `test`. This is the "silently-
// wrong advice" guard applied to copy: the load-bearing assertions are the tier
// phrasings AND that no output ever claims total safety / immunity.

import 'package:flutter_test/flutter_test.dart';

import 'package:foresight/engine/ranking.dart';
import 'package:foresight/engine/stab_risk.dart';
import 'package:foresight/ui/result_subline.dart';

/// Build a RankedPick for [tier] from raw per-STAB hits (candidateType is
/// immaterial to the subline copy — only the hits + tier matter).
RankedPick pickFor(Tier tier, List<StabHit> hits, {double offense = 2}) =>
    RankedPick('candidate', offense, tier, StabRisk('candidate', hits));

/// Every banned phrase the honesty contract forbids (case-insensitive).
const _banned = ['takes nothing', 'totally safe', 'immune'];

void expectHonest(String subline) {
  final lower = subline.toLowerCase();
  for (final phrase in _banned) {
    expect(lower.contains(phrase), isFalse,
        reason: 'subline "$subline" must never contain "$phrase"');
  }
}

void main() {
  test('SAFE mono → "Resists its STAB"', () {
    final s = honestSubline(pickFor(Tier.safe, [StabHit('grass', 0.5)]));
    expect(s, 'Resists its STAB');
    expectHonest(s);
  });

  test('SAFE dual → "Resists both its STABs"', () {
    final s = honestSubline(
        pickFor(Tier.safe, [StabHit('rock', 0.5), StabHit('dark', 0.5)]));
    expect(s, 'Resists both its STABs');
    expectHonest(s);
  });

  test('SAFE reads a 0× (immune) STAB as "resists", never "immune"', () {
    // A 0× STAB is the guaranteed-damage FLOOR, not total safety — it must still
    // read "resists" and must NOT leak the word "immune".
    final s = honestSubline(
        pickFor(Tier.safe, [StabHit('ghost', 0.0), StabHit('normal', 0.5)]));
    expect(s, 'Resists both its STABs');
    expectHonest(s);
  });

  test('GOOD → names the resisted + neutral STABs (Fairy vs Tyranitar)', () {
    // hits: neutral to Rock (1×), resists Dark (0.5×) → "Resists its Dark,
    // neutral to Rock" (the canonical AD-9 GOOD case).
    final s = honestSubline(
        pickFor(Tier.good, [StabHit('rock', 1.0), StabHit('dark', 0.5)]));
    expect(s, 'Resists its Dark, neutral to Rock');
    expectHonest(s);
  });

  test('EVEN → calm "Even trade" (never "trading blows")', () {
    final s = honestSubline(
        pickFor(Tier.even, [StabHit('rock', 1.0), StabHit('dark', 1.0)]));
    expect(s, 'Even trade');
    expect(s.toLowerCase().contains('trading blows'), isFalse);
    expectHonest(s);
  });

  test('RISKY → "Takes its Rock STAB hard"', () {
    final s = honestSubline(
        pickFor(Tier.risky, [StabHit('rock', 2.0), StabHit('dark', 1.0)]));
    expect(s, 'Takes its Rock STAB hard');
    expectHonest(s);
  });

  test('RISKY dual weakness names both STABs', () {
    final s = honestSubline(
        pickFor(Tier.risky, [StabHit('rock', 2.0), StabHit('dark', 2.0)]));
    expect(s, 'Takes its Rock & Dark STAB hard');
    expectHonest(s);
  });
}
