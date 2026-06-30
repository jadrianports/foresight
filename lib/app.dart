import 'package:flutter/material.dart';

import 'theme/cartridge_colors.dart';
import 'theme/cartridge_theme.dart';
import 'theme/cartridge_typography.dart';

/// Placeholder root for the scaffold (Story 1.1), now dressed in the Cartridge
/// theme (Story 1.5). Proves the project builds, the two bundled fonts render
/// fully offline, and both light/dark themes apply via OS-follow. Real screens
/// (Epic 3+) replace `_ScaffoldCheckScreen` — keep it deliberately minimal.
class ForesightApp extends StatelessWidget {
  const ForesightApp({super.key, this.counts});

  /// Offline smoke-count proof (Story 1.4 AC#5): bundled-data row counts to render as
  /// device-observable evidence. Optional/nullable so `const ForesightApp()` stays valid
  /// for the Story 1.1 widget test; the proof line renders only when present.
  final ({int pokemon, int chart})? counts;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Foresight',
      debugShowCheckedModeBanner: false,
      // OS-follow at full light/dark parity (AC#4). The manual System/Light/Dark
      // override is Epic 4 (SettingsController via shared_preferences) — system
      // is correct and forward-compatible here.
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: ThemeMode.system,
      home: _ScaffoldCheckScreen(counts: counts),
    );
  }
}

class _ScaffoldCheckScreen extends StatelessWidget {
  const _ScaffoldCheckScreen({this.counts});

  final ({int pokemon, int chart})? counts;

  @override
  Widget build(BuildContext context) {
    // All styling now flows through the theme (AC#6: no inline GoogleFonts.* that
    // bypass it). The wordmark is the display role; sublines are the body roles.
    // Color comes from the brightness-correct CartridgeColors at the use-site.
    final ink = Theme.of(context).extension<CartridgeColors>()!.ink;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'FORESIGHT',
              style: CartridgeTypography.appTitle.copyWith(color: ink),
            ),
            const SizedBox(height: 20),
            Text(
              'Scaffold online — fonts bundled, offline.',
              style: CartridgeTypography.body.copyWith(color: ink),
            ),
            // Temporary AC#5 proof: shows the bundled DB opened and read fully offline.
            // Real screens are Epic 3 — this line goes away then.
            if (counts != null) ...[
              const SizedBox(height: 12),
              Text(
                '${counts!.pokemon} Pokémon · ${counts!.chart} chart rows',
                style: CartridgeTypography.bodySm.copyWith(color: ink),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
