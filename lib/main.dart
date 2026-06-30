import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app.dart';

void main() {
  // AD-1: zero runtime network. Fonts are bundled as assets (see pubspec `assets:`),
  // so google_fonts must never reach for HTTP. Disabling fetching makes any unbundled
  // glyph lookup fail loudly in dev instead of silently hitting the network in prod.
  GoogleFonts.config.allowRuntimeFetching = false;
  runApp(const ForesightApp());
}
