import 'package:flutter/material.dart';

import '../../theme/cartridge_colors.dart';
import '../../theme/cartridge_physics.dart';
import '../../theme/cartridge_typography.dart';

/// The Home search bar (`{components.search-bar}`): a Cartridge-framed text
/// input that live-filters the grid on every keystroke (Story 3.2).
///
/// STATELESS by design — it owns no query. The single source of truth is
/// [HomeScreen]'s `setState` (AD-6: search text is transient per-screen state,
/// never lifted into a controller). This widget only paints the chrome and
/// forwards keystrokes via [onChanged]; the caller passes the live [controller]
/// so a programmatic clear round-trips. Mirrors the one-concern-per-file split
/// of `TypeChip` / `SpriteTile`.
///
/// There is deliberately NO submit path: no `onSubmitted`/`onEditingComplete`
/// wiring, because typing never navigates — it only narrows the grid in place
/// (AC#1). `autofocus` is off so Home opens calm (no keyboard on entry).
class SearchField extends StatelessWidget {
  const SearchField({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  /// Owned by [HomeScreen] so programmatic clears (and the current text) stay a
  /// single source of truth there.
  final TextEditingController controller;

  /// Fired on every keystroke — the ONLY signal this widget emits (no submit).
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CartridgeColors>()!;

    // The Cartridge border + block-shadow live on the OUTER container; the
    // TextField's own Material underline is killed with `InputBorder.none`.
    // No `borderRadius` → square corners (radiusDefault = 0; DESIGN Shapes:
    // "square… applies to… the search bar" — it is NOT a rounded pill).
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: CartridgePhysics.s4),
      decoration: BoxDecoration(
        color: colors.surface,
        border: CartridgePhysics.cartridgeBorder(colors.ink),
        boxShadow: [CartridgePhysics.cartridgeShadow(colors.shadow)],
      ),
      child: Row(
        children: [
          // Leading magnifier glyph (DESIGN components.search-bar).
          Icon(Icons.search, color: colors.inkMuted),
          const SizedBox(width: CartridgePhysics.s3),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              autofocus: false,
              // Cosmetic only — the enter key must NOT navigate (AC#1).
              textInputAction: TextInputAction.search,
              style: CartridgeTypography.body.copyWith(color: colors.ink),
              decoration: InputDecoration(
                hintText: 'Search…',
                hintStyle:
                    CartridgeTypography.body.copyWith(color: colors.inkMuted),
                border: InputBorder.none,
                isDense: true,
                // {spacing.3} vertical (12); horizontal (16) comes from the
                // outer container padding above.
                contentPadding: const EdgeInsets.symmetric(
                  vertical: CartridgePhysics.s3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
