import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/timetable_models.dart';

/// Local State Store for Timetable Reminder Alerts
class TimetableAlertConfig {
  final int leadTime;
  final String unit; // 'minutes', 'hours', 'days'

  const TimetableAlertConfig({
    required this.leadTime,
    required this.unit,
  });
}

class TimetableAlertsManager {
  static final Map<String, TimetableAlertConfig> _alerts = {};

  static String _getKey(TimetableEntry entry) {
    if (entry.id.isNotEmpty) return entry.id;
    return '${entry.subjectCode}_${entry.dayOfWeek}_${entry.periodIndex}';
  }

  static TimetableAlertConfig? getAlert(TimetableEntry entry) {
    return _alerts[_getKey(entry)];
  }

  static void setAlert(TimetableEntry entry, int leadTime, String unit) {
    _alerts[_getKey(entry)] = TimetableAlertConfig(leadTime: leadTime, unit: unit);
  }

  static void removeAlert(TimetableEntry entry) {
    _alerts.remove(_getKey(entry));
  }
}

/// Universal Modal Dialog to display rich exam details with inline alert picker.
void showExamDetailModal(BuildContext context, TimetableEntry exam) {
  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      elevation: 10,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        child: _ExamDetailModalContent(exam: exam),
      ),
    ),
  );
}

/// Universal Modal Dialog to display rich class details with inline alert picker.
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
        constraints: const BoxConstraints(maxWidth: 420),
        child: _ClassDetailModalContent(entry: entry, sub: sub),
      ),
    ),
  );
}

class _ExamDetailModalContent extends StatefulWidget {
  const _ExamDetailModalContent({required this.exam});
  final TimetableEntry exam;

  @override
  State<_ExamDetailModalContent> createState() => _ExamDetailModalContentState();
}

class _ExamDetailModalContentState extends State<_ExamDetailModalContent> {
  bool _isAlertSectionExpanded = false;
  late int _leadTime;
  late String _unit;
  bool _isAlertActive = false;

  @override
  void initState() {
    super.initState();
    final activeAlert = TimetableAlertsManager.getAlert(widget.exam);
    if (activeAlert != null) {
      _isAlertActive = true;
      _leadTime = activeAlert.leadTime;
      _unit = activeAlert.unit;
    } else {
      _leadTime = 15;
      _unit = 'minutes';
    }
  }

  void _saveAlert() {
    TimetableAlertsManager.setAlert(widget.exam, _leadTime, _unit);
    final message = 'Alert set for $_leadTime $_unit before ${widget.exam.subjectCode}';
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.notifications_active, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF3730A3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
    Navigator.of(context).pop();
  }

