import 'package:flutter/material.dart';

import 'status_card_models.dart';

/// Timetable card designed like a crisp digital schedule display:
/// - Light blue background with deep navy typography
/// - Prominent digital lecture start time
/// - Subject, room number, and faculty details
/// - Digital clock and calendar grid motif
/// - Supports upcoming, ongoing, and completed states
class TimetableScheduleCard extends StatelessWidget {
  const TimetableScheduleCard({
    super.key,
    required this.data,
    required this.onTap,
  });

  final TimetableScheduleCardData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF0F7FF);
    final borderColor = isDark ? const Color(0xFF1E3A8A) : const Color(0xFFBFDBFE);
    final primaryBlue = isDark ? const Color(0xFF60A5FA) : const Color(0xFF1E40AF);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF3B82F6);

    final statusTag = data.isCompletedToday
        ? 'DAY COMPLETE'
        : data.isOngoing
            ? 'ONGOING NOW'
            : 'NEXT CLASS';

    final tagBg = data.isOngoing
        ? const Color(0xFF22C55E)
        : (isDark ? const Color(0xFF1E3A8A) : const Color(0xFFDBEAFE));
    final tagText = data.isOngoing
        ? Colors.white
        : (isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E40AF));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 128,
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF3B82F6).withValues(alpha: isDark ? 0.2 : 0.08),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top row: Schedule tag + Room Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: tagBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          data.isOngoing
                              ? Icons.play_circle_fill_rounded
                              : Icons.schedule_rounded,
                          size: 11,
                          color: tagText,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          statusTag,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: tagText,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (data.room.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFBFDBFE),
                        ),
                      ),
                      child: Text(
                        data.room,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: primaryBlue,
                        ),
                      ),
                    ),
                ],
              ),

              // Main middle row: Time on left, Subject & Lecturer on right
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Start time block
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.startTime,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: primaryBlue,
                          letterSpacing: -0.5,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        data.countdownText ?? (data.isOngoing ? 'Period Active' : 'Today'),
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: subColor,
                        ),
                      ),
                    ],
                  ),

                  Container(
                    height: 38,
                    width: 1,
                    margin: const EdgeInsets.symmetric(horizontal: 14),
                    color: isDark ? const Color(0xFF1E3A8A) : const Color(0xFFDBEAFE),
                  ),

                  // Subject and faculty
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data.subject,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                            height: 1.15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          data.faculty.isNotEmpty ? data.faculty : 'Class Lecture',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Subtle bottom schedule motif dots
              Row(
                children: [
                  for (int i = 0; i < 6; i++) ...[
                    Container(
                      width: 12,
                      height: 3,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: (i == 1 && data.isOngoing)
                            ? const Color(0xFF22C55E)
                            : (i == 0 ? primaryBlue : (isDark ? const Color(0xFF1E293B) : const Color(0xFFDBEAFE))),
                        borderRadius: BorderRadius.circular(1.5),
                      ),
                    ),
                  ],
                  const Spacer(),
                  Text(
                    'Tap for full timetable',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 9.5,
                      color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
