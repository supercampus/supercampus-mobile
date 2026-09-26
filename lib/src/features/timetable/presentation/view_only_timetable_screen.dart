import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/notifications/exam_alert_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../authentication/data/auth_repository.dart';
import '../data/timetable_models.dart';
import '../data/timetable_repository.dart';
import 'timetable_tones.dart';
import 'widgets/daily_period_strip.dart';
import 'widgets/weekly_date_strip.dart';
import 'widgets/month_calendar_dialog.dart';
import 'widgets/exam_detail_modal.dart';

class ViewOnlyTimetableScreen extends StatefulWidget {
  const ViewOnlyTimetableScreen({
    super.key,
    required this.session,
    required this.repository,
    required this.canConfigure,
  });

  final UserSession session;
  final TimetableRepository repository;

  /// Whether this person may shape the timetable rather than only read it.
  /// Resolved from their grants by whoever built this screen.
  final bool canConfigure;

  @override
  State<ViewOnlyTimetableScreen> createState() =>
      _ViewOnlyTimetableScreenState();
}

class _ViewOnlyTimetableScreenState extends State<ViewOnlyTimetableScreen> {
  AppPalette get _p => context.palette;

  DateTime _selectedDate = DateTime.now();
  late String _targetClass;
  int _viewMode = 0; // 0: Daily Classes, 1: Exam Schedule
  String _selectedExamFilter = 'All Exams';

