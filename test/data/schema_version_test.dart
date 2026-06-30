// AD-3 correctness core: the Dart hash routine MUST agree with prebake/schema_version.py
// byte-for-byte. These tests re-assert the same three properties the Python self-check
// guarantees (deterministic value, whitespace/comment-insensitive, shape-sensitive) and
// lock the Dart mirror to the current canonical value. [Story 1.4 Task 8]

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:foresight/data/schema_version.dart';

void main() {
  // Pure-text tests: no Flutter binding, no ffi. We read prebake/schema.sql straight from
  // disk (the same file the prebake hashes) to prove the two routines compute the same int.
  final schema = File('prebake/schema.sql').readAsStringSync();

  // The current canonical value, stamped into the bundled DB by the prebake (Story 1.3).
  // If a future schema edit moves this, BOTH sides move together (AD-3 working) and this
  // constant is updated in the same change.
  const currentUserVersion = 1555704544;

  test('computeUserVersion matches the Python routine for the current schema', () {
    expect(computeUserVersion(schema), currentUserVersion);
  });

  test('is deterministic (computing twice yields the same value)', () {
    expect(computeUserVersion(schema), computeUserVersion(schema));
  });

  test('is whitespace- and comment-insensitive (cosmetic edits do not move it)', () {
    // Mirrors the Python self-check's cosmetic edit: a banner block comment, re-indented
    // lines, and a trailing line comment must normalize away.
    final cosmetic =
        '/* banner */\n\n${schema.replaceAll('\n', '\n   ')}\n-- trailing note\n';
    expect(computeUserVersion(cosmetic), currentUserVersion);
  });

  test('CRLF line endings normalize to the same value as LF', () {
    final crlf = schema.replaceAll('\n', '\r\n');
    expect(computeUserVersion(crlf), currentUserVersion);
  });

  test('a real shape change moves the value', () {
    // Same shape change the Python self-check uses: dropping a NOT NULL constraint.
    final shapeChange =
        schema.replaceAll('viewed_at  INTEGER NOT NULL', 'viewed_at INTEGER');
    expect(shapeChange == schema, isFalse, reason: 'fixture replacement must apply');
    expect(computeUserVersion(shapeChange), isNot(currentUserVersion));
  });

  test('normalize collapses whitespace and strips comments without lowercasing', () {
    expect(
      normalize('/* x */\nCREATE   TABLE  Foo;  -- note\n'),
      'CREATE TABLE Foo;',
    );
  });
}
