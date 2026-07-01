// App-shell build test (updated for Story 3.1): ForesightApp now requires the
// injected dex and shows the sprite grid (the temporary scaffold-check screen is
// gone). Pump a small fake list and assert the wordmark + an injected tile
// render. The degrade path and grid behavior have dedicated tests in test/ui/.

import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:foresight/app.dart';
import 'package:foresight/data/pokemon_queries.dart';
import 'package:foresight/engine/type_chart.dart';
import 'package:foresight/recents_controller.dart';
import 'package:foresight/settings_controller.dart';

import 'recents_test_support.dart';

final _fakeDex = <PokemonListItem>[
  PokemonListItem(
    id: 1,
    name: 'Bulbasaur',
    formLabel: null,
    spritePath: 'assets/sprites/__nope__.png',
    types: const ['grass', 'poison'],
  ),
];

// Story 3.6 + 3.7: ForesightApp now requires both root controllers. They are
// built in setUp — a REAL async zone — because the RecentsController opens a
// sqflite_common_ffi DB, and awaiting that real isolate I/O inside a testWidgets
// (fake-async) body would hang.
late SettingsController _settings;
late RecentsController _recents;

void main() {
  setUpAll(() {
    // Mirror main(): never reach for the network during tests (AD-1).
    GoogleFonts.config.allowRuntimeFetching = false;
    initRecentsFfi();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    _settings = SettingsController(await SharedPreferences.getInstance());
    // Empty recents over the fake dex → the empty-recents state on Home.
    _recents = await buildTestRecents(dex: _fakeDex);
  });

  testWidgets('ForesightApp builds Home with the wordmark and injected tiles',
      (tester) async {
    // Story 3.4: ForesightApp requires the injected type chart too. This test
    // never taps a tile, so an empty chart is sufficient (it is only consumed by
    // the pushed ResultScreen).
    final chart = TypeChart(<(String, String), double>{});

    await tester.pumpWidget(ForesightApp(
        pokemon: _fakeDex, chart: chart, settings: _settings, recents: _recents));
    await tester.pump();

    // Wordmark is rich text ("FORESIGHT" + a red "." accent) — match by substring.
    expect(find.textContaining('FORESIGHT'), findsOneWidget);
    expect(find.text('Bulbasaur'), findsOneWidget);
  });
}
