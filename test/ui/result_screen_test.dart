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
import 'package:foresight/recents_controller.dart';
import 'package:foresight/settings_controller.dart';
import 'package:foresight/theme/cartridge_theme.dart';
import 'package:foresight/ui/result_screen.dart';
import 'package:foresight/ui/widgets/honest_banner.dart';
import 'package:foresight/ui/widgets/sort_toggle.dart';
import 'package:foresight/ui/widgets/tier_result_row.dart';
import 'package:foresight/ui/widgets/top_pick_halo.dart';
import 'package:foresight/ui/widgets/type_chip.dart';

import '../recents_test_support.dart';
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

/// Story 3.7: ResultScreen records to the root RecentsController on mount, so
/// every host now supplies one too (AC#11f harness break). A fresh empty
/// controller per test; the record-on-mount test observes it directly.
late RecentsController _recents;

/// Provider ancestors + themed MaterialApp host for a directly-pumped
/// ResultScreen — both the SettingsController (sort, watched) and the
/// RecentsController (recents, read on mount) resolve above MaterialApp.
///
/// Story 3.8 HARNESS GATE (AC#10g): the host injects `disableAnimations: true` by
/// default, so the #1-SAFE `TopPickHalo` pulse NEVER runs and the existing
/// `pumpAndSettle` tests (Rock/Dark leads with Fighting = SAFE #1) still settle.
/// The one pulse test passes `allowMotion: true` and drives frames with
/// `tester.pump(Duration)` — never `pumpAndSettle` (a repeating controller never
/// quiesces). [textScaler] lets the AC#10f no-clip test pump at 2× OS scale.
Widget _host(
  Widget child,
  SettingsController settings, {
  bool allowMotion = false,
  TextScaler? textScaler,
}) =>
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsController>.value(value: settings),
        ChangeNotifierProvider<RecentsController>.value(value: _recents),
      ],
      child: MaterialApp(
        theme: buildLightTheme(),
        darkTheme: buildDarkTheme(),
        home: child,
        builder: (context, home) {
          var data =
              MediaQuery.of(context).copyWith(disableAnimations: !allowMotion);
          if (textScaler != null) data = data.copyWith(textScaler: textScaler);
          return MediaQuery(data: data, child: home!);
        },
      ),
    );

