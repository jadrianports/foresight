import 'package:flutter/material.dart';

import 'cartridge_colors.dart';
import 'cartridge_typography.dart';

/// The Cartridge [ThemeData] pair — "DS bright paper" (light) and "Game Boy at
/// night" (dark), each assembled from the SAME token tables so they cannot
/// drift. Dark is not a re-implementation: it is the [CartridgeColors.dark]
/// color instance over identical typography + physics (NFR8 parity).

/// Light theme — "DS bright paper" (the primary palette).
ThemeData buildLightTheme() => _buildTheme(Brightness.light, CartridgeColors.light);

/// Dark theme — "Game Boy at night" (a full peer, not an afterthought).
ThemeData buildDarkTheme() => _buildTheme(Brightness.dark, CartridgeColors.dark);

ThemeData _buildTheme(Brightness brightness, CartridgeColors c) {
  // ColorScheme carries ONLY the chrome Material widgets legitimately need
  // (surface/onSurface/background/primary). The bespoke tier + type palettes
  // live in the CartridgeColors extension, never here. Seed for the secondary
  // slots, then pin the ones the design fixes so defaults inherit Cartridge ink
  // on Cartridge paper.
  final colorScheme = ColorScheme.fromSeed(
    seedColor: c.primaryRed,
    brightness: brightness,
  ).copyWith(
    surface: c.surface,
    onSurface: c.ink,
    primary: c.primaryRed,
  );

  // Material defaults: stray `Text` is Nunito (body) in the brightness-correct
  // ink; the AppBar title is Press Start 2P. Per-component DESIGN roles are read
  // directly from CartridgeTypography by Epic 3 widgets — this textTheme just
  // gives Material sane Cartridge defaults, not the full role table.
  final textTheme = TextTheme(
    bodyLarge: CartridgeTypography.body.copyWith(color: c.ink),
    bodyMedium: CartridgeTypography.body.copyWith(color: c.ink),
    bodySmall: CartridgeTypography.bodySm.copyWith(color: c.ink),
  );

  return ThemeData(
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: c.paper,
    textTheme: textTheme,
    extensions: <ThemeExtension<dynamic>>[c],
    appBarTheme: AppBarTheme(
      backgroundColor: c.surface,
      foregroundColor: c.ink,
      // Depth is the block-shadow + a 3px ink bottom border applied by the Epic 3
      // AppBar widget — never Material elevation (DESIGN elevation).
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: CartridgeTypography.appbarTitle.copyWith(color: c.ink),
    ),
    // Square cards by default (DESIGN shapes: 0px corners, no Material softening).
    cardTheme: const CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    ),
  );
}
