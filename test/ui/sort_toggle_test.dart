// Widget test for SortToggle (Story 3.6). Effort matched to risk: the load-
// bearing bits are the two VERBATIM labels rendering and the onChanged callback
// firing with the tapped mode. We do NOT pixel-assert the ink/paper invert
// (project-context "don't over-test boring UI") — one light structural check
// that the active mode drives the label color is enough.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:foresight/engine/ranking.dart';
import 'package:foresight/theme/cartridge_colors.dart';
import 'package:foresight/theme/cartridge_theme.dart';
import 'package:foresight/ui/widgets/sort_toggle.dart';

Widget _host(Widget child) => MaterialApp(
      theme: buildLightTheme(),
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('renders both verbatim labels (AC#7/#10b)', (tester) async {
    await tester.pumpWidget(_host(
      SortToggle(mode: SortMode.safestFirst, onChanged: (_) {}),
    ));
    await tester.pump();

    expect(find.text('SAFEST FIRST'), findsOneWidget);
    expect(find.text('HARDEST HITTING'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping the inactive segment fires onChanged with the other mode '
      '(AC#10b)', (tester) async {
    SortMode? captured;
    await tester.pumpWidget(_host(
      SortToggle(
        mode: SortMode.safestFirst,
        onChanged: (m) => captured = m,
      ),
    ));
    await tester.pump();

    await tester.tap(find.text('HARDEST HITTING'));
    expect(captured, SortMode.hardestHitting);
  });

  testWidgets('the active mode drives the label invert (active=paper, '
      'inactive=inkMuted)', (tester) async {
    await tester.pumpWidget(_host(
      SortToggle(mode: SortMode.hardestHitting, onChanged: (_) {}),
    ));
    await tester.pump();

    final colors =
        Theme.of(tester.element(find.byType(SortToggle))).extension<CartridgeColors>()!;
    final active = tester.widget<Text>(find.text('HARDEST HITTING'));
    final inactive = tester.widget<Text>(find.text('SAFEST FIRST'));
    expect(active.style!.color, colors.paper);
    expect(inactive.style!.color, colors.inkMuted);
  });
}
