// Unit tests for SettingsController (Story 3.6). The load-bearing behaviors are
// PERSISTENCE (sticky across launches) and the default/read/degrade rules —
// locked here with mocked prefs, never a real device store (project-context
// #Testing-Rules). No widget pump needed: the controller is flutter-free logic
// over a SharedPreferences instance.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:foresight/engine/ranking.dart';
import 'package:foresight/settings_controller.dart';

Future<SettingsController> controllerFrom(Map<String, Object> initial) async {
  SharedPreferences.setMockInitialValues(initial);
  final prefs = await SharedPreferences.getInstance();
  return SettingsController(prefs);
}

void main() {
  // shared_preferences' mock channel needs the binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('read on construction (AC#8)', () {
    test('empty prefs → default safestFirst', () async {
      final c = await controllerFrom({});
      expect(c.sortMode, SortMode.safestFirst);
    });

    test('stored hardestHitting is read back', () async {
      final c = await controllerFrom({'sortMode': 'hardestHitting'});
      expect(c.sortMode, SortMode.hardestHitting);
    });

    test('a garbage/corrupt value degrades to safestFirst (soft-default, no throw)',
        () async {
      final c = await controllerFrom({'sortMode': 'garbage'});
      expect(c.sortMode, SortMode.safestFirst);
    });
  });

  group('setSortMode persist + notify (AC#2/#8/#10a)', () {
    test('persists to shared_preferences AND notifies exactly once', () async {
      final c = await controllerFrom({});
      var notifications = 0;
      c.addListener(() => notifications++);

      c.setSortMode(SortMode.hardestHitting);

      expect(c.sortMode, SortMode.hardestHitting);
      expect(notifications, 1);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('sortMode'), 'hardestHitting');
    });

    test('setting the SAME value is a no-op — no extra notify', () async {
      final c = await controllerFrom({'sortMode': 'hardestHitting'});
      var notifications = 0;
      c.addListener(() => notifications++);

      c.setSortMode(SortMode.hardestHitting); // already active

      expect(notifications, 0);
    });

    test('cross-launch "sticky" proof: a fresh controller over the written prefs '
        'restores the choice', () async {
      final c = await controllerFrom({});
      c.setSortMode(SortMode.hardestHitting);

      // Simulate a cold launch: build a NEW controller over the same store.
      final prefs = await SharedPreferences.getInstance();
      final relaunched = SettingsController(prefs);
      expect(relaunched.sortMode, SortMode.hardestHitting);
    });
  });
}
