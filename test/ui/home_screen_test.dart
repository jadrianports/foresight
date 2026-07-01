// Widget tests for the Story 3.1 sprite grid. Effort is matched to risk
// (project-context #Testing-Rules): the load-bearing test is the AC#4 SOFT-
// DEGRADE path — a missing sprite must render name + type chips and throw NO
// exception (silently-wrong/broken tiles are the failure this story can ship).
// We don't golden or pixel-assert boring layout.
//
// Under `flutter test` the asset bundle has no sprites, so EVERY Image.asset
// fails and the errorBuilder fires — which is exactly what exercises the degrade
// path deterministically. We pump a frame so the image resolution fails before
// asserting.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:foresight/data/pokemon_queries.dart';
import 'package:foresight/theme/cartridge_theme.dart';
import 'package:foresight/ui/home_screen.dart';
import 'package:foresight/ui/widgets/sprite_tile.dart';
import 'package:foresight/ui/widgets/type_chip.dart';

/// A few fake items — never the real 1100-row DB (that's not a widget concern).
final _fakeDex = <PokemonListItem>[
  PokemonListItem(
    id: 1,
    name: 'Bulbasaur',
    formLabel: null,
    spritePath: 'assets/sprites/__nope_1__.png',
    types: ['grass', 'poison'],
  ),
  PokemonListItem(
    id: 4,
    name: 'Charmander',
    formLabel: null,
    spritePath: 'assets/sprites/__nope_4__.png',
    types: ['fire'],
  ),
  PokemonListItem(
    id: 25,
    name: 'Pikachu',
    formLabel: null,
    spritePath: 'assets/sprites/__nope_25__.png',
    types: ['electric'],
  ),
];

/// Story 3.2 search fixture. Crucially, BOTH Ninetales rows carry the same
/// display `name` ('Ninetales') — the Alolan form's distinction is `formLabel`
/// (a Story 3.3 badge), never the name (AC#4 / verified DB). So a case-
/// insensitive `name.contains('nine')` naturally keeps both and drops the
/// decoys. Bogus sprite paths hit the (unrelated) degrade path under test — fine.
final _searchDex = <PokemonListItem>[
  PokemonListItem(
    id: 38,
    name: 'Ninetales',
    formLabel: null,
    spritePath: 'assets/sprites/__nope_38__.png',
    types: ['fire'],
  ),
  PokemonListItem(
    id: 10104,
    name: 'Ninetales',
    formLabel: 'Alola',
    spritePath: 'assets/sprites/__nope_10104__.png',
    types: ['ice', 'fairy'],
  ),
  PokemonListItem(
    id: 1,
    name: 'Bulbasaur',
    formLabel: null,
    spritePath: 'assets/sprites/__nope_1__.png',
    types: ['grass', 'poison'],
  ),
  PokemonListItem(
    id: 25,
    name: 'Pikachu',
    formLabel: null,
    spritePath: 'assets/sprites/__nope_25__.png',
    types: ['electric'],
  ),
  PokemonListItem(
    id: 6,
    name: 'Charizard',
    formLabel: null,
    spritePath: 'assets/sprites/__nope_6__.png',
    types: ['fire', 'flying'],
  ),
];

/// Story 3.2 review fixture: diacritic + punctuation names (verified in the
/// bundled DB). The filter folds both sides, so accent-/punctuation-free queries
/// must still reach these. Kept SEPARATE from `_searchDex` so the count-based
/// full-grid assertions there stay valid under the lazy `GridView.builder`.
final _foldDex = <PokemonListItem>[
  PokemonListItem(
    id: 669,
    name: 'Flabébé',
    formLabel: null,
    spritePath: 'assets/sprites/__nope_669__.png',
    types: ['fairy'],
  ),
  PokemonListItem(
    id: 122,
    name: 'Mr. Mime',
    formLabel: null,
    spritePath: 'assets/sprites/__nope_122__.png',
    types: ['psychic', 'fairy'],
  ),
  PokemonListItem(
    id: 772,
    name: 'Type: Null',
    formLabel: null,
    spritePath: 'assets/sprites/__nope_772__.png',
    types: ['normal'],
  ),
];

const _noResultsCopy = 'No Pokémon match that. Check the spelling?';

/// Wrap a widget in the Cartridge theme so the CartridgeColors extension resolves.
Widget _host(Widget child) => MaterialApp(
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      home: child,
    );

