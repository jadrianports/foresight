import 'package:foresight/data/pokemon_queries.dart';
import 'package:foresight/engine/type_chart.dart';

/// A crafted chart + opponent for the Story 3.4 Result/tap tests — one that
/// yields ONE survivor per tier so the row rendering, order, and RISKY treatment
/// can be asserted deterministically. NEVER the real 1100-row/324-cell DB (that
/// is not a widget concern; project-context #Testing-Rules).
///
/// The canonical Tyranitar (rock/dark) opponent. Chart cells are hand-picked so
/// `rank(Typing(['rock','dark']), chart, safestFirst)` yields, in order:
///   1. Fighting  4×  SAFE  (resists both STABs)
///   2. Fairy     2×  GOOD  (resists Dark, neutral to Rock)
///   3. Bug       2×  EVEN  (neutral to both STABs)
///   4. Ground    2×  RISKY (weak to the Rock STAB)
///
/// NOTE the chart is DENSE ENOUGH: `rank` iterates `chart.attackingTypes` (every
/// distinct first-slug in the keys — including `rock`/`dark`, which the STAB-
/// direction rows introduce), so an offense row into BOTH rock and dark exists
/// for each. `water`/`rock`/`dark` are present but < 2× so they're gated out
/// (proving the SE gate) and never reach a STAB lookup.
const rockDarkOpponent = ['rock', 'dark'];

PokemonListItem buildRockDarkOpponent() => PokemonListItem(
      id: 248,
      name: 'Tyranitar',
      formLabel: null,
      spritePath: 'assets/sprites/__nope_248__.png',
      types: rockDarkOpponent,
    );

TypeChart buildResultChart() => TypeChart({
      // ---- offense direction: (attacking, defending∈{rock,dark}) ----
      // Survivors (≥ 2×):
      ('fighting', 'rock'): 2.0, ('fighting', 'dark'): 2.0, // 4× SAFE
      ('fairy', 'rock'): 1.0, ('fairy', 'dark'): 2.0, //       2× GOOD
      ('bug', 'rock'): 2.0, ('bug', 'dark'): 1.0, //           2× EVEN
      ('ground', 'rock'): 2.0, ('ground', 'dark'): 1.0, //     2× RISKY
      // Gated out (< 2×) — offense rows still required for the universe scan:
      ('water', 'rock'): 1.0, ('water', 'dark'): 1.0,
      ('rock', 'rock'): 1.0, ('rock', 'dark'): 1.0,
      ('dark', 'rock'): 1.0, ('dark', 'dark'): 0.5,
      // ---- STAB direction: (opponentStab∈{rock,dark}, candidateProxy) ----
      ('rock', 'fighting'): 0.5, ('dark', 'fighting'): 0.5, // both resisted → SAFE
      ('rock', 'fairy'): 1.0, ('dark', 'fairy'): 0.5, //       neutral+resist → GOOD
      ('rock', 'bug'): 1.0, ('dark', 'bug'): 1.0, //           both neutral → EVEN
      ('rock', 'ground'): 2.0, ('dark', 'ground'): 1.0, //     weak → RISKY
    });

/// A crafted opponent + chart where EVERY super-effective survivor is RISKY —
/// the Story 3.5 all-fragile case. `rank(Typing(['rock','flying']), chart, ...)`
/// yields, hardest-hitting:
///   1. Water    4×  RISKY (4× offense; weak to the Rock STAB)
///   2. Electric 2×  RISKY (2× offense; weak to the Rock STAB)
/// Two survivors at DIFFERENT offense (4× vs 2×) so the hardest-hitting order
/// (bigger hit on top) is assertable, and BOTH RISKY so `isAllFragile` is true.
///
/// Mirrors `buildResultChart`'s density: `rock`/`flying` appear as attacking
/// slugs (introduced by the STAB-direction rows), so offense rows into both
/// opponent slots exist for every universe type — they're gated out at 1×.
const allFragileOpponent = ['rock', 'flying'];

PokemonListItem buildAllFragileOpponent() => PokemonListItem(
      id: 700,
      name: 'Fragilemon',
      formLabel: null,
      spritePath: 'assets/sprites/__nope_700__.png',
      types: allFragileOpponent,
    );

TypeChart buildAllFragileChart() => TypeChart({
      // ---- offense direction: (attacking, defending∈{rock,flying}) ----
      // Survivors (≥ 2×), both RISKY:
      ('water', 'rock'): 2.0, ('water', 'flying'): 2.0, //     4× RISKY
      ('electric', 'rock'): 2.0, ('electric', 'flying'): 1.0, // 2× RISKY
      // Gated out (< 2×) — offense rows still required for the universe scan
      // (rock/flying enter the universe via the STAB rows below):
      ('rock', 'rock'): 1.0, ('rock', 'flying'): 1.0,
      ('flying', 'rock'): 1.0, ('flying', 'flying'): 1.0,
      // ---- STAB direction: (opponentStab∈{rock,flying}, candidateProxy) ----
      ('rock', 'water'): 2.0, ('flying', 'water'): 1.0, //     weak → RISKY
      ('rock', 'electric'): 2.0, ('flying', 'electric'): 1.0, // weak → RISKY
    });

/// A crafted opponent with NO super-effective survivor → `rank` returns `[]`
/// (a legitimate empty state, AC#10). Mono `normal` where the only attacking
/// type in the chart is neutral into it, so the SE gate empties the answer set.
PokemonListItem buildNoAnswerOpponent() => PokemonListItem(
      id: 999,
      name: 'Blankmon',
      formLabel: null,
      spritePath: 'assets/sprites/__nope_999__.png',
      types: const ['normal'],
    );

TypeChart buildNoAnswerChart() => TypeChart({
      ('water', 'normal'): 1.0, // 1× → gated out → rank() == []
    });
