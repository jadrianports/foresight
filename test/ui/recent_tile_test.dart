// Widget test for RecentTile (Story 3.7 Task 4). Matched to risk: the name
// renders, and the AD-7 soft-degrade path (a missing sprite → type chips, no
// throw) works — mirroring the SpriteTile degrade test. We don't pixel-assert the
// bare sprite+name chrome.
//
// Under `flutter test` the asset bundle has no sprites, so every Image.asset
// fails and the errorBuilder fires — exactly what exercises the degrade path.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:foresight/data/pokemon_queries.dart';
import 'package:foresight/theme/cartridge_theme.dart';
import 'package:foresight/ui/widgets/recent_tile.dart';
import 'package:foresight/ui/widgets/type_chip.dart';

Widget _host(Widget child) => MaterialApp(
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      home: Scaffold(body: Center(child: SizedBox(width: 76, child: child))),
    );

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('renders the name and degrades a missing sprite to type chips',
      (tester) async {
    final item = PokemonListItem(
      id: 3,
      name: 'Venusaur',
      formLabel: null,
      spritePath: 'assets/sprites/__does_not_exist__.png',
      types: const ['grass', 'poison'],
    );

    await tester.pumpWidget(_host(RecentTile(item)));
    // Let the asset resolution fail so the errorBuilder swaps in the fallback.
    await tester.pumpAndSettle();

    expect(find.text('Venusaur'), findsOneWidget);
    expect(find.byType(TypeChip), findsNWidgets(2));
    expect(find.text('GRASS'), findsOneWidget);
    expect(find.text('POISON'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
