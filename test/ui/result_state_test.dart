// Pure unit tests for isAllFragile (Story 3.5 Task 5). No widget pump, no
// Flutter binding — the file imports engine/ + the pure predicate only, so the
// ALL-FRAGILE honesty TRIGGER is enforceable with plain `test`. This is the
// "silently-wrong advice" guard applied to a whole screen state: the banner
// must fire on all-RISKY, and NEVER on empty / a present EVEN-GOOD-SAFE pick.

import 'package:flutter_test/flutter_test.dart';

import 'package:foresight/engine/ranking.dart';
import 'package:foresight/engine/stab_risk.dart';
import 'package:foresight/ui/result_state.dart';

/// Build a RankedPick for [tier] (the hits are immaterial to the predicate —
/// only `pick.tier` is read; construct a plausible StabRisk anyway).
RankedPick pickFor(Tier tier, {double offense = 2}) => RankedPick(
      'candidate',
      offense,
      tier,
      StabRisk('candidate', [StabHit('rock', tier == Tier.risky ? 2.0 : 1.0)]),
    );

void main() {
  test('true when every pick is RISKY (all-fragile)', () {
    expect(
      isAllFragile([pickFor(Tier.risky), pickFor(Tier.risky)]),
      isTrue,
    );
  });

  test('false for [] — the degenerate "no SE attacker" state, NOT all-fragile',
      () {
    // AC#4: an empty answer is a DIFFERENT surface (Story 3.4 header + zero
    // rows). The isNotEmpty guard is load-bearing.
    expect(isAllFragile(const []), isFalse);
  });

  test('false for a single EVEN pick — "Even trade" ≠ "trading blows"', () {
    // AC#3: a lone EVEN pick reads the calm subline; the banner must not fire.
    expect(isAllFragile([pickFor(Tier.even)]), isFalse);
  });

  test('false for any mixed list containing a non-RISKY pick', () {
    // every(risky), never any(risky): one safer line disqualifies the banner.
    expect(isAllFragile([pickFor(Tier.safe), pickFor(Tier.risky)]), isFalse);
    expect(isAllFragile([pickFor(Tier.risky), pickFor(Tier.good)]), isFalse);
  });
}
