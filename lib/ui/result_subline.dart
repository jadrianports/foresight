import '../engine/ranking.dart';

/// Composes the HONEST one-line subline for a ranked [pick] from its
/// un-collapsed per-STAB `stabRisk.hits` — the copy half of the "silently-wrong
/// advice is the worst failure" guard applied to strings, not math.
///
/// Pure Dart (imports `engine/` only, NO `package:flutter`) so the honesty
/// invariant is unit-testable with plain `test` — no widget pump.
///
/// THE HONESTY INVARIANT (load-bearing): the output must NEVER say "takes
/// nothing back", "totally safe", or "immune" — the mono-proxy STAB result is a
/// guaranteed-damage FLOOR, not a safety guarantee (coverage moves live outside
/// the model and can only make it worse). So even a 0× (immune) STAB reads
/// "resists" — the floor you can count on, never "immune to everything". EVEN is
/// a calm "Even trade", never "trading blows" (that phrase is the all-fragile
/// banner's, Story 3.5). [lib/engine/stab_risk.dart doc; EXPERIENCE Voice&Tone]
///
/// The tier is taken from [pick] verbatim — never re-derived here (AD-9). The
/// bucket relations mirror the engine's `_classify`: `resists = m <= 0.5`,
/// `neutral = m == 1.0`, `weak = m >= 2.0`. Each STAB slug is first-letter
/// capitalized for DISPLAY only (`dark` → `Dark`), never slug-derived elsewhere.
String honestSubline(RankedPick pick) {
  final hits = pick.stabRisk.hits;
  switch (pick.tier) {
    case Tier.safe:
      // Every STAB resisted-or-immune → the guaranteed-damage floor is low, but
      // it is a floor: "resists", never "takes nothing back".
      return hits.length == 1 ? 'Resists its STAB' : 'Resists both its STABs';
    case Tier.good:
      // ≥1 resisted STAB, the rest neutral, no weakness (engine-guaranteed).
      final resisted = [
        for (final h in hits)
          if (h.multiplier <= 0.5) _cap(h.stabType),
      ];
      final neutral = [
        for (final h in hits)
          if (h.multiplier == 1.0) _cap(h.stabType),
      ];
      return 'Resists its ${resisted.join(' & ')}, '
          'neutral to ${neutral.join(' & ')}';
    case Tier.even:
      return 'Even trade';
    case Tier.risky:
      // Weak to ≥1 STAB (engine-guaranteed). Name the STAB(s) that land hard.
      final weak = [
        for (final h in hits)
          if (h.multiplier >= 2.0) _cap(h.stabType),
      ];
      return 'Takes its ${weak.join(' & ')} STAB hard';
  }
}

/// First-letter-capitalize a lowercase slug for display (`dark` → `Dark`).
/// Display-only — the canonical key stays the lowercase slug (AD-4).
String _cap(String slug) =>
    slug.isEmpty ? slug : slug[0].toUpperCase() + slug.substring(1);
