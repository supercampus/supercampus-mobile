import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/timetable_models.dart';
import 'exam_alert_section.dart';

/// Universal Modal Dialog to display rich exam details on card tap.
void showExamDetailModal(BuildContext context, TimetableEntry exam) {
  final dateStr = exam.examDate != null
      ? DateFormat('EEEE, dd MMMM yyyy').format(exam.examDate!)
      : '${exam.dayOfWeek} (Scheduled Slot)';
  final startIdx = exam.startPeriodIndex ?? exam.periodIndex;
  final endIdx = exam.endPeriodIndex ?? exam.periodIndex;
  final spanText = startIdx == endIdx
      ? 'Period $startIdx'
      : 'Periods $startIdx–$endIdx';
  final hall = exam.hallNumber ?? 'Main Exam Hall (Block B)';
  final seat = exam.seatNumber ?? 'Seat Unassigned';
  final invigilator = exam.invigilatorName ?? exam.facultyName;
  final marks = exam.maxMarks ?? 100;
  final syllabusText =
      exam.syllabus ??
      'Units 1 & 2: Core Concepts, Problem Solving & System Architecture';
  final permittedItemsText =
      exam.permittedItems ??
      'Non-programmable Scientific Calculator, Physical College ID Card mandatory.';

  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      elevation: 10,
      child: Container(
        padding: const EdgeInsets.all(22),
        constraints: const BoxConstraints(maxWidth: 420),
        // The details scroll; the alert stays put at the foot of the dialog.
        // It is the only thing here a student can act on, and on a phone the
        // details are long enough to push it under the fold otherwise.
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Row: Exam Title Badge & Close Button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Flexible: a long category name on a narrow phone has to
                        // give way to the close button rather than push it off.
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0E7FF),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              (exam.examTitle ?? 'EXAMINATION').toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF3730A3),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.close,
                            size: 20,
                            color: Colors.grey,
                          ),
                          onPressed: () => Navigator.of(ctx).pop(),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Full Subject Name & Code
                    Text(
                      '${exam.subjectCode} - ${exam.subjectName}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E1B4B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Class ${exam.className} • $marks Maximum Marks',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),

                    const SizedBox(height: 16),
                    const Divider(height: 1, color: Color(0xFFE0E7FF)),
                    const SizedBox(height: 16),

                    // Date, Time Slot & Duration Section
                    _buildModalDetailRow(
                      icon: Icons.calendar_today_rounded,
                      iconColor: const Color(0xFF3730A3),
                      title: 'Date of Exam',
                      value: dateStr,
                    ),
                    const SizedBox(height: 12),
                    _buildModalDetailRow(
                      icon: Icons.access_time_rounded,
                      iconColor: const Color(0xFF4F46E5),
                      title: 'Time & Duration',
                      value:
                          '${exam.timeSlot}  ($spanText)\nTotal Duration: ${exam.duration ?? "1h 40m"}',
                    ),

                    const SizedBox(height: 16),
                    const Divider(height: 1, color: Color(0xFFE0E7FF)),
                    const SizedBox(height: 16),

                    // Venue & Seating Section
                    _buildModalDetailRow(
                      icon: Icons.account_balance_rounded,
                      iconColor: const Color(0xFF0284C7),
                      title: 'Assigned Venue & Desk',
                      value: '$hall  •  $seat',
                    ),
                    const SizedBox(height: 12),

                    // Supervision / Invigilator Section
                    _buildModalDetailRow(
                      icon: Icons.person_rounded,
                      iconColor: const Color(0xFF0D9488),
                      title: 'Chief Invigilator / Proctor',
                      value: invigilator,
                    ),

                    const SizedBox(height: 16),
                    const Divider(height: 1, color: Color(0xFFE0E7FF)),
                    const SizedBox(height: 16),

                    // Syllabus / Units Covered
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.menu_book_rounded,
                          size: 18,
                          color: Color(0xFF7C3AED),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Syllabus / Units Covered',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                syllabusText,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1F2937),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Permitted Items / Rules
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.verified_user_outlined,
                          size: 18,
                          color: Color(0xFFD97706),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Instructions & Permitted Items',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                permittedItemsText,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1F2937),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 18),

            // Reminder CTA. The dialog closes from the × above, so the space
            // at the foot of it goes to the one thing a student can act on.
            ExamAlertSection(exam: exam),
          ],
        ),
      ),
    ),
  );
}

/// Universal Modal Dialog to display rich class details on card tap.
void showClassDetailModal(
  BuildContext context,
  TimetableEntry entry, {
  FacultySubstitution? sub,
}) {
  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      elevation: 10,
      child: Container(
        padding: const EdgeInsets.all(22),
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: entry.isLab
                          ? Colors.purple.shade50
                          : Colors.indigo.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: entry.isLab
                            ? Colors.purple.shade200
                            : Colors.indigo.shade200,
                      ),
                    ),
                    child: Text(
                      entry.isLab ? 'LABORATORY SESSION' : 'REGULAR LECTURE',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: entry.isLab
                            ? Colors.purple.shade800
                            : Colors.indigo.shade800,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: Colors.grey),
                  onPressed: () => Navigator.of(ctx).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${entry.subjectCode} - ${entry.subjectName}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E1B4B),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Class Section: ${entry.className} • Slot Index: ${entry.periodIndex}',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: Color(0xFFE0E7FF)),
            const SizedBox(height: 16),
            _buildModalDetailRow(
              icon: Icons.access_time_rounded,
              iconColor: const Color(0xFF4F46E5),
              title: 'Scheduled Slot',
              value: '${entry.dayOfWeek} • ${entry.timeSlot}',
            ),
            const SizedBox(height: 12),
            _buildModalDetailRow(
              icon: Icons.person_rounded,
              iconColor: const Color(0xFF0D9488),
              title: sub != null ? 'Original Instructor' : 'Assigned Faculty',
              value: entry.facultyName,
            ),
            if (sub != null) ...[
              const SizedBox(height: 12),
              _buildModalDetailRow(
                icon: Icons.swap_horiz_rounded,
                iconColor: Colors.amber.shade800,
                title: 'Substitute Faculty Coverage',
                value: '${sub.substituteFaculty}\nReason: ${sub.reason}',
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF3730A3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Close Overview'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _buildModalDetailRow({
  required IconData icon,
  required Color iconColor,
  required String title,
  required String value,
}) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 18, color: iconColor),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
