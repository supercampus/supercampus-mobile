import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/widgets/module_navigation_buttons.dart';
import '../../../core/widgets/skeleton_loading.dart';

import '../../../core/theme/app_theme.dart';
import '../../authentication/data/auth_repository.dart';
import '../../attendance/data/attendance_repository.dart';
import '../data/student_assessments_repository.dart';

String _mark(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(1);

/// Student/parent view of Academics. Staff marking stays in FacultyPortalScreen.
class StudentAcademicsShell extends StatefulWidget {
  const StudentAcademicsShell({
    super.key,
    required this.session,
    required this.onExitModule,
    this.initialAction,
    this.assessmentsSource,
    this.attendanceRepository,
  });

  final UserSession session;
  final VoidCallback onExitModule;
  final String? initialAction;
  final StudentAssessmentsSource? assessmentsSource;
  final AttendanceRepository? attendanceRepository;

  @override
  State<StudentAcademicsShell> createState() => _StudentAcademicsShellState();
}

class _StudentAcademicsShellState extends State<StudentAcademicsShell> {
  final _attendanceKey = GlobalKey();
  final _marksKey = GlobalKey();
  final _analysisKey = GlobalKey();
  List<StudentAssessment> _assessments = const [];
  bool _loadingAssessments = false;
  String? _assessmentError;
  Map<String, dynamic>? _attendanceSummary;
  bool _loadingAttendance = false;
  String? _attendanceError;
  DateTime _focusedAttendanceDay = DateTime.now();
  DateTime _selectedAttendanceDay = DateTime.now();
  bool _showAttendanceHistory = false;
  bool _showMarksResults = false;

  @override
  void initState() {
    super.initState();
    _loadAssessments();
    _loadAttendance();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showInitialAction());
  }

  void _showInitialAction() {
    if (!mounted) return;
    if (widget.initialAction == 'marks') {
      setState(() => _showMarksResults = true);
      return;
    }
    final key = switch (widget.initialAction) {
      'analysis' => _analysisKey,
      _ => _attendanceKey,
    };
    final target = key.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(target, duration: Duration.zero, alignment: 0);
    }
  }

  Future<void> _refresh() async {
    await Future.wait([_loadAttendance(), _loadAssessments()]);
  }

  Future<void> _loadAttendance() async {
    final repository = widget.attendanceRepository;
    if (repository == null) return;
    setState(() {
      _loadingAttendance = true;
      _attendanceError = null;
    });
    try {
      final summary = await repository.summary('me');
      if (!mounted) return;
      setState(() {
        _attendanceSummary = summary;
        final records = summary['records'];
        if (records is List && records.isNotEmpty && records.first is Map) {
          final latest = DateTime.tryParse(
            (records.first as Map)['heldOn']?.toString() ?? '',
          );
          if (latest != null) {
            _focusedAttendanceDay = latest;
            _selectedAttendanceDay = latest;
          }
        }
      });
    } on AttendanceException catch (error) {
      if (!mounted) return;
      setState(() => _attendanceError = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _attendanceError = 'Unable to load attendance records.');
    } finally {
      if (mounted) setState(() => _loadingAttendance = false);
    }
  }

  Future<void> _loadAssessments() async {
    final source = widget.assessmentsSource;
    if (source == null) return;
    setState(() {
      _loadingAssessments = true;
      _assessmentError = null;
    });
    try {
      final assessments = await source.loadAssessments();
      if (!mounted) return;
      setState(() => _assessments = assessments);
    } on StudentAssessmentsException catch (error) {
      if (!mounted) return;
      setState(() => _assessmentError = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _assessmentError = 'Unable to load assessment marks.');
    } finally {
      if (mounted) setState(() => _loadingAssessments = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    appBar: AppBar(
      backgroundColor: AppColors.gateBlue,
      foregroundColor: Colors.white,
      leading: ModuleBackButton(
        onPressed: _showAttendanceHistory || _showMarksResults
            ? () => setState(() {
                _showAttendanceHistory = false;
                _showMarksResults = false;
              })
            : widget.onExitModule,
        color: Colors.white,
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Academics'),
          Text(
            widget.session.displayName,
            style: const TextStyle(fontSize: 11, color: Colors.white70),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Refresh academics',
          onPressed: _loadingAssessments || _loadingAttendance
              ? null
              : _refresh,
          icon: const Icon(Icons.refresh),
        ),
        ModuleHomeButton(onPressed: widget.onExitModule, color: Colors.white),
      ],
    ),
    body: _showAttendanceHistory
        ? SingleChildScrollView(
            key: const ValueKey('attendance-history-page'),
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 32),
            child: _attendanceHistory(),
          )
        : _showMarksResults
        ? SingleChildScrollView(
            key: const ValueKey('marks-results-page'),
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 32),
            child: _marks(),
          )
        : SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                KeyedSubtree(key: _attendanceKey, child: _attendance()),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 24),
                KeyedSubtree(key: _marksKey, child: _marksResultsLink()),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 24),
                KeyedSubtree(key: _analysisKey, child: _analysis()),
              ],
            ),
          ),
  );

  int _count(String key) => switch (_attendanceSummary?[key]) {
    final int value => value,
    final num value => value.round(),
    _ => 0,
  };

  double _number(Object? value) => switch (value) {
    final num number => number.toDouble(),
    _ => 0,
  };

  List<Map<String, dynamic>> get _attendanceRecords {
    final value = _attendanceSummary?['records'];
    if (value is! List) return const [];
    return value.whereType<Map>().map((item) {
      return item.map((key, value) => MapEntry(key.toString(), value));
    }).toList();
  }

  Widget _attendance() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'Attendance overview',
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
      ),
      const SizedBox(height: 6),
      const Text(
        'Your attendance by subject',
        style: TextStyle(color: AppColors.muted),
      ),
      const SizedBox(height: 18),
      if (_loadingAttendance && _attendanceSummary == null)
        const Column(
          children: [
            SkeletonListRow(height: 118),
            SizedBox(height: 10),
            SkeletonListRow(height: 128),
            SizedBox(height: 10),
            SkeletonListRow(height: 128),
          ],
        )
      else if (_attendanceError != null && _attendanceSummary == null)
        _attendanceMessage(
          Icons.cloud_off_outlined,
          'Attendance could not be loaded',
          _attendanceError!,
        )
      else if (_count('totalClasses') == 0)
        _attendanceMessage(
          Icons.fact_check_outlined,
          'No attendance published yet',
          'A subject appears here after its staff member publishes the roll.',
        )
      else ...[
        if (_loadingAttendance) const LinearProgressIndicator(minHeight: 2),
        _overallAttendanceCard(),
        const SizedBox(height: 12),
        _attendanceHistoryLink(),
      ],
    ],
  );

  Widget _attendanceHistoryLink() => Card(
    elevation: 0,
    child: InkWell(
      key: const ValueKey('attendance-history-link'),
      borderRadius: BorderRadius.circular(16),
      onTap: () => setState(() => _showAttendanceHistory = true),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.gateBlue.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(
                Icons.calendar_month_outlined,
                color: AppColors.gateBlue,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Attendance history',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_attendanceRecords.length} published records · Calendar view',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.muted),
          ],
        ),
      ),
    ),
  );

  Widget _attendanceMessage(IconData icon, String title, String subtitle) =>
      Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppColors.muted),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  Widget _overallAttendanceCard() {
    final percentage = _number(_attendanceSummary?['percentage']);
    final accent = percentage < 75 ? Colors.orange : Colors.green;
    final grid = _weeklyAttendanceGrid();
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.school_outlined, color: accent),
            const SizedBox(height: 12),
            Text(
              '${percentage.round()}%',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: accent,
              ),
            ),
            const SizedBox(height: 12),
            for (var day = 0; day < grid.length; day++) ...[
              if (day > 0) const SizedBox(height: 5),
              Row(
                children: [
                  SizedBox(
                    width: 20,
                    child: Text(
                      const ['M', 'T', 'W', 'T', 'F'][day],
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 7),
                  for (var period = 0; period < 7; period++) ...[
                    if (period > 0) const SizedBox(width: 5),
                    Expanded(
                      child: _weeklyHeatCell(
                        grid[day][period],
                        day: day,
                        period: period,
                      ),
                    ),
                  ],
                ],
              ),
            ],
            const SizedBox(height: 16),
            const Text(
              'Overall attendance',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 2),
            Text(
              '${_count('presentClasses')} present  •  ${_count('absences')} absent  •  ${_count('onDutyClasses')} OD  •  ${_count('leaveClasses')} leave',
              style: const TextStyle(fontSize: 11, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }

  List<List<_WeeklyAttendanceStatus?>> _weeklyAttendanceGrid() {
    final grid = List.generate(
      5,
      (_) => List<_WeeklyAttendanceStatus?>.filled(7, null),
    );
    final dated = <(DateTime, Map<String, dynamic>)>[];
    for (final record in _attendanceRecords) {
      final heldOn = DateTime.tryParse(record['heldOn']?.toString() ?? '');
      if (heldOn != null) dated.add((heldOn, record));
    }
    if (dated.isEmpty) return grid;
    final anchor = dated
        .map((item) => item.$1)
        .reduce((current, next) => next.isAfter(current) ? next : current);
    final monday = DateTime(
      anchor.year,
      anchor.month,
      anchor.day,
    ).subtract(Duration(days: anchor.weekday - DateTime.monday));
    for (final (date, record) in dated) {
      final day = DateTime(
        date.year,
        date.month,
        date.day,
      ).difference(monday).inDays;
      if (day < 0 || day >= 5) continue;
      final status = switch (record['status']?.toString().toLowerCase()) {
        'present' => _WeeklyAttendanceStatus.present,
        'absent' => _WeeklyAttendanceStatus.absent,
        'od' || 'on_duty' => _WeeklyAttendanceStatus.onDuty,
        _ => null,
      };
      if (status == null) continue;
      final periods = RegExp(r'\d+')
          .allMatches(record['periodLabel']?.toString() ?? '')
          .map((match) => int.tryParse(match.group(0) ?? ''))
          .whereType<int>()
          .toList();
      if (periods.isEmpty) continue;
      final start = periods.first.clamp(1, 7);
      final end = (periods.length > 1 ? periods.last : start).clamp(start, 7);
      for (var period = start; period <= end; period++) {
        grid[day][period - 1] ??= status;
      }
    }
    return grid;
  }

  Widget _weeklyHeatCell(
    _WeeklyAttendanceStatus? status, {
    required int day,
    required int period,
  }) {
    final color = switch (status) {
      _WeeklyAttendanceStatus.present => const Color(0xFF1DCF00),
      _WeeklyAttendanceStatus.absent => const Color(0xFFFF1723),
      _WeeklyAttendanceStatus.onDuty => const Color(0xFFFFD600),
      null => const Color(0xFFE4E1EA),
    };
    final label = switch (status) {
      _WeeklyAttendanceStatus.present => 'present',
      _WeeklyAttendanceStatus.absent => 'absent',
      _WeeklyAttendanceStatus.onDuty => 'on duty',
      null => 'no record',
    };
    final weekday = const [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
    ][day];
    return Semantics(
      label: '$weekday period ${period + 1}: $label',
      child: AspectRatio(
        aspectRatio: 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(5),
          ),
        ),
      ),
    );
  }

  Widget _attendanceHistory() {
    final records = _attendanceRecords;
    final selectedRecords = records.where((record) {
      final date = DateTime.tryParse(record['heldOn']?.toString() ?? '');
      return date != null && isSameDay(date, _selectedAttendanceDay);
    }).toList();
    final dates = records
        .map((record) => DateTime.tryParse(record['heldOn']?.toString() ?? ''))
        .whereType<DateTime>()
        .toList();
    final earliest = dates.isEmpty
        ? DateTime(DateTime.now().year - 1)
        : dates.reduce((a, b) => a.isBefore(b) ? a : b);
    final latest = dates.isEmpty
        ? DateTime(DateTime.now().year + 1, 12, 31)
        : dates.reduce((a, b) => a.isAfter(b) ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Attendance history',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        const Text(
          'Choose a date to see every published subject attendance record.',
          style: TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 14),
        Card(
          elevation: 0,
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
            child: TableCalendar<Map<String, dynamic>>(
              firstDay: DateTime(earliest.year, earliest.month),
              lastDay: DateTime(latest.year, latest.month + 1, 0),
              focusedDay: _focusedAttendanceDay,
              calendarFormat: CalendarFormat.month,
              availableCalendarFormats: const {CalendarFormat.month: 'Month'},
              selectedDayPredicate: (day) =>
                  isSameDay(day, _selectedAttendanceDay),
              eventLoader: (day) => records.where((record) {
                final heldOn = DateTime.tryParse(
                  record['heldOn']?.toString() ?? '',
                );
                return heldOn != null && isSameDay(heldOn, day);
              }).toList(),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedAttendanceDay = selectedDay;
                  _focusedAttendanceDay = focusedDay;
                });
              },
              onPageChanged: (focusedDay) => _focusedAttendanceDay = focusedDay,
              headerStyle: const HeaderStyle(
                titleCentered: true,
                formatButtonVisible: false,
              ),
              calendarStyle: CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: AppColors.gateBlue.withValues(alpha: .18),
                  shape: BoxShape.circle,
                ),
                todayTextStyle: const TextStyle(color: AppColors.gateBlue),
                selectedDecoration: const BoxDecoration(
                  color: AppColors.gateBlue,
                  shape: BoxShape.circle,
                ),
                markerDecoration: const BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          DateFormat('EEEE, d MMMM yyyy').format(_selectedAttendanceDay),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        if (selectedRecords.isEmpty)
          _attendanceMessage(
            Icons.event_available_outlined,
            'No attendance on this date',
            'Select a date with an orange marker to view its subject records.',
          )
        else
          for (final record in selectedRecords) _attendanceHistoryCard(record),
      ],
    );
  }

  Widget _attendanceHistoryCard(Map<String, dynamic> record) {
    final status = record['status']?.toString() ?? 'unknown';
    final color = _attendanceStatusColor(status);
    final subject = record['subjectName']?.toString() ?? 'Subject';
    final code = record['subjectCode']?.toString() ?? '';
    final heldOn = DateTime.tryParse(record['heldOn']?.toString() ?? '');
    final period = record['periodLabel']?.toString() ?? 'Period not recorded';
    final time = _attendanceTimeRange(record);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        key: ValueKey('attendance-history-${record['sessionId']}'),
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showAttendanceDetails(record),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 54,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      heldOn == null ? '--' : DateFormat('dd').format(heldOn),
                      style: TextStyle(
                        color: color,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      heldOn == null
                          ? '---'
                          : DateFormat('MMM').format(heldOn).toUpperCase(),
                      style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subject,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (code.isNotEmpty)
                      Text(
                        code,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 11,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      time.isEmpty ? period : '$period  •  $time',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _attendanceStatusLabel(status),
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }

  void _showAttendanceDetails(Map<String, dynamic> record) {
    final heldOn = DateTime.tryParse(record['heldOn']?.toString() ?? '');
    final status = record['status']?.toString() ?? 'unknown';
    final color = _attendanceStatusColor(status);
    final duration = switch (record['durationMinutes']) {
      final num value when value > 0 => '${value.round()} minutes',
      _ => 'Not recorded',
    };
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      record['subjectName']?.toString() ?? 'Subject attendance',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _attendanceStatusLabel(status),
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _attendanceDetailRow(
                Icons.calendar_today_outlined,
                'Date',
                heldOn == null
                    ? 'Not recorded'
                    : DateFormat('d MMMM yyyy').format(heldOn),
              ),
              _attendanceDetailRow(
                Icons.today_outlined,
                'Day',
                heldOn == null
                    ? 'Not recorded'
                    : DateFormat('EEEE').format(heldOn),
              ),
              _attendanceDetailRow(
                Icons.menu_book_outlined,
                'Subject',
                _subjectDetail(record),
              ),
              _attendanceDetailRow(
                Icons.person_outline,
                'Staff',
                _valueOrFallback(record['facultyName']),
              ),
              _attendanceDetailRow(
                Icons.schedule_outlined,
                'Time',
                _attendanceTimeRange(record).isEmpty
                    ? 'Not recorded'
                    : _attendanceTimeRange(record),
              ),
              _attendanceDetailRow(
                Icons.timelapse_outlined,
                'Duration',
                duration,
              ),
              _attendanceDetailRow(
                Icons.view_timeline_outlined,
                'Period',
                _valueOrFallback(record['periodLabel']),
              ),
              if (_valueOrFallback(record['sectionName']) != 'Not recorded')
                _attendanceDetailRow(
                  Icons.groups_outlined,
                  'Class',
                  _valueOrFallback(record['sectionName']),
                ),
              if (_valueOrFallback(record['roomCode']) != 'Not recorded')
                _attendanceDetailRow(
                  Icons.meeting_room_outlined,
                  'Room',
                  _valueOrFallback(record['roomCode']),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _attendanceDetailRow(IconData icon, String label, String value) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 21, color: AppColors.gateBlue),
            const SizedBox(width: 12),
            SizedBox(
              width: 72,
              child: Text(
                label,
                style: const TextStyle(color: AppColors.muted),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );

  String _subjectDetail(Map<String, dynamic> record) {
    final name = _valueOrFallback(record['subjectName']);
    final code = record['subjectCode']?.toString().trim() ?? '';
    return code.isEmpty ? name : '$name ($code)';
  }

  String _valueOrFallback(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? 'Not recorded' : text;
  }

  String _attendanceTimeRange(Map<String, dynamic> record) {
    final start = _clockLabel(record['startsAt']);
    final end = _clockLabel(record['endsAt']);
    if (start.isEmpty || end.isEmpty) return '';
    return '$start – $end';
  }

  String _clockLabel(Object? value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return '';
    for (final pattern in const ['HH:mm:ss', 'HH:mm']) {
      try {
        return DateFormat('h:mm a').format(DateFormat(pattern).parse(raw));
      } catch (_) {
        // Try the next supported database time representation.
      }
    }
    return raw;
  }

  String _attendanceStatusLabel(String status) =>
      switch (status.toLowerCase()) {
        'present' => 'PRESENT',
        'absent' => 'ABSENT',
        'od' || 'on_duty' => 'ON DUTY',
        'leave' => 'LEAVE',
        _ => status.toUpperCase(),
      };

  Color _attendanceStatusColor(String status) => switch (status.toLowerCase()) {
    'present' => Colors.green,
    'absent' => Colors.red,
    'od' || 'on_duty' => const Color(0xFFB57900),
    'leave' => Colors.orange,
    _ => AppColors.muted,
  };

  Widget _marksResultsLink() => Card(
    elevation: 0,
    child: InkWell(
      key: const ValueKey('marks-results-link'),
      borderRadius: BorderRadius.circular(16),
      onTap: () => setState(() => _showMarksResults = true),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.deepPurple.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(
                Icons.assessment_outlined,
                color: Colors.deepPurple,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Marks and results',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _assessments.isEmpty
                        ? 'Semester, internal and other tests updated by your class advisor'
                        : '${_assessments.length} results · Semester, internal and other tests',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.muted),
          ],
        ),
      ),
    ),
  );

  Widget _marks() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'Marks and results',
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
      ),
      const SizedBox(height: 6),
      const Text(
        'Semester, internal and other tests updated by your class advisor',
        style: TextStyle(color: AppColors.muted),
      ),
      const SizedBox(height: 18),
      if (_loadingAssessments && _assessments.isEmpty)
        const Column(
          children: [
            SkeletonListRow(height: 112),
            SizedBox(height: 10),
            SkeletonListRow(height: 112),
            SizedBox(height: 10),
            SkeletonListRow(height: 112),
          ],
        )
      else if (_assessmentError != null && _assessments.isEmpty)
        _assessmentMessage(
          icon: Icons.cloud_off_outlined,
          title: 'Marks could not be loaded',
          subtitle: _assessmentError!,
          actionLabel: 'Try again',
          onAction: _loadAssessments,
        )
      else if (_assessments.isEmpty)
        _assessmentMessage(
          icon: Icons.assignment_outlined,
          title: 'No marks published yet',
          subtitle:
              'Marks entered by your class advisor will appear here automatically.',
          actionLabel: 'Refresh',
          onAction: _loadAssessments,
        )
      else ...[
        if (_loadingAssessments) const LinearProgressIndicator(minHeight: 2),
        for (final assessment in _assessments) _assessmentCard(assessment),
      ],
    ],
  );

  Widget _assessmentCard(StudentAssessment assessment) {
    final color = switch (assessment.kind) {
      StudentAssessmentKind.semester => const Color(0xFF4A4E9C),
      StudentAssessmentKind.internal => Colors.green,
      StudentAssessmentKind.test => Colors.deepPurple,
    };
    final icon = switch (assessment.kind) {
      StudentAssessmentKind.semester => Icons.school_outlined,
      StudentAssessmentKind.internal => Icons.fact_check_outlined,
      StudentAssessmentKind.test => Icons.assignment_outlined,
    };
    final kind = switch (assessment.kind) {
      StudentAssessmentKind.semester => 'Semester examination',
      StudentAssessmentKind.internal => 'Internal assessment',
      StudentAssessmentKind.test => 'Other test',
    };
    final semester = assessment.semester == null
        ? kind
        : '$kind  •  Semester ${assessment.semester}';
    final detail = assessment.subjectCode == null
        ? semester
        : '${assessment.subjectCode}  •  $semester';
    final score =
        '${_mark(assessment.marksObtained)} / ${_mark(assessment.maximumMarks)}';
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
                CircleAvatar(
                  backgroundColor: color.withValues(alpha: .12),
                  foregroundColor: color,
                  child: Icon(icon),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        assessment.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        detail,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  score,
                  style: TextStyle(
                    color: color,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            LinearProgressIndicator(
              value: assessment.percentage / 100,
              color: color,
              backgroundColor: color.withValues(alpha: .10),
              minHeight: 7,
              borderRadius: BorderRadius.circular(7),
            ),
            const SizedBox(height: 7),
            Text(
              '${_mark(assessment.percentage)}%',
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
            if (assessment.notes != null) ...[
              const SizedBox(height: 8),
              Text(
                assessment.notes!,
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _assessmentMessage({
    required IconData icon,
    required String title,
    required String subtitle,
    required String actionLabel,
    required VoidCallback onAction,
  }) => Card(
    elevation: 0,
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF4A4E9C), size: 34),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    ),
  );

  Widget _analysis() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'Academic analysis',
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
      ),
      const SizedBox(height: 6),
      const Text(
        'A quick view of your academic progress',
        style: TextStyle(color: AppColors.muted),
      ),
      const SizedBox(height: 18),
      Row(
        children: [
          Expanded(
            child: _summaryCard(
              'Current CGPA',
              '7.42',
              'Target: 8.00',
              const Color(0xFF4A4E9C),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _summaryCard(
              'Credits',
              '118',
              'of 160 completed',
              Colors.orange,
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'What needs attention',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 12),
              const ListTile(
                leading: Icon(
                  Icons.warning_amber_outlined,
                  color: Colors.orange,
                ),
                title: Text('Microwave Engineering attendance is below 75%'),
                contentPadding: EdgeInsets.zero,
              ),
              const ListTile(
                leading: Icon(Icons.trending_up_outlined, color: Colors.green),
                title: Text('Your CIA 2 average improved by 6%'),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
    ],
  );

  Widget _summaryCard(
    String title,
    String value,
    String subtitle,
    Color color,
  ) => Card(
    elevation: 0,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.school_outlined, color: color),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11, color: AppColors.muted),
          ),
        ],
      ),
    ),
  );
}

enum _WeeklyAttendanceStatus { present, absent, onDuty }
