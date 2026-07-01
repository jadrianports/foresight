import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/pokemon_queries.dart';
import 'engine/type_chart.dart';
import 'recents_controller.dart';
import 'settings_controller.dart';
import 'theme/cartridge_theme.dart';
import 'ui/home_screen.dart';

/// The app root. Wires the Cartridge light/dark themes (Story 1.5, OS-follow at
/// full parity) and shows [HomeScreen] — the full-dex sprite grid (Story 3.1).
///
/// The dex and the type [chart] are both queried ONCE in the composition root
/// (`main()`) and injected here as plain value objects (AD-6: the UI never
/// touches sqflite/data — but a `TypeChart` is an immutable engine value object,
/// NOT a `Database` handle, so holding/passing it is fine).
///
/// [settings] and [recents] — the two root-provided `ChangeNotifier`s (AD-6),
/// created in `main()` and exposed via a `MultiProvider` of
/// `ChangeNotifierProvider.value`s ABOVE `MaterialApp` so BOTH `HomeScreen` (in
/// the tree) and the pushed `ResultScreen` (on the nav stack) can read them.
/// [settings] holds the sort preference (Story 3.6; its theme-override slice and
/// the manual System/Light/Dark switch arrive in Story 4.2, at which point
/// `themeMode` below stops being hard-wired). [recents] holds the newest-first
/// recents (Story 3.7) — Home watches it; Result records to it on mount.
class ForesightApp extends StatelessWidget {
  const ForesightApp({
    super.key,
    required this.pokemon,
    required this.chart,
    required this.settings,
    required this.recents,
  });

  /// The full bundled dex, resolved before `runApp` and handed to [HomeScreen].
  final List<PokemonListItem> pokemon;

  /// The in-memory type chart, injected down to the pushed `ResultScreen` so its
  /// `rank(...)` runs synchronously with no DB access (Story 3.4).
  final TypeChart chart;

  /// The root sort-preference controller, provided app-wide (Story 3.6).
  final SettingsController settings;

  /// The root recents controller, provided app-wide (Story 3.7).
  final RecentsController recents;

  @override
  Widget build(BuildContext context) {
    // Both `.value` because main() owns the controllers' lifetimes — these
    // app-lifetime singletons must NOT be disposed by the provider (the `create:`
    // form would). The MultiProvider sits ABOVE MaterialApp so both Home and the
    // Navigator's pushed routes (ResultScreen) can read them (AD-6 root-provided).
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsController>.value(value: settings),
        ChangeNotifierProvider<RecentsController>.value(value: recents),
      ],
      child: MaterialApp(
        title: 'Foresight',
        debugShowCheckedModeBanner: false,
        // OS-follow at full light/dark parity (Story 1.5 AC#4). The manual
        // override is Epic 4 (Story 4.2 adds SettingsController's theme slice).
        theme: buildLightTheme(),
        darkTheme: buildDarkTheme(),
        themeMode: ThemeMode.system,
        home: HomeScreen(pokemon: pokemon, chart: chart),
      ),
    );
  }
}
