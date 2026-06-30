import 'package:flutter/material.dart';

import 'cartridge_colors.dart';

/// The 18 canonical Pokémon type fills, keyed by **lowercase PokeAPI slug**.
///
/// These are theme-INDEPENDENT (a Fire chip is the same orange in light and
/// dark — the chip carries its own fill and ink-color text) and reserved
/// EXCLUSIVELY for type chips identifying an opponent's typing. They never carry
/// UI semantics and must never be reused for chrome or status. Hex copied
/// verbatim from DESIGN colors (type-normal … type-fairy).
const Map<String, Color> kTypeColors = <String, Color>{
  'normal': Color(0xFFA8A878),
  'fire': Color(0xFFF08030),
  'water': Color(0xFF6890F0),
  'electric': Color(0xFFF8D030),
  'grass': Color(0xFF78C850),
  'ice': Color(0xFF98D8D8),
  'fighting': Color(0xFFC03028),
  'poison': Color(0xFFA040A0),
  'ground': Color(0xFFE0C068),
  'flying': Color(0xFFA890F0),
  'psychic': Color(0xFFF85888),
  'bug': Color(0xFFA8B820),
  'rock': Color(0xFFB8A038),
  'ghost': Color(0xFF705898),
  'dragon': Color(0xFF7038F8),
  'dark': Color(0xFF705848),
  'steel': Color(0xFFB8B8D0),
  'fairy': Color(0xFFEE99AC),
};

/// The five type fills dark enough to need WHITE label text for ≥4.5:1 WCAG AA;
/// every other fill takes ink text. Keyed by lowercase slug (never a display
/// string — `'Fire'` would silently miss).
const Set<String> kWhiteTextTypeFills = <String>{
  'fighting',
  'poison',
  'ghost',
  'dragon',
  'dark',
};

/// The label color a type chip must use for its [slug] fill to clear ≥4.5:1.
///
/// The chip fill is theme-independent, so its text is too: the canonical olive
/// ink ([CartridgeColors.light].ink, #20300F) on every light/bright/mid fill,
/// white only on the five dark fills. The contrast floor for each pairing is
/// locked by `test/theme/contrast_test.dart`. (Epic 3's chip widget consumes
/// this rule; this story only supplies it — no chip is rendered here.)
Color typeChipTextColor(String slug) {
  return kWhiteTextTypeFills.contains(slug)
      ? Colors.white
      : CartridgeColors.light.ink;
}