void main() {
  setUpAll(() {
    // Mirror main(): never reach for the network during tests (AD-1).
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('renders the wordmark and one tile per injected item',
      (tester) async {
    await tester.pumpWidget(_host(HomeScreen(pokemon: _fakeDex)));
    await tester.pump();

    // Wordmark is rich text ("FORESIGHT" + a red "." accent) — match by substring.
    expect(find.textContaining('FORESIGHT'), findsOneWidget);
    expect(find.byType(SpriteTile), findsNWidgets(_fakeDex.length));
    for (final item in _fakeDex) {
      expect(find.text(item.name), findsOneWidget);
    }
  });

  // ----- Story 3.2: live-search filter -----

  testWidgets('AC#2/#10d: an empty query shows the full grid (3.1 intact)',
      (tester) async {
    await tester.pumpWidget(_host(HomeScreen(pokemon: _searchDex)));
    await tester.pump();

    // No query typed → the whole injected dex renders, no no-results line.
    expect(find.byType(SpriteTile), findsNWidgets(_searchDex.length));
    expect(find.text(_noResultsCopy), findsNothing);
  });

  testWidgets('AC#4/#10a: "nine" narrows to exactly the two Ninetales tiles',
      (tester) async {
    await tester.pumpWidget(_host(HomeScreen(pokemon: _searchDex)));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'nine');
    await tester.pump();

    // Both Ninetales rows share name 'Ninetales' → two tiles; decoys hidden.
    expect(find.byType(SpriteTile), findsNWidgets(2));
    expect(find.text('Ninetales'), findsNWidgets(2));
    expect(find.text('Bulbasaur'), findsNothing);
    expect(find.text('Pikachu'), findsNothing);
    expect(find.text('Charizard'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AC#2/#10b: clearing the field restores the full grid',
      (tester) async {
    await tester.pumpWidget(_host(HomeScreen(pokemon: _searchDex)));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'nine');
    await tester.pump();
    expect(find.byType(SpriteTile), findsNWidgets(2));

    // Delete back to empty → the un-filtered full-dex grid returns (AC#2).
    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    expect(find.byType(SpriteTile), findsNWidgets(_searchDex.length));
    expect(find.text(_noResultsCopy), findsNothing);
  });

  testWidgets('AC#3/#10c: a no-match query shows one honest line, no grid/spinner',
      (tester) async {
    await tester.pumpWidget(_host(HomeScreen(pokemon: _searchDex)));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'zzzzz');
    await tester.pump();

    // The grid is replaced by the exact copy — no spinner, no tiles, no throw.
    expect(find.text(_noResultsCopy), findsOneWidget);
    expect(find.byType(SpriteTile), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Review: folded match — accent-/punctuation-free query reaches Flabébé, '
      'Mr. Mime, Type: Null', (tester) async {
    await tester.pumpWidget(_host(HomeScreen(pokemon: _foldDex)));
    await tester.pump();

    // No accent typed → still finds Flabébé (é folded to e).
    await tester.enterText(find.byType(TextField), 'flabebe');
    await tester.pump();
    expect(find.text('Flabébé'), findsOneWidget);
    expect(find.byType(SpriteTile), findsNWidgets(1));

    // No period, space instead of "." → still finds Mr. Mime.
    await tester.enterText(find.byType(TextField), 'mr mime');
    await tester.pump();
    expect(find.text('Mr. Mime'), findsOneWidget);
    expect(find.byType(SpriteTile), findsNWidgets(1));

    // No colon → still finds Type: Null.
    await tester.enterText(find.byType(TextField), 'type null');
    await tester.pump();
    expect(find.text('Type: Null'), findsOneWidget);
    expect(find.byType(SpriteTile), findsNWidgets(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('AC#4 degrade: a missing sprite shows name + type chips, no throw',
      (tester) async {
    final item = PokemonListItem(
      id: 3,
      name: 'Venusaur',
      formLabel: null,
      spritePath: 'assets/sprites/__does_not_exist__.png',
      types: ['grass', 'poison'],
    );

    await tester.pumpWidget(_host(
      Scaffold(body: Center(child: SizedBox(width: 120, height: 140, child: SpriteTile(item)))),
    ));
    // Let the asset resolution fail so the errorBuilder swaps in the fallback.
    await tester.pumpAndSettle();

    // Name still present; a TypeChip per type; no exception surfaced.
    expect(find.text('Venusaur'), findsOneWidget);
    expect(find.byType(TypeChip), findsNWidgets(2));
    expect(find.text('GRASS'), findsOneWidget);
    expect(find.text('POISON'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