  @override
  void initState() {
    super.initState();
    _targetClass = studentTimetableClassFor(
      availableClasses: widget.repository.getAvailableClasses(),
      claimedSectionId: widget.session.sectionId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAllocator = widget.canConfigure;
    final config = widget.repository.getConfig();
    final entries = widget.repository.getEntriesForClass(_targetClass);
    final selectedDayStr = DateFormat('EEEE').format(_selectedDate);

    final dayEntries = entries
        .where(
          (entry) =>
              entry.dayOfWeek.toLowerCase() == selectedDayStr.toLowerCase(),
        )
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
                Text(
                  isAllocator ? 'Published timetable' : 'Student Timetable',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  isAllocator
                      ? 'View and acknowledge the active schedule'
                      : '$_targetClass • Semester View',
                  style: TextStyle(fontSize: 12, color: context.grey(600)),
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

        // Timetable allocators can also inspect exam rows. Learners receive a
        // timetable-only surface: they may move between allocated dates but
        // cannot enter staff or examination operations from this module.
        if (isAllocator)
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: context.grey(200),
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
                        color: _viewMode == 0 ? _p.brand : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                        boxShadow: _viewMode == 0
                            ? [
                                BoxShadow(
                                  color: _p.brandInk.withValues(alpha: 0.25),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
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
                            color: _viewMode == 0
                                ? Colors.white
                                : context.grey(700),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Daily Classes',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: _viewMode == 0
                                  ? Colors.white
                                  : context.grey(700),
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
                        color: _viewMode == 1
                            ? const Color(0xFF3730A3)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                        boxShadow: _viewMode == 1
                            ? [
                                BoxShadow(
                                  color: const Color(
                                    0xFF3730A3,
                                  ).withValues(alpha: 0.25),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
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
                            color: _viewMode == 1
                                ? Colors.white
                                : context.grey(700),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Exam Schedule',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: _viewMode == 1
                                  ? Colors.white
                                  : context.grey(700),
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

        if (isAllocator) const SizedBox(height: 16),

        if (_viewMode == 0) ...[
          // Mode 0: Daily Classes View (With Weekly Strip & Timetable Grid View)
          WeeklyDateStrip(
            selectedDate: _selectedDate,
            onDateSelected: (date) => setState(() => _selectedDate = date),
          ),
          const SizedBox(height: 16),
          DailyPeriodStrip(
            periodsPerDay: config.periodsPerDay,
            entries: dayEntries,
            audience: TimetableAudience.student,
          ),
        ] else ...[
          // Mode 1: Filtered Standalone Exam Schedule View
          _buildFilteredExamSchedule(context, entries),
        ],
      ],
    );
  }

  Widget _buildFilteredExamSchedule(
    BuildContext context,
    List<TimetableEntry> allEntries,
  ) {
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
            color: _p.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.examLine),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.filter_alt_outlined,
                    size: 18,
                    color: context.examInk,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Filter Category:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: context.examHeading,
                    ),
                  ),
                ],
              ),
              // Flexible + isExpanded: the closed dropdown otherwise takes the
              // width of its longest option ("Practical Evaluation"), which
              // runs off the right of a narrow phone.
              Flexible(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedExamFilter,
                    isExpanded: true,
                    alignment: AlignmentDirectional.centerEnd,
                    icon: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: context.examInk,
                    ),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: context.examInk,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'All Exams',
                        child: Text('All Exams'),
                      ),
                      DropdownMenuItem(
                        value: 'Internal Assessment',
                        child: Text('Internal Assessment'),
                      ),
                      DropdownMenuItem(
                        value: 'Midterm Exam',
                        child: Text('Midterm Exam'),
                      ),
                      DropdownMenuItem(
                        value: 'Final Exam',
                        child: Text('Final Exam'),
                      ),
                      DropdownMenuItem(
                        value: 'Practical Evaluation',
                        child: Text('Practical Evaluation'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedExamFilter = val);
                      }
                    },
                  ),
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
              color: _p.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.grey(200)),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.assignment_outlined,
                  size: 56,
                  color: context.grey(400),
                ),
                const SizedBox(height: 12),
                Text(
                  'No ${_selectedExamFilter == "All Exams" ? "" : _selectedExamFilter} Exams Found',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'There are currently no examination entries matching "$_selectedExamFilter" for $_targetClass.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.grey(600), fontSize: 13),
                ),
              ],
            ),
          )
        else
          ...examEntries.map(
            (exam) => _buildExamScheduleCard(
              context,
              exam,
              hideCategoryTitle: hideCategoryTitle,
            ),
          ),
      ],
    );
  }

  /// The card's trailing affordance, carrying a bell once the student has an
  /// alert on this exam — otherwise the only way to tell is to open each one.
  Widget _viewDetailsRow(TimetableEntry exam) {
    return ListenableBuilder(
      listenable: ExamAlertService.instance,
      builder: (context, _) {
        final alerted = ExamAlertService.instance.alertFor(exam.id) != null;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (alerted) ...[
              Icon(
                Icons.notifications_active_rounded,
                size: 15,
                color: context.examAlertGreen,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              'View Details',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: context.examInk,
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.chevron_right_rounded, size: 18, color: context.examInk),
          ],
        );
      },
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
    final startIdx = exam.startPeriodIndex ?? exam.periodIndex;
    final endIdx = exam.endPeriodIndex ?? exam.periodIndex;
    final spanText = startIdx == endIdx
        ? 'Period $startIdx'
        : 'Periods $startIdx–$endIdx';
    final examCategory = exam.examTitle ?? 'Official Examination';
    final durationStr = exam.duration != null ? ' [${exam.duration}]' : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      color: context.examCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: context.examLine, width: 1.5),
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
                // Top Row: Exam Category Title & Detail Arrow Action
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: context.examSoft,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        examCategory.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: context.examInk,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    _viewDetailsRow(exam),
                  ],
                ),
                const SizedBox(height: 10),

                // 2. Subject & Code
                Text(
                  '${exam.subjectCode} - ${exam.subjectName}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: context.examHeading,
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
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: context.examHeading,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _viewDetailsRow(exam),
                  ],
                ),
              ],

              const SizedBox(height: 10),

              // 3. Date of Exam
              Row(
                children: [
                  Icon(
                    Icons.event_note_rounded,
                    size: 15,
                    color: context.examInk,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    dateStr,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.examInk,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 6),

              // 4. Duration / Time Slot
              Row(
                children: [
                  Icon(
                    Icons.access_time_rounded,
                    size: 15,
                    color: context.examAccent,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${exam.timeSlot} ($spanText)$durationStr',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: context.examHeading,
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
