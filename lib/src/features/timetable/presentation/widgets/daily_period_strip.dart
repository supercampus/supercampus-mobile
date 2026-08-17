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
    final cardWidth = (MediaQuery.sizeOf(context).width * 0.72).clamp(
      238.0,
      292.0,
    );

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
        const SizedBox(height: 12),
        SizedBox(
          height: 208,
          child: ListView.separated(
            key: const ValueKey('daily-period-strip'),
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(right: 4),
            itemCount: periodsPerDay,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final period = index + 1;
              return SizedBox(
                width: cardWidth,
                child: _PeriodCard(
                  period: period,
                  entry: byPeriod[period],
                  audience: audience,
                ),
              );
            },
          ),
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
    final detail = entry == null
        ? 'Available for allocation'
        : audience == TimetableAudience.student
        ? entry.facultyName
        : '${_departmentLabel(entry.className)}  |  Class ${entry.className}';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$period',
                    style: TextStyle(
                      color: accent,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    entry?.timeSlot ?? 'Period $period',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              entry?.subjectName ?? 'Free period',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 18,
                height: 1.15,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              entry == null ? detail : '${entry.subjectCode}  |  $detail',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
            const SizedBox(height: 14),
            Container(height: 3, color: accent),
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
}
