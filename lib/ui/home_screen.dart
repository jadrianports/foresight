import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/pokemon_queries.dart';
import '../engine/type_chart.dart';
import '../recents_controller.dart';
import '../theme/cartridge_colors.dart';
import '../theme/cartridge_physics.dart';
import '../theme/cartridge_typography.dart';
import 'result_screen.dart';
import 'widgets/empty_recents.dart';
import 'widgets/form_badge.dart';
import 'widgets/recent_tile.dart';
import 'widgets/search_field.dart';
import 'widgets/sprite_tile.dart';

/// Home: the app-title wordmark, a live-search bar (Story 3.2), a horizontal
/// Recent strip (Story 3.7), then a full-dex 3-column sprite grid (Story 3.1).
/// Typing narrows the grid IN PLACE on every keystroke — never a submit, never a
/// navigation. The form badge (3.3) and tap→Result (3.4) compose over the grid;
/// the sort toggle (3.6) lives on Result. The IA is wordmark → search → recent →
/// grid (UX-DR7 / DESIGN Layout), the sections separated by `spacing.5`.
///
/// The Recent strip (AC#5/#6) reads `context.watch<RecentsController>().recents`
/// (the app's one writable surface, AD-5/AD-6): newest-first `RecentTile`s that
/// reopen `ResultScreen` on tap (moving that opponent to the front on return via
/// the controller notify), or the honest [EmptyRecents] line when there's no
/// history — with the grid fully populated below either way. The remaining a11y/
/// motion polish (≥44pt targets, `Semantics`, dynamic-type) is Story 3.8.
///
/// [pokemon] is already-resolved data injected from the composition root
/// (`main()`) — the UI never queries the DB (AD-6). So there is NO
/// `FutureBuilder`, spinner, or loading branch anywhere (NFR2): the grid renders
/// synchronously on the first frame under the native splash, and filtering is a
/// trivial in-memory linear scan (no debounce, no async).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.pokemon, required this.chart});

  /// The full bundled dex (~1100 items), ordered by id, injected by `main()`.
  /// Immutable and never mutated — the filtered view is derived in `build()`.
  final List<PokemonListItem> pokemon;

  /// The in-memory type chart injected from `main()`. HomeScreen only carries it
  /// to hand to the pushed [ResultScreen] on tap (Story 3.4) — the grid itself
  /// never consults it. Constructor injection, same as [pokemon]; NOT a
  /// controller/Provider (an injected value object is neither shared nor
  /// persisted state — AD-6).
  final TypeChart chart;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// The live query. Transient, single-screen UI state → `setState`, NOT a
  /// controller (AD-6: only shared/persisted state uses the sanctioned
  /// `ChangeNotifier`s; search text is neither).
  String _query = '';

  /// Owned here so `SearchField` stays stateless and a programmatic clear (and
  /// the current text) has a single source of truth.
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CartridgeColors>()!;

    // The recents strip data (AC#5) — `watch` so a `recordView` notify (from the
    // pushed ResultScreen on return) rebuilds Home and floats that opponent to
    // the front. Newest-first, already resolved to display items (AD-6).
    final recents = context.watch<RecentsController>().recents;

    // Filter is a pure derivation of (injected list + query) — never cached,
    // never mutating `widget.pokemon`. FOLDED substring on `name` only (AC#5):
    // `_fold` case-folds, strips diacritics, and drops non-alphanumerics on both
    // sides, so accent-/punctuation-free queries still reach names that carry
    // them (`flabebe`→Flabébé, `mr mime`→Mr. Mime, `type null`→Type: Null,
    // `nidoran`→Nidoran♀/♂). Folding also absorbs the trim — a whitespace-only
    // query folds to '' ⇒ the full un-filtered grid (AC#2).
    final query = _fold(_query);
    final visible = query.isEmpty
        ? widget.pokemon
        : [
            for (final p in widget.pokemon)
              if (_fold(p.name).contains(query)) p,
          ];
    // The no-results line only appears once the user has typed something that
    // matched nothing — an empty query is always "full grid" (AC#2/#3), never
    // the no-match state (guards the degenerate empty-dex/test case too).
    final noMatch = query.isNotEmpty && visible.isEmpty;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(CartridgePhysics.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Home wordmark — "FORESIGHT" with the primary-red dot accent
              // (DESIGN app-title). This is the brand-shout at the top of Home.
              Padding(
                padding: const EdgeInsets.only(bottom: CartridgePhysics.s4),
                child: Text.rich(
                  TextSpan(
                    text: 'FORESIGHT',
                    children: [
                      TextSpan(
                        text: '.',
                        style: TextStyle(color: colors.primaryRed),
                      ),
                    ],
                  ),
                  style: CartridgeTypography.appTitle.copyWith(color: colors.ink),
                ),
              ),
              SearchField(
                controller: _controller,
                onChanged: (value) => setState(() => _query = value),
              ),
              // s5 separates search → recent (DESIGN Layout: spacing.5–6 separate
              // major sections). The recent strip is a distinct, minor section.
              const SizedBox(height: CartridgePhysics.s5),
              // Recent strip (AC#5) OR the honest empty state (AC#6). A fixed-
              // height section that never steals the grid's vertical space — the
              // grid keeps the Expanded below.
              recents.isEmpty
                  ? const EmptyRecents()
                  : _recentStrip(recents),
              const SizedBox(height: CartridgePhysics.s5),
              Expanded(
                child: noMatch
                    ? _NoResults(colors: colors)
                    // GridView.builder lazily builds only visible tiles —
                    // mandatory for the large dex so paint stays instant (NFR2),
                    // and stays lazy over the FILTERED list too.
                    : GridView.builder(
                        padding: EdgeInsets.zero,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: CartridgePhysics.s3,
                          crossAxisSpacing: CartridgePhysics.s3,
                          childAspectRatio: 0.82,
                        ),
                        itemCount: visible.length,
                        itemBuilder: (context, i) => _tappableTile(visible[i]),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// A grid cell made tappable (Story 3.4): a tap pushes [ResultScreen] for the
  /// tapped item onto a plain `MaterialPageRoute` (Home → Result, back via the
  /// app-bar chevron; NO hero animation on open — EXPERIENCE IA). We WRAP the
  /// [_tile] output rather than add an `onTap` to [SpriteTile] (AC#9: the tile
  /// stays a pure primitive; its doc reserves the tap for "Story 3.4 wraps it").
  /// The chart carried from `main()` rides along so Result renders synchronously
  /// with no DB access (AD-6/NFR2).
  Widget _tappableTile(PokemonListItem item) {
    return GestureDetector(
      onTap: () => _openResult(item),
      child: _tile(item),
    );
  }

  /// The single Home → Result push, SHARED by grid tiles and recent tiles (AC#5)
  /// so both open the same [ResultScreen] with the same injected [chart]. A
  /// recent-tile tap therefore re-records the opponent (Result records on mount),
  /// floating it to the front of the strip on return (AD-6).
  void _openResult(PokemonListItem item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResultScreen(opponent: item, chart: widget.chart),
      ),
    );
  }

  /// The horizontal Recent strip: a fixed-height, horizontally-scrolling row of
  /// newest-first [RecentTile]s (AC#5). Fixed height so it never consumes the
  /// grid's vertical space; on a narrow screen it scrolls sideways, never wraps.
  Widget _recentStrip(List<PokemonListItem> recents) {
    return SizedBox(
      height: _recentStripHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: recents.length,
        separatorBuilder: (_, _) =>
            const SizedBox(width: CartridgePhysics.s3),
        itemBuilder: (context, i) {
          final item = recents[i];
          return SizedBox(
            width: _recentTileWidth,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _openResult(item),
              child: RecentTile(item),
            ),
          );
        },
      ),
    );
  }

  /// Strip height = 64px sprite + s1 gap + one name line, with headroom so the
  /// name never clips before the Story 3.8 dynamic-type pass.
  static const double _recentStripHeight = 92;

  /// Each recent tile's fixed width — a touch wider than the 64px sprite so short
  /// names center and long ones ellipsize tidily.
  static const double _recentTileWidth = 76;

  /// One grid cell. A base form (`formLabel == null`) is the bare Story 3.1
  /// [SpriteTile] — no Stack, no badge. A typing-distinct form overhangs a
  /// [FormBadge] on the tile's top-right via a `Clip.none` `Stack` so the badge
  /// spills 3px into the s3 gutter (AC#1/#5/#7). We COMPOSE — [SpriteTile] is
  /// untouched (AC#7); the badge text is the row's `formLabel` verbatim, never
  /// slug-derived (AD-4). The overlay rides the already-filtered `visible` list,
  /// so it's automatically additive to search (AC#8).
  Widget _tile(PokemonListItem item) {
    final label = item.formLabel;
    if (label == null) return SpriteTile(item);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        SpriteTile(item),
        Positioned(
          top: -CartridgePhysics.badgeOverhang,
          right: -CartridgePhysics.badgeOverhang,
          child: FormBadge(label),
        ),
      ],
    );
  }
}

