import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/timetable_models.dart';

enum TimetableAudience { student, staff }

class DailyPeriodStrip extends StatelessWidget {
  const DailyPeriodStrip({
    super.key,
    required this.periodsPerDay,
    required this.entries,
    required this.audience,
  });

  final int periodsPerDay;
  final List<TimetableEntry> entries;
  final TimetableAudience audience;

  @override
  Widget build(BuildContext context) {
    final byPeriod = <int, TimetableEntry>{
      for (final entry in entries.where((entry) => !entry.isExam))
        entry.periodIndex: entry,
    };
    final assigned = byPeriod.length.clamp(0, periodsPerDay);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Today\'s periods',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              '$assigned of $periodsPerDay assigned',
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Column(
          key: const ValueKey('daily-period-strip'),
          children: [
            for (var period = 1; period <= periodsPerDay; period++) ...[
              _PeriodCard(
                period: period,
                entry: byPeriod[period],
                audience: audience,
              ),
              if (period != periodsPerDay) const SizedBox(height: 8),
            ],
          ],
        ),
      ],
    );
  }
}

class _PeriodCard extends StatelessWidget {
  const _PeriodCard({
    required this.period,
    required this.entry,
    required this.audience,
  });

  final int period;
  final TimetableEntry? entry;
  final TimetableAudience audience;

  @override
  Widget build(BuildContext context) {
    final entry = this.entry;
    final accent = entry?.categoryColor ?? AppColors.muted;
    final subject = entry == null
        ? 'Free period'
        : _subjectLabel(entry.subjectName);
    final detail = entry == null
        ? 'Available for allocation'
        : audience == TimetableAudience.student
        ? entry.facultyName
        : '${_departmentLabel(entry.className)}  |  Class ${entry.className}';

    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.45)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$period',
                style: TextStyle(
                  color: accent,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subject,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              constraints: const BoxConstraints(minWidth: 82),
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                entry?.timeSlot ?? 'Period $period',
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  height: 1.15,
                  color: accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _departmentLabel(String className) {
    final prefix = className.trim().toUpperCase().split('-').first;
    return switch (prefix) {
      'ECE' => 'ECE',
      'ME' => 'Mechanical',
      'CS' => 'Computer Science',
      _ => prefix,
    };
  }

  String _subjectLabel(String raw) {
    var value = raw.trim();
    for (final separator in const ['â€“', 'â€”', 'â€', '–', '—']) {
      final index = value.indexOf(separator);
      if (index > 0) value = value.substring(0, index).trim();
    }
    value = value
        .replaceFirst(RegExp(r'\s*-\s*\([^)]*\)\s*$'), '')
        .replaceFirst(RegExp(r'\s*\([A-Z0-9]{1,8}\)\s*$'), '')
        .replaceAll('â€¦', '')
        .replaceAll('…', '')
        .trim();
    return value.isEmpty ? raw.trim() : value;
  }
}
