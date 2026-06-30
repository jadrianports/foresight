// Proportional parity guard (AC#4 / NFR8): both themes are built from the same
// token tables, so this only needs to confirm the wiring — chrome differs where
// DESIGN says it differs, tier fills are shared, the type map is complete, and
// both ThemeData register the extension at the correct brightness. The heavy
// test target is the engine (Epic 2), not the theme.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:foresight/theme/cartridge_colors.dart';
import 'package:foresight/theme/cartridge_theme.dart';
import 'package:foresight/theme/type_colors.dart';

void main() {
  setUpAll(() {
    // buildLightTheme/buildDarkTheme construct TextStyles via google_fonts,
    // which reads the bundled font assets — that needs an initialized binding
    // even outside testWidgets. And never reach the network (AD-1).
    TestWidgetsFlutterBinding.ensureInitialized();
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('CartridgeColors light/dark', () {
    test('chrome differs between light and dark where DESIGN says it does', () {
      const light = CartridgeColors.light;
      const dark = CartridgeColors.dark;
      expect(light.paper, isNot(dark.paper));
      expect(light.surface, isNot(dark.surface));
      expect(light.ink, isNot(dark.ink));
      expect(light.inkMuted, isNot(dark.inkMuted));
      expect(light.hairline, isNot(dark.hairline));
      expect(light.shadow, isNot(dark.shadow));
      expect(light.primaryRed, isNot(dark.primaryRed));
      // The brand primaries + placeholder fills also brighten in dark — assert
      // them too, so a copy-paste that collapsed one across themes can't pass.
      expect(light.primaryBlue, isNot(dark.primaryBlue));
      expect(light.primaryYellow, isNot(dark.primaryYellow));
      expect(light.placeholder1, isNot(dark.placeholder1));
      expect(light.placeholder2, isNot(dark.placeholder2));
    });

    test('tier fills are identical in light and dark', () {
      const light = CartridgeColors.light;
      const dark = CartridgeColors.dark;
      expect(light.tierSafe, dark.tierSafe);
      expect(light.tierGood, dark.tierGood);
      expect(light.tierEven, dark.tierEven);
      expect(light.tierRisky, dark.tierRisky);
      expect(light.tierRiskyAccent, dark.tierRiskyAccent);
    });

    test('tierRiskyText DIFFERS by theme — it is text-on-surface, not a fill', () {
      // The one tier token that must brighten in dark: #C2410C as text is fine
      // on the white light surface but 3.0:1 on the dark surface, so dark uses a
      // brightened orange. Lock the divergence so it can't be "unified" back.
      expect(CartridgeColors.light.tierRiskyText,
          isNot(CartridgeColors.dark.tierRiskyText));
    });
  });

  test('type-color map has exactly the 18 canonical lowercase slugs', () {
    expect(kTypeColors, hasLength(18));
    expect(
      kTypeColors.keys.toSet(),
      <String>{
        'normal', 'fire', 'water', 'electric', 'grass', 'ice', 'fighting',
        'poison', 'ground', 'flying', 'psychic', 'bug', 'rock', 'ghost',
        'dragon', 'dark', 'steel', 'fairy',
      },
    );
  });

  group('ThemeData pair', () {
    test('brightness is correct and each registers the extension', () {
      final light = buildLightTheme();
      final dark = buildDarkTheme();

      expect(light.brightness, Brightness.light);
      expect(dark.brightness, Brightness.dark);

      final lightExt = light.extension<CartridgeColors>();
      final darkExt = dark.extension<CartridgeColors>();
      expect(lightExt, isNotNull);
      expect(darkExt, isNotNull);
      // The registered extension carries the brightness-correct chrome.
      expect(lightExt!.paper, CartridgeColors.light.paper);
      expect(darkExt!.paper, CartridgeColors.dark.paper);
    });

    test('scaffold background is the theme paper', () {
      expect(buildLightTheme().scaffoldBackgroundColor, CartridgeColors.light.paper);
      expect(buildDarkTheme().scaffoldBackgroundColor, CartridgeColors.dark.paper);
    });
  });
}
