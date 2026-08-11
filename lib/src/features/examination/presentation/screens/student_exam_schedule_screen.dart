import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../timetable/data/mock_timetable_repository.dart';
import '../../../timetable/data/timetable_models.dart';

/// Student read-only exam schedule sourced from Campus Timetable Management.
class StudentExamScheduleScreen extends StatelessWidget {
  const StudentExamScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final entries =
        MockTimetableRepository()
            .getEntriesForClass('CS-3A')
            .where((entry) => entry.isExam)
            .toList()
          ..sort(
            (a, b) => (a.examDate ?? DateTime(2100)).compareTo(
              b.examDate ?? DateTime(2100),
            ),
          );

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Text(
          'Exam schedule',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        const Text(
          'Published by Campus Timetable Management',
          style: TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 18),
        for (final entry in entries) _ExamScheduleCard(entry: entry),
      ],
    );
  }
}

class _ExamScheduleCard extends StatelessWidget {
  const _ExamScheduleCard({required this.entry});
  final TimetableEntry entry;

  @override
  Widget build(BuildContext context) {
    final date = entry.examDate;
    final dateLabel = date == null
        ? 'Date pending'
        : '${date.day.toString().padLeft(2, '0')} ${_month(date.month)} ${date.year}';
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    entry.subjectName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  entry.subjectCode,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _detail(Icons.event_outlined, dateLabel),
            _detail(Icons.schedule_outlined, entry.timeSlot),
            _detail(
              Icons.room_outlined,
              '${entry.hallNumber ?? 'Venue pending'} · Seat ${entry.seatNumber ?? 'pending'}',
            ),
            _detail(
              Icons.assignment_outlined,
              entry.examTitle ?? 'Published examination',
            ),
          ],
        ),
      ),
    );
  }

  Widget _detail(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Row(
      children: [
        Icon(icon, size: 17, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 12))),
      ],
    ),
  );

  String _month(int month) => const [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ][month - 1];
}
