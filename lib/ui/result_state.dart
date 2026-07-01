import '../engine/ranking.dart';

/// The pure, unit-tested ALL-FRAGILE predicate (Story 3.5) — the whole honesty
/// trigger for the [HonestBanner], made enforceable in plain `test` with no
/// widget pump. Mirrors the `honestSubline` precedent: a load-bearing copy /
/// honesty invariant lives in a flutter-free file (imports `engine/` ONLY) so
/// the trigger cannot silently mis-fire. [project-context "The worst failure is
/// silently-wrong advice"; lib/ui/result_subline.dart]
///
/// True IFF `rank(...)` returned at least one pick AND EVERY pick is RISKY — the
/// "every super-effective answer is fragile" state that leads with one honest
/// banner instead of a wall of ⚠ rows (AC#1). It only READS the engine's
/// already-decided `pick.tier` verbatim; it never re-derives a tier or
/// re-inspects a multiplier (AD-9).
///
/// The `isNotEmpty` guard is LOAD-BEARING — two distinct non-triggers:
///   - An empty `[]` is the degenerate "no super-effective attacker at all"
///     state (Gen 6+ makes it practically unreachable, but the engine can
///     return it). It is NOT "trading blows" — it keeps Story 3.4's header +
///     zero-rows behavior, with NO banner (AC#4).
///   - A present EVEN / GOOD / SAFE pick means at least one line is not fragile;
///     "trading blows" is reserved for when EVERY line is. A lone EVEN pick
///     reads the calm "Even trade" subline (Story 3.4 `honestSubline`) — the
///     banner must NOT appear. Hence `every(risky)`, never `any(risky)` (AC#3).
bool isAllFragile(List<RankedPick> picks) =>
    picks.isNotEmpty && picks.every((p) => p.tier == Tier.risky);
