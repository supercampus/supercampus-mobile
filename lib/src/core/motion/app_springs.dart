import 'package:flutter/widgets.dart';

/// Springs described the way Apple's designers describe them.
///
/// Apple replaced the physics triplet (mass / stiffness / damping) with two
/// parameters that map to what you actually see:
///
/// * **damping ratio** — overshoot. `1.0` settles without bouncing; below that
///   it overshoots, and lower bounces more.
/// * **response** — how quickly the value reaches the target, in seconds. It is
///   *not* a duration: a spring has no fixed end, and its settle time falls out
///   of the parameters.
///
/// Flutter wants the triplet, so this converts. Response is the natural period,
/// so `ω₀ = 2π / response`, `stiffness = m·ω₀²`, and `damping = 2·ζ·ω₀·m`.
class AppSprings {
  const AppSprings._();

  /// The house default: critically damped, no overshoot. Use for anything that
  /// simply moves or returns — overshoot on a card that merely slid back reads
  /// as noise.
  static final SpringDescription standard = describe(
    dampingRatio: 1,
    response: 0.4,
  );

  /// For motion the user's own gesture launched. The bounce is earned by the
  /// flick that preceded it, so it belongs here and nowhere else.
  static final SpringDescription momentum = describe(
    dampingRatio: 0.8,
    response: 0.3,
  );

  static SpringDescription describe({
    required double dampingRatio,
    required double response,
    double mass = 1,
  }) {
    final omega = 2 * pi / response;
    return SpringDescription(
      mass: mass,
      stiffness: mass * omega * omega,
      damping: 2 * dampingRatio * omega * mass,
    );
  }

  static const double pi = 3.1415926535897932;
}

/// Where a flick would come to rest if it decelerated like a scroll.
///
/// This is Apple's projection from the *Designing Fluid Interfaces* sample, not
/// the textbook `v²/2a`. Snapping from the release point ignores how hard the
/// user threw the thing; projecting forward is what makes a flick feel like a
/// throw.
double projectMomentum(double velocity, {double decelerationRate = 0.998}) =>
    (velocity / 1000) * decelerationRate / (1 - decelerationRate);

/// Progressive resistance past a boundary.
///
/// A hard stop reads as frozen. Resistance that grows with the overshoot reads
/// as "still listening, but there is nothing more this way".
double rubberband(
  double overshoot,
  double dimension, {
  double constant = 0.55,
}) {
  if (dimension <= 0) return overshoot;
  return (overshoot * dimension * constant) /
      (dimension + constant * overshoot.abs());
}

/// Whether this device is asking for gentler, non-vestibular motion.
///
/// Reduced motion does not mean no feedback — callers should keep the state
/// change and its colour, and drop only the travel.
bool prefersReducedMotion(BuildContext context) =>
    MediaQuery.maybeOf(context)?.disableAnimations ?? false;
