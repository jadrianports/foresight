import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Dart mirror of `prebake/schema_version.py` — the AD-3 schema-version routine.
///
/// `prebake/schema.sql` is the single source of truth for DB shape. `PRAGMA user_version`
/// is DERIVED from a hash of its *normalized* text: the prebake stamps it into the bundled
/// DB (Story 1.3) and the app re-computes the same value here and asserts equality on open
/// (Story 1.4). So a shape change with a forgotten prebake re-run fails LOUD instead of
/// silently serving a stale DB.
///
/// This MUST stay byte-for-byte identical to the Python routine. The unit test locks it to
/// the current canonical value (1555704544); the Python module is the authoritative spec.

/// Strip comments, collapse whitespace, trim. Mirrors `schema_version.py::normalize`.
///
/// We deliberately do NOT lowercase — SQL identifiers and values are case-significant.
/// Each comment is replaced with a single space (NOT ''), exactly as Python does, so the
/// normalized text is byte-identical across the two languages.
String normalize(String schemaText) {
  return schemaText
      .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), ' ') // block comments
      .replaceAll(RegExp(r'--[^\n]*'), ' ') // line comments (to EOL)
      .replaceAll(RegExp(r'\s+'), ' ') // collapse all whitespace runs
      .trim();
}

/// Map normalized schema text -> the signed-32-bit-safe `PRAGMA user_version`.
///
/// SHA-256 of the normalized UTF-8 text; first 4 bytes big-endian, masked to 31 bits so it
/// fits SQLite's signed-32-bit `user_version` and stays positive. Mirrors
/// `schema_version.py::compute_user_version`.
int computeUserVersion(String schemaText) {
  final digest = sha256.convert(utf8.encode(normalize(schemaText))).bytes;
  return ((digest[0] << 24) |
          (digest[1] << 16) |
          (digest[2] << 8) |
          digest[3]) &
      0x7FFFFFFF;
}

/// The expected `user_version` for the bundled schema, computed at runtime from the schema
/// text the app was built against (AD-3 — never a hard-coded constant). CRLF vs LF is
/// irrelevant: the whitespace collapse in [normalize] erases line-ending differences.
Future<int> userVersionForBundledSchema() async {
  return computeUserVersion(await rootBundle.loadString('prebake/schema.sql'));
}