/// Fold a name or query for forgiving matching (Story 3.2 review): lowercase,
/// map common Latin-1 diacritics to their ASCII base, and drop every
/// non-alphanumeric character (spaces, `. ' : -`, the ♀/♂ symbols). Applied to
/// BOTH the dex name and the query so an accent-/punctuation-free query still
/// reaches names that carry them — otherwise `mr mime` / `flabebe` / `type null`
/// fall to the no-results line for Pokémon that exist.
///
/// Dependency-free by design (NFR6): dart:core has no Unicode NFD normalize, and
/// the bundled dex's only diacritic is `é` — the small fold map covers it with
/// headroom. A *decomposed* accent (base + combining mark) also folds correctly:
/// the combining mark is non-alphanumeric and is dropped, leaving the base.
String _fold(String s) {
  const deaccent = <String, String>{
    'á': 'a', 'à': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a',
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
    'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
    'ó': 'o', 'ò': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o',
    'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
    'ñ': 'n', 'ç': 'c',
  };
  final buf = StringBuffer();
  for (final ch in s.toLowerCase().split('')) {
    final mapped = deaccent[ch] ?? ch;
    final code = mapped.codeUnitAt(0);
    final isDigit = code >= 0x30 && code <= 0x39; // 0-9
    final isAlpha = code >= 0x61 && code <= 0x7a; // a-z (already lowercased)
    if (isDigit || isAlpha) buf.write(mapped);
  }
  return buf.toString();
}

/// AC#3: when a typed query matches nothing, the grid is replaced by ONE honest
/// line of body copy — verbatim, no spinner, no skeleton, no "did you mean"
/// suggestions, no error chrome. `Text` wraps (not a hard-clipped box) so the
/// deferred Story 3.8 dynamic-type pass stays unblocked.
class _NoResults extends StatelessWidget {
  const _NoResults({required this.colors});

  final CartridgeColors colors;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'No Pokémon match that. Check the spelling?',
        style: CartridgeTypography.body.copyWith(color: colors.inkMuted),
        textAlign: TextAlign.center,
      ),
    );
  }
}
