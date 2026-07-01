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
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:foresight/data/pokemon_queries.dart';
import 'package:foresight/engine/type_chart.dart';
import 'package:foresight/recents_controller.dart';
import 'package:foresight/settings_controller.dart';
import 'package:foresight/theme/cartridge_theme.dart';
import 'package:foresight/ui/home_screen.dart';
import 'package:foresight/ui/result_screen.dart';
import 'package:foresight/ui/widgets/empty_recents.dart';
import 'package:foresight/ui/widgets/form_badge.dart';
import 'package:foresight/ui/widgets/recent_tile.dart';
import 'package:foresight/ui/widgets/sprite_tile.dart';
import 'package:foresight/ui/widgets/type_chip.dart';

import '../recents_test_support.dart';
import 'result_fixtures.dart';

/// Story 3.4 threads a required `chart` through HomeScreen. The pre-3.4 tests
/// never tap a tile, so the chart is unused there — any valid chart works; we
/// reuse the crafted Result chart for uniformity.
final TypeChart _chart = buildResultChart();

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

/// Story 3.3 badge fixture: a base form (`formLabel: null` → NO badge), an
/// `Alola` form, and — crucially — a `Hisui` form. Hisui is one of the two DB
/// labels the epic/DESIGN never name (only 5 of the 7 are listed); including it
/// locks AC#3 so a naive 5-label enum/whitelist would drop it and fail the
/// count/text assertions below. Bogus sprite paths hit the degrade path — fine.
final _badgeDex = <PokemonListItem>[
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
    id: 10229,
    name: 'Zoroark',
    formLabel: 'Hisui',
    spritePath: 'assets/sprites/__nope_10229__.png',
    types: ['normal', 'ghost'],
  ),
];

const _noResultsCopy = 'No Pokémon match that. Check the spelling?';

/// Wrap a widget in the Cartridge theme so the CartridgeColors extension resolves.
/// Story 3.6: the pushed ResultScreen reads the root SettingsController
/// (context.watch), so the host provides one ABOVE MaterialApp — its Navigator's
/// pushed routes resolve it. Seeded per-test in setUp over mocked prefs.
late SettingsController _settings;

/// Story 3.7: HomeScreen watches the root RecentsController, and its pushed
/// ResultScreen reads it on mount — so the host provides one above MaterialApp
/// (AC#11f harness break). Empty by default (→ the empty-recents state); the
/// strip tests reassign it before pumping.
late RecentsController _recents;

/// Story 3.8: tapping a tile pushes a ResultScreen whose #1 pick is SAFE
/// (Rock/Dark → Fighting), whose `TopPickHalo` pulse would block `pumpAndSettle`.
/// The host injects `disableAnimations: true` so those pushed routes settle.
/// [textScaler] lets the AC#10f no-clip test pump Home at 2× OS scale.
Widget _host(Widget child, {TextScaler? textScaler}) => MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsController>.value(value: _settings),
        ChangeNotifierProvider<RecentsController>.value(value: _recents),
      ],
      child: MaterialApp(
        theme: buildLightTheme(),
        darkTheme: buildDarkTheme(),
        home: child,
        builder: (context, home) {
          var data = MediaQuery.of(context).copyWith(disableAnimations: true);
          if (textScaler != null) data = data.copyWith(textScaler: textScaler);
          return MediaQuery(data: data, child: home!);
        },
      ),
    );

