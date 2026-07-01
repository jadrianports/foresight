import 'package:flutter/material.dart';

import 'data/pokemon_queries.dart';
import 'engine/type_chart.dart';
import 'theme/cartridge_theme.dart';
import 'ui/home_screen.dart';

/// The app root. Wires the Cartridge light/dark themes (Story 1.5, OS-follow at
/// full parity) and shows [HomeScreen] — the full-dex sprite grid (Story 3.1).
///
/// The dex and the type [chart] are both queried ONCE in the composition root
/// (`main()`) and injected here as plain value objects (AD-6: the UI never
/// touches sqflite/data — but a `TypeChart` is an immutable engine value object,
/// NOT a `Database` handle, so holding/passing it is fine). The manual
/// System/Light/Dark override arrives with `SettingsController` in Epic 4.
class ForesightApp extends StatelessWidget {
  const ForesightApp({super.key, required this.pokemon, required this.chart});

  /// The full bundled dex, resolved before `runApp` and handed to [HomeScreen].
  final List<PokemonListItem> pokemon;

  /// The in-memory type chart, injected down to the pushed `ResultScreen` so its
  /// `rank(...)` runs synchronously with no DB access (Story 3.4).
  final TypeChart chart;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Foresight',
      debugShowCheckedModeBanner: false,
      // OS-follow at full light/dark parity (Story 1.5 AC#4). The manual override
      // is Epic 4 (SettingsController via shared_preferences).
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: ThemeMode.system,
      home: HomeScreen(pokemon: pokemon, chart: chart),
    );
  }
}
