import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/pokemon_queries.dart';
import 'engine/type_chart.dart';
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
/// [settings] — the app's first root-provided `ChangeNotifier` (AD-6), created in
/// `main()` and exposed via `ChangeNotifierProvider.value` ABOVE `MaterialApp` so
/// the pushed `ResultScreen` (on the nav stack) can read the live sort mode
/// (Story 3.6). `SettingsController` now EXISTS for the sort preference; its
/// theme-override slice — and the manual System/Light/Dark switch — arrive in
/// Epic 4 (Story 4.2), at which point `themeMode` below stops being hard-wired.
class ForesightApp extends StatelessWidget {
  const ForesightApp({
    super.key,
    required this.pokemon,
    required this.chart,
    required this.settings,
  });

  /// The full bundled dex, resolved before `runApp` and handed to [HomeScreen].
  final List<PokemonListItem> pokemon;

  /// The in-memory type chart, injected down to the pushed `ResultScreen` so its
  /// `rank(...)` runs synchronously with no DB access (Story 3.4).
  final TypeChart chart;

  /// The root sort-preference controller, provided app-wide (Story 3.6).
  final SettingsController settings;

  @override
  Widget build(BuildContext context) {
    // `.value` because main() owns the controller's lifetime — this app-lifetime
    // singleton must NOT be disposed by the provider (the `create:` form would).
    // The provider sits ABOVE MaterialApp so routes its Navigator pushes can read
    // it (AD-6 root-provided).
    return ChangeNotifierProvider<SettingsController>.value(
      value: settings,
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
