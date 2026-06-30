import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app.dart';
import 'data/foresight_database.dart';

Future<void> main() async {
  // Needed before touching the asset bundle / plugins ahead of runApp.
  WidgetsFlutterBinding.ensureInitialized();

  // AD-1: zero runtime network. Fonts are bundled as assets (see pubspec `assets:`),
  // so google_fonts must never reach for HTTP. Disabling fetching makes any unbundled
  // glyph lookup fail loudly in dev instead of silently hitting the network in prod.
  GoogleFonts.config.allowRuntimeFetching = false;

  // AD-3/AD-7: copy-on-first-launch + version reconcile + hash assert, ONCE before the first
  // frame. The native splash covers this one-time open — no spinner/FutureBuilder (NFR2).
  // A DataContractViolation here PROPAGATES and fails the launch loudly; we never swallow it,
  // because the worst failure for a correctness tool is silently-wrong advice.
  final db = await openForesightDatabase();
  final counts = await smokeCounts(db);

  runApp(ForesightApp(counts: counts));
}
