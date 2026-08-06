import 'package:flutter/widgets.dart';

/// Emphasis for an insight. Drives colour only — the ranking is independent.
enum InsightTone { neutral, positive, caution, urgent }

/// The headline number, rendered as a progress ring.
class InsightMetric {
  const InsightMetric({
    required this.value,
    required this.label,
    this.caption,
  });

  /// 0..1, the filled portion of the ring.
  final double value;

  /// Short text inside the ring, e.g. `82%` or `₹240`.
  final String label;

  final String? caption;
}

/// One candidate card. Deliberately data-only: sources compute *what* to say
/// and how relevant it is, the presentation layer decides how it looks. That
/// keeps the ranking pure and unit-testable.
class Insight {
  const Insight({
    required this.sourceId,
    required this.relevance,
    required this.headline,
    required this.icon,
    required this.signature,
    this.supporting,
    this.metric,
    this.tone = InsightTone.neutral,
  });

  final String sourceId;

  /// 0..1 before novelty and fatigue are applied by the engine.
  final double relevance;

  final String headline;
  final String? supporting;
  final InsightMetric? metric;
  final IconData icon;
  final InsightTone tone;

  /// Changes whenever the underlying data changes. The engine compares it
  /// against the last shown value to award a novelty bonus, so a *newly*
  /// approved outpass outranks one approved yesterday.
  final String signature;
}

/// Everything the sources are allowed to look at. Assembled once per update
/// so every source sees a consistent view of the world.
class InsightContext {
  const InsightContext({
    required this.now,
    this.attendance,
    this.walletBalance,
  });

  final DateTime now;
  final AttendanceSnapshot? attendance;
  final double? walletBalance;
}

class AttendanceSnapshot {
  const AttendanceSnapshot({
    required this.attended,
    required this.total,
    this.requiredFraction = 0.75,
  });

  final int attended;
  final int total;

  /// Institution's minimum. Varies, so it is configuration rather than a
  /// constant baked into the source.
  final double requiredFraction;

  double get fraction => total == 0 ? 1 : attended / total;
}
