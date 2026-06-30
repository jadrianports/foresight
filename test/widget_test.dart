// Scaffold smoke test (Story 1.1): the placeholder app builds and renders the
// bundled-font wordmark + subline. Real tests arrive with the engine (Epic 2).

import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:foresight/app.dart';

void main() {
  testWidgets('Foresight scaffold renders wordmark and subline', (tester) async {
    // Mirror main(): never reach for the network during tests (AD-1).
    GoogleFonts.config.allowRuntimeFetching = false;

    await tester.pumpWidget(const ForesightApp());

    expect(find.text('FORESIGHT'), findsOneWidget);
    expect(find.textContaining('fonts bundled'), findsOneWidget);
  });
}
