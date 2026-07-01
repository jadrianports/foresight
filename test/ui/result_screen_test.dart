// Widget tests for the Story 3.4 Result screen. Effort matched to risk
// (project-context #Testing-Rules): assert the answer renders — tier WORDS,
// multipliers, safest-first order, one row per survivor, the RISKY row, and the
// empty-survivors no-crash path — NOT the row chrome / hatch pixels.
//
// Fixtures are hand-built (crafted chart + fake opponent), never the real DB.
// Under `flutter test` every Image.asset fails; the OpponentCard errorBuilder
// degrades cleanly so the name + chips still assert.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:foresight/theme/cartridge_theme.dart';
import 'package:foresight/ui/result_screen.dart';
import 'package:foresight/ui/widgets/tier_result_row.dart';
import 'package:foresight/ui/widgets/type_chip.dart';

import 'result_fixtures.dart';

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

  testWidgets('AC#2/#7/#11c: leads with the opponent header + USE THESE TYPES',
      (tester) async {
    await tester.pumpWidget(_host(
      ResultScreen(opponent: buildRockDarkOpponent(), chart: buildResultChart()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Tyranitar'), findsOneWidget);
    // A TypeChip per opponent type (rock/dark), using the canonical palette.
    expect(find.byType(TypeChip), findsNWidgets(2));
    expect(find.text('ROCK'), findsOneWidget);
    expect(find.text('DARK'), findsOneWidget);
    expect(find.text('USE THESE TYPES'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'AC#3/#4/#11d/e: ranked rows render — tier words, multipliers, order, '
      'RISKY present', (tester) async {
    await tester.pumpWidget(_host(
      ResultScreen(opponent: buildRockDarkOpponent(), chart: buildResultChart()),
    ));
    await tester.pumpAndSettle();

    // Four survivors → four rows, one per tier.
    expect(find.byType(TierResultRow), findsNWidgets(4));
    expect(find.text('SAFE'), findsOneWidget);
    expect(find.text('GOOD'), findsOneWidget);
    expect(find.text('EVEN'), findsOneWidget);
    expect(find.text('RISKY'), findsOneWidget); // AC#11e

    // Attacking TYPES, up-cased (never Pokémon names).
    expect(find.text('FIGHTING'), findsOneWidget);
    expect(find.text('FAIRY'), findsOneWidget);
    expect(find.text('GROUND'), findsOneWidget);

    // Multipliers: Fighting is 4× (dual 2×·2×); the rest are 2×.
    expect(find.text('4×'), findsOneWidget);
    expect(find.textContaining('2×'), findsWidgets);

    // Safest-first order: SAFE renders above RISKY (rank owns the order; the UI
    // renders it top-to-bottom, so #1 is the top row).
    final safeY = tester.getTopLeft(find.text('SAFE')).dy;
    final riskyY = tester.getTopLeft(find.text('RISKY')).dy;
    expect(safeY, lessThan(riskyY));

    // An honest subline is present (never "takes nothing back").
    expect(find.text('Resists both its STABs'), findsOneWidget);
    expect(find.textContaining('takes nothing'), findsNothing);

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AC#10/#11g: no super-effective survivor → header + zero rows, no throw',
      (tester) async {
    await tester.pumpWidget(_host(
      ResultScreen(
          opponent: buildNoAnswerOpponent(), chart: buildNoAnswerChart()),
    ));
    await tester.pumpAndSettle();

    // The header + section still render; there are simply no tier rows, and
    // nothing crashes (the rich all-fragile copy is Story 3.5, intentionally
    // absent here).
    expect(find.text('Blankmon'), findsOneWidget);
    expect(find.text('USE THESE TYPES'), findsOneWidget);
    expect(find.byType(TierResultRow), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
