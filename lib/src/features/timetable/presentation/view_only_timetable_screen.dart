import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../authentication/data/auth_repository.dart';
import '../data/timetable_models.dart';
import '../data/mock_timetable_repository.dart';
import 'widgets/timetable_grid_view.dart';
import 'widgets/weekly_date_strip.dart';
import 'widgets/month_calendar_dialog.dart';
import 'widgets/exam_detail_modal.dart';

class ViewOnlyTimetableScreen extends StatefulWidget {
  const ViewOnlyTimetableScreen({
    super.key,
    required this.session,
    required this.repository,
  });

  final UserSession session;
  final MockTimetableRepository repository;

  @override
  State<ViewOnlyTimetableScreen> createState() =>
      _ViewOnlyTimetableScreenState();
}

class _ViewOnlyTimetableScreenState extends State<ViewOnlyTimetableScreen> {
  DateTime _selectedDate = DateTime.now();
  late String _targetClass;
  int _viewMode = 0; // 0: Daily Classes, 1: Exam Schedule
  String _selectedExamFilter = 'All Exams';

  @override
  void initState() {
    super.initState();
    _targetClass = widget.session.departmentOrWard ?? 'CS-3A';
    if (!_targetClass.contains('CS') && !_targetClass.contains('-')) {
      _targetClass = 'CS-3A';
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.repository.getConfig();
    final entries = widget.repository.getEntriesForClass(_targetClass);
    final selectedDayStr = DateFormat('EEEE').format(_selectedDate);

    final activeSubs = widget.repository
        .getSubstitutions()
        .where((s) =>
            s.className == _targetClass &&
            s.status == 'Approved' &&
            s.dayOfWeek == selectedDayStr)
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        // Header Row with Title and Calendar Month Picker
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Student Timetable',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text(
                  '$_targetClass • Semester View',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
            if (_viewMode == 0)
              IconButton.filledTonal(
                tooltip: 'Month Calendar',
                onPressed: () async {
                  final date = await showDialog<DateTime>(
                    context: context,
                    builder: (ctx) =>
                        MonthCalendarDialog(selectedDate: _selectedDate),
                  );
                  if (date != null) {
                    setState(() => _selectedDate = date);
                  }
                },
                icon: const Icon(Icons.calendar_month_outlined),
              ),
          ],
        ),

        const SizedBox(height: 14),