  void _deleteAlert() {
    TimetableAlertsManager.removeAlert(widget.exam);
    setState(() {
      _isAlertActive = false;
      _isAlertSectionExpanded = false;
    });
    final message = 'Alert deleted for ${widget.exam.subjectCode}';
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.notifications_off_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final exam = widget.exam;
    final dateStr = exam.examDate != null
        ? DateFormat('EEEE, dd MMMM yyyy').format(exam.examDate!)
        : '${exam.dayOfWeek} (Scheduled Slot)';
    final startIdx = exam.startPeriodIndex ?? exam.periodIndex;
    final endIdx = exam.endPeriodIndex ?? exam.periodIndex;
    final spanText = startIdx == endIdx ? 'Period $startIdx' : 'Periods $startIdx–$endIdx';
    final hall = exam.hallNumber ?? 'Main Exam Hall (Block B)';
    final seat = exam.seatNumber ?? 'Seat Unassigned';
    final invigilator = exam.invigilatorName ?? exam.facultyName;
    final marks = exam.maxMarks ?? 100;
    final syllabusText = exam.syllabus ??
        'Units 1 & 2: Core Concepts, Problem Solving & System Architecture';
    final permittedItemsText = exam.permittedItems ??
        'Non-programmable Scientific Calculator, Physical College ID Card mandatory.';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Exam Title Badge & Close Icon
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E7FF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  (exam.examTitle ?? 'EXAMINATION').toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF3730A3),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20, color: Colors.grey),
                onPressed: () => Navigator.of(context).pop(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Active Alert Indicator (If alert is active)
          if (_isAlertActive) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFC7D2FE)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.notifications_active_rounded,
                      size: 18, color: Color(0xFF3730A3)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Alert Active: Remind $_leadTime $_unit before start',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3730A3),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

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
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
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
            value: '${exam.timeSlot}  ($spanText)\nTotal Duration: ${exam.duration ?? "1h 40m"}',
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
              const Icon(Icons.menu_book_rounded, size: 18, color: Color(0xFF7C3AED)),
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
              const Icon(Icons.verified_user_outlined, size: 18, color: Color(0xFFD97706)),
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

          // Inline Alert Configuration Picker (Expanded when configuring or alert active)
          if (_isAlertActive || _isAlertSectionExpanded) ...[
            const SizedBox(height: 16),
            _buildInlineAlertPicker(
              leadTime: _leadTime,
              unit: _unit,
              onLeadTimeChanged: (val) => setState(() => _leadTime = val),
              onUnitChanged: (val) => setState(() => _unit = val),
            ),
          ],

          const SizedBox(height: 20),

          // Dynamic Modal Bottom Actions Bar (Replacing Close Details completely)
          if (!_isAlertActive && !_isAlertSectionExpanded) ...[
            // Default State (No Active Alert & Section Collapsed): Single Primary "Set Alert" Button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  setState(() {
                    _isAlertSectionExpanded = true;
                  });
                },
                icon: const Icon(Icons.add_alert_rounded, size: 18),
                label: const Text(
                  'Set Alert',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF3730A3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ] else ...[
            // Active or Editing State: Two-Button Layout (Delete Alert & Save/Update Alert)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _deleteAlert,
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text(
                      'Delete Alert',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFFCA5A5)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _saveAlert,
                    icon: const Icon(Icons.check_circle_rounded, size: 18),
                    label: Text(
                      _isAlertActive ? 'Update Alert' : 'Save Alert',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF3730A3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ClassDetailModalContent extends StatefulWidget {
  const _ClassDetailModalContent({required this.entry, this.sub});
  final TimetableEntry entry;
  final FacultySubstitution? sub;

  @override
  State<_ClassDetailModalContent> createState() => _ClassDetailModalContentState();
}

class _ClassDetailModalContentState extends State<_ClassDetailModalContent> {
  bool _isAlertSectionExpanded = false;
  late int _leadTime;
  late String _unit;
  bool _isAlertActive = false;

  @override
  void initState() {
    super.initState();
    final activeAlert = TimetableAlertsManager.getAlert(widget.entry);
    if (activeAlert != null) {
      _isAlertActive = true;
      _leadTime = activeAlert.leadTime;
      _unit = activeAlert.unit;
    } else {
      _leadTime = 15;
      _unit = 'minutes';
    }
  }

  void _saveAlert() {
    TimetableAlertsManager.setAlert(widget.entry, _leadTime, _unit);
    final message = 'Alert set for $_leadTime $_unit before ${widget.entry.subjectCode}';
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.notifications_active, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF3730A3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
    Navigator.of(context).pop();
  }

  void _deleteAlert() {
    TimetableAlertsManager.removeAlert(widget.entry);
    setState(() {
      _isAlertActive = false;
      _isAlertSectionExpanded = false;
    });
    final message = 'Alert deleted for ${widget.entry.subjectCode}';
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.notifications_off_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final sub = widget.sub;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: entry.isLab ? Colors.purple.shade50 : Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: entry.isLab ? Colors.purple.shade200 : Colors.indigo.shade200,
                  ),
                ),
                child: Text(
                  entry.isLab ? 'PRACTICAL / LAB SESSION' : 'REGULAR LECTURE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: entry.isLab ? Colors.purple.shade800 : Colors.indigo.shade800,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20, color: Colors.grey),
                onPressed: () => Navigator.of(context).pop(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Active Alert Indicator (If alert is active)
          if (_isAlertActive) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFC7D2FE)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.notifications_active_rounded,
                      size: 18, color: Color(0xFF3730A3)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Alert Active: Remind $_leadTime $_unit before start',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3730A3),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

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
            icon: Icons.location_on_rounded,
            iconColor: const Color(0xFF0284C7),
            title: 'Venue / Room',
            value: entry.isLab ? 'Computer Science Lab B302 (Block B)' : 'Lecture Hall 102 (Main Academic Block)',
          ),
          const SizedBox(height: 12),
          _buildModalDetailRow(
            icon: Icons.person_rounded,
            iconColor: const Color(0xFF0D9488),
            title: sub != null ? 'Original Faculty' : 'Assigned Faculty',
            value: entry.facultyName,
          ),
          if (sub != null) ...[
            const SizedBox(height: 12),
            _buildModalDetailRow(
              icon: Icons.swap_horiz_rounded,
              iconColor: Colors.amber.shade800,
              title: 'Substituted Faculty Coverage',
              value: 'Assigned to ${sub.substituteFaculty} in place of ${sub.originalFaculty}\nReason: ${sub.reason}',
            ),
          ],

          // Inline Alert Configuration Picker (Expanded when configuring or alert active)
          if (_isAlertActive || _isAlertSectionExpanded) ...[
            const SizedBox(height: 16),
            _buildInlineAlertPicker(
              leadTime: _leadTime,
              unit: _unit,
              onLeadTimeChanged: (val) => setState(() => _leadTime = val),
              onUnitChanged: (val) => setState(() => _unit = val),
            ),
          ],

          const SizedBox(height: 20),

          // Dynamic Modal Bottom Actions Bar (Replacing Close Details completely)
          if (!_isAlertActive && !_isAlertSectionExpanded) ...[
            // Default State (No Active Alert & Section Collapsed): Single Primary "Set Alert" Button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  setState(() {
                    _isAlertSectionExpanded = true;
                  });
                },
                icon: const Icon(Icons.add_alert_rounded, size: 18),
                label: const Text(
                  'Set Alert',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF3730A3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ] else ...[
            // Active or Editing State: Two-Button Layout (Delete Alert & Save/Update Alert)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _deleteAlert,
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text(
                      'Delete Alert',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFFCA5A5)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _saveAlert,
                    icon: const Icon(Icons.check_circle_rounded, size: 18),
                    label: Text(
                      _isAlertActive ? 'Update Alert' : 'Save Alert',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF3730A3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

Widget _buildInlineAlertPicker({
  required int leadTime,
  required String unit,
  required ValueChanged<int> onLeadTimeChanged,
  required ValueChanged<String> onUnitChanged,
}) {
  return Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFF5F7FF),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFC7D2FE), width: 1.2),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.alarm_add_rounded, size: 18, color: Color(0xFF3730A3)),
            SizedBox(width: 8),
            Text(
              'Configure Reminder Lead Time',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E1B4B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Remind me before session starts:',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            // Stepper Minus Button
            InkWell(
              onTap: () {
                if (leadTime > 1) onLeadTimeChanged(leadTime - 1);
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFC7D2FE)),
                ),
                child: const Icon(Icons.remove_rounded,
                    size: 18, color: Color(0xFF3730A3)),
              ),
            ),
            const SizedBox(width: 8),

            // Stepper Value Display
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFC7D2FE)),
              ),
              child: Text(
                '$leadTime',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E1B4B),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Stepper Plus Button
            InkWell(
              onTap: () {
                if (leadTime < 120) onLeadTimeChanged(leadTime + 1);
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFC7D2FE)),
                ),
                child: const Icon(Icons.add_rounded,
                    size: 18, color: Color(0xFF3730A3)),
              ),
            ),
            const SizedBox(width: 12),

            // Unit Switcher Dropdown
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFC7D2FE)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: unit,
                    isExpanded: true,
                    icon: const Icon(Icons.arrow_drop_down_rounded,
                        color: Color(0xFF3730A3)),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E1B4B),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'minutes', child: Text('minutes')),
                      DropdownMenuItem(value: 'hours', child: Text('hours')),
                      DropdownMenuItem(value: 'days', child: Text('days')),
                    ],
                    onChanged: (val) {
                      if (val != null) onUnitChanged(val);
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
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