void main() {
  setUpAll(() {
    // Mirror main(): never reach for the network during tests (AD-1).
    GoogleFonts.config.allowRuntimeFetching = false;
    initRecentsFfi();
  });

  setUp(() async {
    _recents = await buildTestRecents();
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

  testWidgets(
      'AC#8/#11e: records the opponent exactly ONCE per mount — a sort toggle '
      'does NOT record again', (tester) async {
    // recordView is the only thing that notifies RecentsController, so a listener
    // count IS the recordView count.
    var records = 0;
    _recents.addListener(() => records++);

    await tester.pumpWidget(_host(
      ResultScreen(opponent: buildRockDarkOpponent(), chart: buildResultChart()),
      await _controller(),
    ));
    await tester.pumpAndSettle();

    // The post-frame callback fired once → exactly one record.
    expect(records, 1);
    expect(_recents.recents.map((i) => i.name), ['Tyranitar']);

    // Flip the sort — ResultScreen rebuilds (context.watch) but initState does
    // NOT re-run, so no second record (the AC#8 subtle bug).
    await tester.tap(find.text('HARDEST HITTING'));
    await tester.pumpAndSettle();

    expect(records, 1, reason: 'a toggle rebuild must not re-record');
    expect(find.byType(ResultScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // ----- Story 3.8: top-pick treatment, motion gate, semantics, targets, scale -----

  testWidgets(
      'AC#1/#10a: a SAFE lead gets exactly one #1 marker + TopPickHalo on the '
      'top row', (tester) async {
    await tester.pumpWidget(_host(
      ResultScreen(opponent: buildRockDarkOpponent(), chart: buildResultChart()),
      await _controller(),
    ));
    await tester.pumpAndSettle(); // gated (disableAnimations:true) → settles.

    // Exactly one #1 marker, wrapped in exactly one TopPickHalo, and it sits on
    // the SAFE lead row — above RISKY (rank owns the order).
    expect(find.text('#1'), findsOneWidget);
    expect(find.byType(TopPickHalo), findsOneWidget);
    final markerY = tester.getTopLeft(find.text('#1')).dy;
    final safeY = tester.getTopLeft(find.text('SAFE')).dy;
    final riskyY = tester.getTopLeft(find.text('RISKY')).dy;
    expect((markerY - safeY).abs(), lessThan(40),
        reason: 'the #1 marker rides the SAFE row');
    expect(markerY, lessThan(riskyY));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'AC#1/#10a: an all-fragile result (no SAFE lead) gets NO #1 marker and NO '
      'TopPickHalo', (tester) async {
    await tester.pumpWidget(_host(
      ResultScreen(
          opponent: buildAllFragileOpponent(), chart: buildAllFragileChart()),
      await _controller(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('#1'), findsNothing);
    expect(find.byType(TopPickHalo), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'AC#2/#3/#10b: the pulse runs ONLY when motion is allowed; the gated tree '
      'still shows the static cues', (tester) async {
    final settings = await _controller();

    // Motion ON: the halo exists and the tree does NOT settle (a repeating pulse
    // never quiesces) — drive bounded frames, assert no throw. NEVER pumpAndSettle.
    await tester.pumpWidget(_host(
      ResultScreen(opponent: buildRockDarkOpponent(), chart: buildResultChart()),
      settings,
      allowMotion: true,
    ));
    await tester.pump(); // first frame + schedule the record-on-mount callback
    await tester.pump(const Duration(milliseconds: 700)); // advance the pulse
    expect(find.byType(TopPickHalo), findsOneWidget);
    expect(find.text('#1'), findsOneWidget); // static cue present regardless
    expect(tester.takeException(), isNull);

    // Now GATE the SAME tree (disableAnimations flips true): TopPickHalo's
    // didChangeDependencies stops the repeating ticker, so the tree settles — and
    // pumpAndSettle also flushes the record-on-mount DB timer. State is preserved
    // (same widget types/positions), so initState does NOT re-run (no re-record).
    // The static cues remain: the top pick still reads via wider bar + #1 + rank.
    await tester.pumpWidget(_host(
      ResultScreen(opponent: buildRockDarkOpponent(), chart: buildResultChart()),
      settings,
    ));
    await tester.pumpAndSettle();
    expect(find.byType(TopPickHalo), findsOneWidget);
    expect(find.text('#1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'AC#4/#10c: each row exposes ONE merged label; the top pick prefixes '
      '"Top pick."; the section header is a header', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(
      ResultScreen(opponent: buildRockDarkOpponent(), chart: buildResultChart()),
      await _controller(),
    ));
    await tester.pumpAndSettle();

    // The composed row announcement (RegExp = contains, so the "Top pick. "
    // prefix on the SAFE lead doesn't break the match).
    expect(
      find.bySemanticsLabel(
          RegExp('Fighting, 4 times, SAFE, resists both its STABs')),
      findsOneWidget,
    );
    // The GOOD row composes type + multiplier + word + reused subline.
    expect(
      find.bySemanticsLabel(
          RegExp('Fairy, 2 times, GOOD, resists its Dark, neutral to Rock')),
      findsOneWidget,
    );
    // The #1 SAFE row's label is prefixed "Top pick." — exactly one such row.
    expect(find.bySemanticsLabel(RegExp(r'^Top pick\. ')), findsOneWidget);

    // The section header carries the header flag.
    expect(
      tester.getSemantics(find.text('USE THESE TYPES')),
      isSemantics(isHeader: true),
    );

    handle.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets('AC#5b/#10d: the active sort segment announces button + selected',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(
      ResultScreen(opponent: buildRockDarkOpponent(), chart: buildResultChart()),
      await _controller(), // default safestFirst → SAFEST FIRST is active
    ));
    await tester.pumpAndSettle();

    expect(
      tester.getSemantics(find.text('SAFEST FIRST')),
      isSemantics(isButton: true, isSelected: true),
    );
    expect(
      tester.getSemantics(find.text('HARDEST HITTING')),
      isSemantics(isButton: true, isSelected: false),
    );

    handle.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets('AC#6/#10e: each sort-toggle segment stands ≥ 48dp tall',
      (tester) async {
    await tester.pumpWidget(_host(
      ResultScreen(opponent: buildRockDarkOpponent(), chart: buildResultChart()),
      await _controller(),
    ));
    await tester.pumpAndSettle();

    for (final label in const ['SAFEST FIRST', 'HARDEST HITTING']) {
      final segHeight = tester
          .getSize(find
              .ancestor(
                  of: find.text(label), matching: find.byType(GestureDetector))
              .first)
          .height;
      expect(segHeight, greaterThanOrEqualTo(48.0), reason: '$label ≥ 48dp');
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('AC#7/#10f: Result survives 2× OS text scale with no overflow',
      (tester) async {
    await tester.pumpWidget(_host(
      ResultScreen(opponent: buildRockDarkOpponent(), chart: buildResultChart()),
      await _controller(),
      textScaler: const TextScaler.linear(2.0),
    ));
    await tester.pumpAndSettle();

    // No RenderFlex/paragraph overflow, and the key pixel strings still render.
    expect(tester.takeException(), isNull);
    expect(find.text('FIGHTING'), findsOneWidget);
    expect(find.text('4×'), findsOneWidget);
    expect(find.text('USE THESE TYPES'), findsOneWidget);
  });
}