        // Dedicated Student View Mode Switcher / Toggle [ Daily Classes | Exam Schedule ]
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _viewMode = 0),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _viewMode == 0 ? AppColors.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                      boxShadow: _viewMode == 0
                          ? [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.25),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              )
                            ]
                          : [],
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 16,
                          color: _viewMode == 0 ? Colors.white : Colors.grey.shade700,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Daily Classes',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: _viewMode == 0 ? Colors.white : Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _viewMode = 1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _viewMode == 1 ? const Color(0xFF3730A3) : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                      boxShadow: _viewMode == 1
                          ? [
                              BoxShadow(
                                color: const Color(0xFF3730A3).withValues(alpha: 0.25),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              )
                            ]
                          : [],
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.assignment_turned_in_rounded,
                          size: 16,
                          color: _viewMode == 1 ? Colors.white : Colors.grey.shade700,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Exam Schedule',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: _viewMode == 1 ? Colors.white : Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        if (_viewMode == 0) ...[
          // Mode 0: Daily Classes View (With Weekly Strip & Timetable Grid View)
          WeeklyDateStrip(
            selectedDate: _selectedDate,
            onDateSelected: (date) => setState(() => _selectedDate = date),
          ),
          const SizedBox(height: 16),
          TimetableGridView(
            entries: entries,
            workingDays: config.workingDays,
            selectedDay: DateFormat('EEEE').format(_selectedDate),
            selectedDate: _selectedDate,
            activeSubs: activeSubs,
            onDaySelected: (_) {},
            isEditable: false,
            showDayFilterChips: false,
          ),
        ] else ...[
          // Mode 1: Filtered Standalone Exam Schedule View
          _buildFilteredExamSchedule(context, entries),
        ],
      ],
    );
  }

  Widget _buildFilteredExamSchedule(
      BuildContext context, List<TimetableEntry> allEntries) {
    // 1. Filter entries based on dropdown selection
    final examEntries = allEntries.where((e) {
      if (!e.isExam) return false;
      if (_selectedExamFilter == 'All Exams') return true;
      final title = (e.examTitle ?? '').toLowerCase();
      final filter = _selectedExamFilter.toLowerCase();
      return title.contains(filter);
    }).toList();

    examEntries.sort((a, b) {
      if (a.examDate != null && b.examDate != null) {
        return a.examDate!.compareTo(b.examDate!);
      }
      return a.periodIndex.compareTo(b.periodIndex);
    });

    final bool hideCategoryTitle = _selectedExamFilter != 'All Exams';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Dynamic Dropdown Filter Header Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFC7D2FE)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.filter_alt_outlined, size: 18, color: Color(0xFF3730A3)),
                  SizedBox(width: 6),
                  Text(
                    'Filter Category:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E1B4B),
                    ),
                  ),
                ],
              ),
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedExamFilter,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded,
                      size: 20, color: Color(0xFF3730A3)),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF3730A3),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'All Exams', child: Text('All Exams')),
                    DropdownMenuItem(
                        value: 'Internal Assessment', child: Text('Internal Assessment')),
                    DropdownMenuItem(value: 'Midterm Exam', child: Text('Midterm Exam')),
                    DropdownMenuItem(value: 'Final Exam', child: Text('Final Exam')),
                    DropdownMenuItem(
                        value: 'Practical Evaluation', child: Text('Practical Evaluation')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedExamFilter = val);
                    }
                  },
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Exam Cards List or Empty State
        if (examEntries.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Icon(Icons.assignment_outlined, size: 56, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                Text(
                  'No ${_selectedExamFilter == "All Exams" ? "" : _selectedExamFilter} Exams Found',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  'There are currently no examination entries matching "$_selectedExamFilter" for $_targetClass.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              ],
            ),
          )
        else
          ...examEntries.map((exam) => _buildExamScheduleCard(
                context,
                exam,
                hideCategoryTitle: hideCategoryTitle,
              )),
      ],
    );
  }

  Widget _buildExamScheduleCard(
    BuildContext context,
    TimetableEntry exam, {
    bool hideCategoryTitle = false,
  }) {
    final dateStr = exam.examDate != null
        ? DateFormat('EEEE, dd MMM yyyy').format(exam.examDate!)
        : '${exam.dayOfWeek} (Scheduled Slot)';
    final examCategory = exam.examTitle ?? 'Official Examination';

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      color: const Color(0xFFF8F9FE),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFC7D2FE), width: 1.5),
      ),
      child: InkWell(
        onTap: () => showExamDetailModal(context, exam),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!hideCategoryTitle) ...[
                // Top Row: 1. Exam Category Title & Detail Arrow Action
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
                        examCategory.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF3730A3),
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    const Row(
                      children: [
                        Text(
                          'View Details',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF3730A3),
                          ),
                        ),
                        SizedBox(width: 2),
                        Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF3730A3)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // 2. Subject & Code
                Text(
                  '${exam.subjectCode} - ${exam.subjectName}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E1B4B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ] else ...[
                // Primary Heading: Subject & Code (When Category Title is stripped by Dropdown Filter)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${exam.subjectCode} - ${exam.subjectName}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E1B4B),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Row(
                      children: [
                        Text(
                          'View Details',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF3730A3),
                          ),
                        ),
                        SizedBox(width: 2),
                        Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF3730A3)),
                      ],
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 10),

              // 3. Date of Exam
              Row(
                children: [
                  const Icon(Icons.event_note_rounded, size: 15, color: Color(0xFF3730A3)),
                  const SizedBox(width: 6),
                  Text(
                    dateStr,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF3730A3),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 6),

              // 4. Time Duration (Strictly time slot without period metadata)
              Row(
                children: [
                  const Icon(Icons.access_time_rounded, size: 15, color: Color(0xFF4F46E5)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      exam.timeSlot,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E1B4B),
                      ),
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
