import 'package:flutter_test/flutter_test.dart';
import 'package:foresight/engine/typing.dart';

// Plain Dart tests via flutter_test — no binding, no sqflite: the engine is pure Dart
// (project-context #Testing-Rules). The 1.5 Flutter-binding workaround was only for
// google_fonts; nothing here needs it.
void main() {
  test('mono holds one slug; dual holds two in slot order', () {
    expect(Typing.mono('fire').types, ['fire']);
    expect(Typing.dual('rock', 'dark').types, ['rock', 'dark']);
  });

  test('equality is by ordered slugs (slot order is significant)', () {
    expect(Typing.dual('rock', 'dark'), Typing.dual('rock', 'dark'));
    expect(Typing.dual('rock', 'dark') == Typing.dual('dark', 'rock'), isFalse);
    expect(Typing.mono('fire') == Typing.dual('fire', 'flying'), isFalse);
  });

  test('types list is unmodifiable (value holder, not a mutable container)', () {
    expect(() => Typing.mono('fire').types.add('water'), throwsUnsupportedError);
  });

  test('does NOT lowercase-coerce — a wrong-case slug is preserved to fail loud later', () {
    // project-context: query/compare on lowercase slugs ONLY. Coercing here would mask a
    // caller's casing bug; instead the bad slug misses the chart and trips AD-7's throw.
    expect(Typing.mono('Fire').types, ['Fire']);
  });

  test('asserts the slug count is 1 or 2', () {
    expect(() => Typing(<String>[]), throwsA(isA<AssertionError>()));
    expect(() => Typing(['a', 'b', 'c']), throwsA(isA<AssertionError>()));
  });
}
