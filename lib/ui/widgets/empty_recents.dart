import 'package:flutter/material.dart';

import '../../theme/cartridge_colors.dart';
import '../../theme/cartridge_physics.dart';
import '../../theme/cartridge_typography.dart';

/// The recent-strip empty state (AC#6): a 3px DASHED ink box on `surface` with
/// one centered muted line. Shown in the strip slot when there is no history —
/// the sprite grid below stays fully populated (this is NOT a whole-screen empty
/// state). No spinner, no skeleton (AD-7).
///
/// Flutter's `BoxDecoration.border` has no dash support, so the dashed rect is a
/// dependency-free hand-rolled [CustomPainter] (NFR6 forbids a new package) —
/// mirroring the `_HatchPainter` `CustomPaint` precedent in `tier_result_row.dart`.
class EmptyRecents extends StatelessWidget {
  const EmptyRecents({super.key});

  /// Verbatim UX copy (UX-DR9 / EXPERIENCE.md:45) — do NOT reword.
  static const String message =
      'No recent matchups yet — tap a Pokémon to start.';

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CartridgeColors>()!;

    return CustomPaint(
      painter: _DashedRectPainter(color: colors.ink),
      child: Container(
        width: double.infinity,
        color: colors.surface,
        padding: const EdgeInsets.all(CartridgePhysics.s4),
        child: Text(
          message,
          // Wraps (not hard-clipped) so the deferred Story 3.8 dynamic-type pass
          // stays unblocked (mirrors _NoResults in home_screen.dart).
          style: CartridgeTypography.body.copyWith(color: colors.inkMuted),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

/// Strokes a 3px dashed rectangle in [color] around the painter's bounds. Cheap:
/// four dashed edges. Decorative border only — the fill/content is the child.
class _DashedRectPainter extends CustomPainter {
  _DashedRectPainter({required this.color});

  final Color color;

  static const double _dash = 6;
  static const double _gap = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = CartridgePhysics.borderWidth // 3px
      ..style = PaintingStyle.stroke;

    // Inset by half the stroke so the 3px line sits fully inside the bounds
    // (a centered stroke would otherwise clip its outer half).
    const inset = CartridgePhysics.borderWidth / 2;
    final rect = Rect.fromLTRB(
      inset,
      inset,
      size.width - inset,
      size.height - inset,
    );

    void dashLine(Offset from, Offset to) {
      final total = (to - from).distance;
      if (total == 0) return;
      final dir = (to - from) / total;
      var drawn = 0.0;
      while (drawn < total) {
        final segEnd = (drawn + _dash).clamp(0.0, total);
        canvas.drawLine(from + dir * drawn, from + dir * segEnd, paint);
        drawn += _dash + _gap;
      }
    }

    final tl = rect.topLeft, tr = rect.topRight;
    final br = rect.bottomRight, bl = rect.bottomLeft;
    dashLine(tl, tr);
    dashLine(tr, br);
    dashLine(br, bl);
    dashLine(bl, tl);
  }

  @override
  bool shouldRepaint(_DashedRectPainter oldDelegate) =>
      oldDelegate.color != color;
}
