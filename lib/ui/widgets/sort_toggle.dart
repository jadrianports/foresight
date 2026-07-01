import 'package:flutter/material.dart';

import '../../engine/ranking.dart';
import '../../theme/cartridge_colors.dart';
import '../../theme/cartridge_physics.dart';
import '../../theme/cartridge_typography.dart';

/// The Cartridge segmented sort control (Story 3.6): two equal-width segments —
/// **"SAFEST FIRST"** | **"HARDEST HITTING"** — that re-sort the SAME Result
/// list in place. The ACTIVE segment inverts to `ink` ground / `paper` text (the
/// loud "this is selected" cue); the inactive one is `surface` / `inkMuted`.
///
/// PURELY PRESENTATIONAL: it holds no state and knows nothing of
/// `SettingsController`/`provider`. The screen passes the active [mode] down and
/// gets the tapped mode back via [onChanged], so the widget is testable in
/// isolation (project-context dependency direction: a widget reads theme + engine
/// value types only, never `data`/Provider). [DESIGN.md:211-220/:382]
class SortToggle extends StatelessWidget {
  const SortToggle({super.key, required this.mode, required this.onChanged});

  /// The currently-active sort mode — drives which segment renders inverted.
  final SortMode mode;

  /// Fired with a segment's mode when it is tapped. Tapping the already-active
  /// segment still fires; `SettingsController.setSortMode` no-ops on an unchanged
  /// value, so that is harmless.
  final ValueChanged<SortMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CartridgeColors>()!;

    return Container(
      // DESIGN sort-toggle: 3px ink border, 4px block-shadow (offsetStandard),
      // square corners — the standard raised Cartridge surface.
      decoration: BoxDecoration(
        color: colors.surface,
        border: CartridgePhysics.cartridgeBorder(colors.ink),
        boxShadow: [CartridgePhysics.cartridgeShadow(colors.shadow)],
      ),
      // IntrinsicHeight + stretch so the divider matches the segments' height.
      // Without it, the childless divider Container collapses to height 0 under
      // the unbounded vertical constraints of ResultScreen's ListView, and the
      // 3px ink divider AC#7 requires renders invisibly.
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
                child: _segment(colors, SortMode.safestFirst, 'SAFEST FIRST')),
            // 3px ink divider between the two segments (DESIGN sort-toggle).
            Container(width: CartridgePhysics.borderWidth, color: colors.ink),
            Expanded(
                child:
                    _segment(colors, SortMode.hardestHitting, 'HARDEST HITTING')),
          ],
        ),
      ),
    );
  }

  /// One tappable segment. Active → `ink` ground / `paper` label; inactive →
  /// `surface` ground / `inkMuted` label. The label is a plain [Text] with the
  /// VERBATIM DESIGN string so `find.text(...)` matches it exactly.
  Widget _segment(CartridgeColors colors, SortMode segmentMode, String label) {
    final active = segmentMode == mode;
    return GestureDetector(
      onTap: () => onChanged(segmentMode),
      child: Container(
        // The whole box is tappable, not just the glyphs (transparent ≠ null).
        color: active ? colors.ink : colors.surface,
        // Comfortable tap height now; the FORMAL ≥44pt audit is Story 3.8.
        padding: const EdgeInsets.symmetric(
          vertical: CartridgePhysics.s3,
          horizontal: CartridgePhysics.s2,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: CartridgeTypography.badge.copyWith(
            color: active ? colors.paper : colors.inkMuted,
          ),
        ),
      ),
    );
  }
}
