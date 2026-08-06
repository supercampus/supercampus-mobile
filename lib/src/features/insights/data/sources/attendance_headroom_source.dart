import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/access/effective_permissions.dart';
import '../../../../core/access/module_catalog.dart';
import '../insight.dart';
import '../insight_source.dart';

/// "Can I skip tomorrow?" — the number students actually check.
///
/// Shows the answer rather than the percentage, because a percentage makes
/// them do the arithmetic themselves.
class AttendanceHeadroomSource implements InsightSource {
  const AttendanceHeadroomSource();

  @override
  String get id => 'attendance_headroom';

  @override
  bool isAvailable(EffectivePermissions permissions) =>
      permissions.canSeeModule(ModuleCatalog.attendance);

  @override
  Insight? evaluate(InsightContext context) {
    final attendance = context.attendance;
    if (attendance == null || attendance.total == 0) return null;

    final required = attendance.requiredFraction;
    final fraction = attendance.fraction;
    final percent = (fraction * 100).round();
    final requiredPercent = (required * 100).round();

    final String headline;
    final double relevance;
    final InsightTone tone;

    if (fraction >= required) {
      // Largest k where attended / (total + k) still clears the threshold.
      final headroom = math.max(
        0,
        (attendance.attended / required - attendance.total).floor(),
      );

      headline = switch (headroom) {
        0 => "Don't miss your next class",
        1 => 'You can miss 1 more class',
        _ => 'You can miss $headroom more classes',
      };
      // Tightens as the buffer shrinks — 9 spare classes is barely news.
      relevance = (1 - headroom / 12).clamp(0.2, 0.95);
      tone = headroom <= 1 ? InsightTone.caution : InsightTone.positive;
    } else {
      // Smallest m where (attended + m) / (total + m) clears the threshold.
      final needed =
          ((required * attendance.total - attendance.attended) / (1 - required))
              .ceil();

      headline = needed == 1
          ? 'Attend 1 more class to clear $requiredPercent%'
          : 'Attend $needed in a row to clear $requiredPercent%';
      relevance = 1.0;
      tone = InsightTone.urgent;
    }

    return Insight(
      sourceId: id,
      relevance: relevance,
      headline: headline,
      supporting:
          '$percent% attended · '
          '${attendance.attended}/${attendance.total} classes',
      metric: InsightMetric(
        value: fraction.clamp(0.0, 1.0),
        label: '$percent%',
      ),
      icon: Icons.event_available_outlined,
      tone: tone,
      signature: '${attendance.attended}/${attendance.total}',
    );
  }
}