void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    _settings = SettingsController(await SharedPreferences.getInstance());
    _recents = await buildTestRecents();
  });

  setUpAll(() {
    // Mirror main(): never reach for the network during tests (AD-1).
    GoogleFonts.config.allowRuntimeFetching = false;
    initRecentsFfi();
  });

  testWidgets('renders the wordmark and one tile per injected item',
      (tester) async {
    await tester.pumpWidget(_host(HomeScreen(pokemon: _fakeDex, chart: _chart)));
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
    await tester.pumpWidget(_host(HomeScreen(pokemon: _searchDex, chart: _chart)));
    await tester.pump();

    // No query typed → the whole injected dex renders, no no-results line.
    expect(find.byType(SpriteTile), findsNWidgets(_searchDex.length));
    expect(find.text(_noResultsCopy), findsNothing);
  });

  testWidgets('AC#4/#10a: "nine" narrows to exactly the two Ninetales tiles',
      (tester) async {
    await tester.pumpWidget(_host(HomeScreen(pokemon: _searchDex, chart: _chart)));
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
    await tester.pumpWidget(_host(HomeScreen(pokemon: _searchDex, chart: _chart)));
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
    await tester.pumpWidget(_host(HomeScreen(pokemon: _searchDex, chart: _chart)));
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
    await tester.pumpWidget(_host(HomeScreen(pokemon: _foldDex, chart: _chart)));
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

  // ----- Story 3.3: alternate-form badged tiles -----

  testWidgets('AC#1/#2/#5: an alt form renders a FormBadge with up-cased text',
      (tester) async {
    await tester.pumpWidget(_host(HomeScreen(pokemon: _badgeDex, chart: _chart)));
    await tester.pump();

    // The Alolan Ninetales carries an ALOLA badge — up-cased for display, never a
    // composed "Alolan Ninetales" name (the name column stays 'Ninetales').
    expect(find.text('ALOLA'), findsOneWidget);
    expect(find.byType(FormBadge), findsNWidgets(2)); // Alola + Hisui
    expect(tester.takeException(), isNull);
  });

  testWidgets('AC#1: a base-only dex renders no FormBadge', (tester) async {
    await tester.pumpWidget(_host(HomeScreen(pokemon: _fakeDex, chart: _chart)));
    await tester.pump();

    // Every _fakeDex item is a base form (formLabel: null) → zero badges.
    expect(find.byType(FormBadge), findsNothing);
  });

  testWidgets(
      'AC#3: badge count tracks the data, no whitelist — Hisui/Paldea render',
      (tester) async {
    await tester.pumpWidget(_host(HomeScreen(pokemon: _badgeDex, chart: _chart)));
    await tester.pump();

    // Badge count == number of non-null-formLabel items, and the un-named-by-the-
    // epic 'Hisui' label paints — a 5-label enum would drop it and fail here.
    final badged = _badgeDex.where((p) => p.formLabel != null).length;
    expect(find.byType(FormBadge), findsNWidgets(badged));
    expect(find.text('HISUI'), findsOneWidget);
  });

  testWidgets('AC#8/#10d: the badge overlay never skews SpriteTile counts',
      (tester) async {
    await tester.pumpWidget(_host(HomeScreen(pokemon: _badgeDex, chart: _chart)));
    await tester.pump();

    // One SpriteTile per item (base + 2 badged) — the Stack wraps, not adds, a
    // tile. Filtering by the shared name still keeps both Ninetales, one badged.
    expect(find.byType(SpriteTile), findsNWidgets(_badgeDex.length));

    await tester.enterText(find.byType(TextField), 'nine');
    await tester.pump();
    expect(find.byType(SpriteTile), findsNWidgets(2));
    expect(find.byType(FormBadge), findsOneWidget); // only the Alolan one
    expect(find.text('ALOLA'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('FormBadge in isolation up-cases a multi-word label, no throw',
      (tester) async {
    await tester.pumpWidget(_host(
      const Scaffold(body: Center(child: FormBadge('Mega X'))),
    ));
    await tester.pump();

    expect(find.text('MEGA X'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // ----- Story 3.4: tap → Result navigation -----

  testWidgets('AC#1/#11b: tapping a tile pushes ResultScreen for that opponent',
      (tester) async {
    final opponent = buildRockDarkOpponent();
    await tester.pumpWidget(
      _host(HomeScreen(pokemon: [opponent], chart: buildResultChart())),
    );
    await tester.pump();

    // Home shows the tile, not yet a Result.
    expect(find.byType(ResultScreen), findsNothing);

    await tester.tap(find.byType(SpriteTile));
    await tester.pumpAndSettle();

    // A ResultScreen for the tapped opponent is now on the stack, leading with
    // its name and the "USE THESE TYPES" section.
    expect(find.byType(ResultScreen), findsOneWidget);
    expect(find.text('Tyranitar'), findsOneWidget);
    expect(find.text('USE THESE TYPES'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // ----- Story 3.7: recent strip + empty state -----

  testWidgets(
      'AC#5/#11d: the strip shows N recent tiles above the grid, newest-first, '
      'and a tap reopens Result', (tester) async {
    // A dex with the chart-covered rock/dark opponent plus a base form. Seed
    // recents [1, 248] with ascending timestamps → id 248 is newest.
    final dex = [
      buildRockDarkOpponent(), // id 248, rock/dark (buildResultChart covers it)
      PokemonListItem(
        id: 1,
        name: 'Bulbasaur',
        formLabel: null,
        spritePath: 'assets/sprites/__nope_1__.png',
        types: const ['grass', 'poison'],
      ),
    ];
    // Build the seeded controller in a REAL async zone — RecentsController.open
    // does sqflite_common_ffi I/O, and awaiting real isolate I/O inside the
    // testWidgets fake-async body would hang (as would `await` on it directly).
    final seeded = await tester.runAsync(
        () => buildTestRecents(dex: dex, seededIds: const [1, 248]));
    _recents = seeded!;

    await tester.pumpWidget(
        _host(HomeScreen(pokemon: dex, chart: buildResultChart())));
    await tester.pumpAndSettle();

    // Two recent tiles, newest (Tyranitar) first in the strip.
    expect(find.byType(RecentTile), findsNWidgets(2));
    expect(
      find.descendant(
          of: find.byType(RecentTile).first, matching: find.text('Tyranitar')),
      findsOneWidget,
      reason: 'newest recent (Tyranitar) is first in the strip',
    );

    // The strip sits ABOVE the grid, which is still fully populated.
    final stripY = tester.getTopLeft(find.byType(RecentTile).first).dy;
    final gridY = tester.getTopLeft(find.byType(SpriteTile).first).dy;
    expect(stripY, lessThan(gridY));
    expect(find.byType(SpriteTile), findsNWidgets(dex.length));

    // Tapping the newest recent tile reopens Result for that opponent.
    await tester.tap(find.byType(RecentTile).first);
    await tester.pumpAndSettle();
    expect(find.byType(ResultScreen), findsOneWidget);
    expect(find.text('USE THESE TYPES'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'AC#6/#11d: no history → the verbatim empty line renders, grid still full',
      (tester) async {
    // _recents is empty (setUp default) → the empty-recents state.
    await tester.pumpWidget(_host(HomeScreen(pokemon: _fakeDex, chart: _chart)));
    await tester.pump();

    expect(find.byType(EmptyRecents), findsOneWidget);
    expect(
      find.text('No recent matchups yet — tap a Pokémon to start.'),
      findsOneWidget,
    );
    expect(find.byType(RecentTile), findsNothing);
    // The grid below is still fully populated and usable.
    expect(find.byType(SpriteTile), findsNWidgets(_fakeDex.length));
    expect(tester.takeException(), isNull);
  });

  // ----- Story 3.8: tile/badge semantics + dynamic-type no-clip -----

  testWidgets('AC#5a/#10d: a grid tile exposes a button role + the mon name',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(HomeScreen(pokemon: _fakeDex, chart: _chart)));
    await tester.pump();

    // The tap wrapper merges the tile into ONE button node labelled by the name
    // (the inner sprite image label is suppressed — announced once).
    expect(
      tester.getSemantics(find.text('Bulbasaur')),
      isSemantics(isButton: true, label: 'Bulbasaur'),
    );

    handle.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets('AC#5c/#10d: a FormBadge announces "<label> form"', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(
      const Scaffold(body: Center(child: FormBadge('Alola'))),
    ));
    await tester.pump();

    expect(find.bySemanticsLabel(RegExp('Alola form')), findsOneWidget);

    handle.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets('AC#7/#10f: Home survives 2× OS text scale with no overflow',
      (tester) async {
    await tester.pumpWidget(_host(
      HomeScreen(pokemon: _fakeDex, chart: _chart),
      textScaler: const TextScaler.linear(2.0),
    ));
    await tester.pump();

    // No RenderFlex/paragraph overflow at max scale; wordmark + a tile name still
    // render (pixel strings clamp-scale; body scales freely).
    expect(tester.takeException(), isNull);
    expect(find.textContaining('FORESIGHT'), findsOneWidget);
    expect(find.text('Bulbasaur'), findsOneWidget);
  });
}
