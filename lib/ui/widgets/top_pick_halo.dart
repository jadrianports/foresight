import 'package:flutter/material.dart';

import '../../theme/cartridge_colors.dart';

/// The app's SINGLE animation (EXPERIENCE.md:86; DESIGN.md:298): a subtle,
/// SAFE-colored PULSE halo wrapped around the #1 SAFE top-pick row (Story 3.8
/// AC#2). It is the one carve-out from the zero-blur Cartridge rule — DESIGN
/// grants a soft blur ONLY here — and it is deliberately low-amplitude.
///
/// MOTION-GATED (AC#3): the halo reads `MediaQuery.disableAnimationsOf(context)`
/// (the platform Reduce-Motion flag). When motion is OFF it renders [child]
/// verbatim with NO animated halo and the controller stopped — the top pick then
/// reads via its AC#1 static cues (wider bar + `#1` marker + top-of-list rank).
/// The flag is re-evaluated in [didChangeDependencies] so a runtime OS toggle
/// takes effect and never leaves the ticker repeating with motion off.
///
/// Only the top-pick row is ever wrapped — non-top-pick rows own no controller
/// and pay no cost.
///
/// HARNESS NOTE (AC#10g): a repeating `AnimationController` NEVER quiesces, so
/// `tester.pumpAndSettle()` on a Result whose #1 pick is SAFE times out while the
/// pulse runs. Callers/tests therefore gate the pulse via `disableAnimations`
/// (the Result test `_host` injects `disableAnimations: true`); the one pulse
/// test overrides it false and drives frames with `tester.pump(Duration)`.
class TopPickHalo extends StatefulWidget {
  const TopPickHalo({required this.child, super.key});

  final Widget child;

  @override
  State<TopPickHalo> createState() => _TopPickHaloState();
}

class _TopPickHaloState extends State<TopPickHalo>
    with SingleTickerProviderStateMixin {
  // ~1.4s low-amplitude cycle, reversing, repeating — the single flourish.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reading the flag here establishes the MediaQuery dependency, so a runtime
    // Reduce-Motion toggle re-runs this and we resync the ticker (AC#3).
    _syncToMotionPref();
  }

  /// Run the repeating pulse ONLY when motion is allowed; stop and reset it when
  /// Reduce Motion is on. Never leave a controller repeating with motion off.
  void _syncToMotionPref() {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion) {
      if (_controller.isAnimating) {
        _controller.stop();
        _controller.value = 0;
      }
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Motion off → the child alone, no halo (the static cues carry it — AC#3).
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;

    // tierSafe is the theme-independent SAFE fill (#2E7D33) — the halo color.
    final safe = Theme.of(context).extension<CartridgeColors>()!.tierSafe;
    return AnimatedBuilder(
      animation: _controller,
      // The child subtree is built ONCE and reused across frames — only the
      // decoration's blur/spread/opacity pulse (cheap; the app's one animation).
      child: widget.child,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_controller.value);
        return DecoratedBox(
          decoration: BoxDecoration(
            // The ONE sanctioned soft shadow (DESIGN's single blur carve-out).
            boxShadow: [
              BoxShadow(
                color: safe.withValues(alpha: 0.15 + 0.35 * t),
                blurRadius: 6 + 10 * t,
                spreadRadius: 1 + 2 * t,
              ),
            ],
          ),
          child: child,
        );
      },
    );
  }
}
