// App-shell build test (updated for Story 3.1): ForesightApp now requires the
// injected dex and shows the sprite grid (the temporary scaffold-check screen is
// gone). Pump a small fake list and assert the wordmark + an injected tile
// render. The degrade path and grid behavior have dedicated tests in test/ui/.

import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:foresight/app.dart';
import 'package:foresight/data/pokemon_queries.dart';
import 'package:foresight/engine/type_chart.dart';

void main() {
  testWidgets('ForesightApp builds Home with the wordmark and injected tiles',
      (tester) async {
    // Mirror main(): never reach for the network during tests (AD-1).
    GoogleFonts.config.allowRuntimeFetching = false;

    final fakeDex = <PokemonListItem>[
      PokemonListItem(
        id: 1,
        name: 'Bulbasaur',
        formLabel: null,
        spritePath: 'assets/sprites/__nope__.png',
        types: ['grass', 'poison'],
      ),
    ];

    // Story 3.4: ForesightApp now requires the injected type chart too. This test
    // never taps a tile, so an empty chart is sufficient (it is only consumed by
    // the pushed ResultScreen).
    final chart = TypeChart(<(String, String), double>{});

    await tester.pumpWidget(ForesightApp(pokemon: fakeDex, chart: chart));
    await tester.pump();

    // Wordmark is rich text ("FORESIGHT" + a red "." accent) — match by substring.
    expect(find.textContaining('FORESIGHT'), findsOneWidget);
    expect(find.text('Bulbasaur'), findsOneWidget);
  });
}
