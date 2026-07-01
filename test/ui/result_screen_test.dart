// Widget tests for the Result screen (Story 3.4 + 3.5 + 3.6). Effort matched to
// risk (project-context #Testing-Rules): assert the answer renders — tier WORDS,
// multipliers, order, one row per survivor, the RISKY row, the empty-survivors
// no-crash path — and the Story 3.6 RE-SORT-IN-PLACE behavior. We do NOT pixel-
// assert row chrome / hatch / the toggle invert.
//
// Fixtures are hand-built (crafted chart + fake opponent), never the real DB.
// Prefs are mocked (SharedPreferences.setMockInitialValues) — never a device
// store. ResultScreen now reads the root SettingsController (context.watch), so
// every host wraps it in a ChangeNotifierProvider ancestor (AC#10f harness break,
// mirroring Story 3.4's chart threading).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:foresight/engine/ranking.dart';
import 'package:foresight/settings_controller.dart';
import 'package:foresight/theme/cartridge_theme.dart';
import 'package:foresight/ui/result_screen.dart';
import 'package:foresight/ui/widgets/honest_banner.dart';
import 'package:foresight/ui/widgets/sort_toggle.dart';
import 'package:foresight/ui/widgets/tier_result_row.dart';
import 'package:foresight/ui/widgets/type_chip.dart';

import 'result_fixtures.dart';

/// Builds a fresh SettingsController over mocked prefs seeded to [start]. A test
/// that needs to begin in a chosen mode passes it; the default is the app default
/// (safestFirst).
Future<SettingsController> _controller(
    {SortMode start = SortMode.safestFirst}) async {
  SharedPreferences.setMockInitialValues(
    start == SortMode.hardestHitting ? {'sortMode': 'hardestHitting'} : {},
  );
  return SettingsController(await SharedPreferences.getInstance());
}

/// Provider ancestor + themed MaterialApp host for a directly-pumped ResultScreen.
Widget _host(Widget child, SettingsController settings) =>
    ChangeNotifierProvider<SettingsController>.value(
      value: settings,
      child: MaterialApp(
        theme: buildLightTheme(),
        darkTheme: buildDarkTheme(),
        home: child,
      ),
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
      await _controller(),
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
      await _controller(),
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

    // Story 3.5 AC#3: a mixed (not all-RISKY) result shows NO honest banner, the
    // EVEN row reads the calm "Even trade", and "trading blows" never leaks in.
    expect(find.byType(HonestBanner), findsNothing);
    expect(find.text('Even trade'), findsOneWidget);
    expect(find.textContaining('trading blows'), findsNothing);

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'AC#1/#3/#10c: the toggle re-sorts the SAME rows in place — no new route, '
      'tiers still shown', (tester) async {
    // Start in the default safest-first order.
    await tester.pumpWidget(_host(
      ResultScreen(opponent: buildRockDarkOpponent(), chart: buildResultChart()),
      await _controller(),
    ));
    await tester.pumpAndSettle();

    // Safest-first: SAFE above RISKY, and the toggle is present (rows exist).
    expect(find.byType(SortToggle), findsOneWidget);
    expect(tester.getTopLeft(find.text('SAFE')).dy,
        lessThan(tester.getTopLeft(find.text('RISKY')).dy));
    expect(find.byType(HonestBanner), findsNothing);

    // Flip to hardest-hitting IN PLACE.
    await tester.tap(find.text('HARDEST HITTING'));
    await tester.pumpAndSettle();

    // Same screen — no navigation happened.
    expect(find.byType(ResultScreen), findsOneWidget);
    expect(find.byType(TierResultRow), findsNWidgets(4));

    // Hardest-hitting order: the 4× (FIGHTING) row stays on top; the three 2×
    // rows reorder to slug-asc (BUG < FAIRY < GROUND). Tier is IGNORED for order.
    final fightingY = tester.getTopLeft(find.text('FIGHTING')).dy;
    final bugY = tester.getTopLeft(find.text('BUG')).dy;
    final fairyY = tester.getTopLeft(find.text('FAIRY')).dy;
    final groundY = tester.getTopLeft(find.text('GROUND')).dy;
    expect(fightingY, lessThan(bugY));
    expect(bugY, lessThan(fairyY));
    expect(fairyY, lessThan(groundY));

    // AC#3: every tier badge/word is STILL present (risk shown, not used to sort).
    expect(find.text('SAFE'), findsOneWidget);
    expect(find.text('GOOD'), findsOneWidget);
    expect(find.text('EVEN'), findsOneWidget);
    expect(find.text('RISKY'), findsOneWidget);

    // No banner appears/disappears from toggling a mixed result.
    expect(find.byType(HonestBanner), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'AC#1/#2/#5/#10d: all-fragile → banner leads + both RISKY rows, coexists '
      'with the toggle under either position', (tester) async {
    await tester.pumpWidget(_host(
      ResultScreen(
          opponent: buildAllFragileOpponent(), chart: buildAllFragileChart()),
      await _controller(),
    ));
    await tester.pumpAndSettle();

    // The banner leads with its heading + the exact honest line (verbatim copy).
    expect(find.byType(HonestBanner), findsOneWidget);
    expect(find.text('NO CLEAN ANSWER'), findsOneWidget);
    expect(
      find.text(
          "No clean answer — you're trading blows. Lead with the hardest hit."),
      findsOneWidget,
    );

    // The toggle shows (there ARE rows) and both RISKY rows follow beneath it.
    expect(find.byType(SortToggle), findsOneWidget);
    expect(find.byType(TierResultRow), findsNWidgets(2));
    expect(find.text('RISKY'), findsNWidgets(2));
    expect(find.text('WATER'), findsOneWidget);
    expect(find.text('ELECTRIC'), findsOneWidget);

    // One tier → safestFirst ≡ hardestHitting: WATER (4×) sits above ELECTRIC
    // (2×) and the banner leads — under EITHER toggle position, no throw (AC#5).
    for (final label in const ['SAFEST FIRST', 'HARDEST HITTING']) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(find.byType(HonestBanner), findsOneWidget);
      final bannerY = tester.getTopLeft(find.text('NO CLEAN ANSWER')).dy;
      final waterY = tester.getTopLeft(find.text('WATER')).dy;
      final electricY = tester.getTopLeft(find.text('ELECTRIC')).dy;
      expect(bannerY, lessThan(waterY));
      expect(waterY, lessThan(electricY));
    }

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'AC#6/#10e: no super-effective survivor → header + zero rows + NO toggle, '
      'no throw', (tester) async {
    await tester.pumpWidget(_host(
      ResultScreen(
          opponent: buildNoAnswerOpponent(), chart: buildNoAnswerChart()),
      await _controller(),
    ));
    await tester.pumpAndSettle();

    // The header + section still render; there are simply no tier rows, no
    // banner, and — nothing to re-sort — NO toggle. Nothing crashes.
    expect(find.text('Blankmon'), findsOneWidget);
    expect(find.text('USE THESE TYPES'), findsOneWidget);
    expect(find.byType(TierResultRow), findsNothing);
    expect(find.byType(HonestBanner), findsNothing);
    expect(find.byType(SortToggle), findsNothing); // AC#6
    expect(tester.takeException(), isNull);
  });
}
