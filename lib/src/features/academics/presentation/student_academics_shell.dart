import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/widgets/module_navigation_buttons.dart';
import '../../../core/widgets/skeleton_loading.dart';

import '../../../core/access/module_catalog.dart';
import '../../../core/theme/app_theme.dart';
import '../../authentication/data/auth_repository.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../timetable/presentation/timetable_shell.dart';
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
    this.onOpenModule,
  });

  final UserSession session;
  final VoidCallback onExitModule;
  final String? initialAction;
  final StudentAssessmentsSource? assessmentsSource;
  final AttendanceRepository? attendanceRepository;
  final ValueChanged<String>? onOpenModule;

  @override
  State<StudentAcademicsShell> createState() => _StudentAcademicsShellState();
}

class _StudentAcademicsShellState extends State<StudentAcademicsShell> {
  final _attendanceKey = GlobalKey();
  final _marksKey = GlobalKey();
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
  DateTime? _selectedWeekMonday;

  DateTime get _activeWeekMonday {
    if (_selectedWeekMonday != null) return _selectedWeekMonday!;
    return _defaultWeekMonday();
  }

  DateTime _defaultWeekMonday() {
    final dated = <DateTime>[];
    for (final record in _attendanceRecords) {
      final heldOn = DateTime.tryParse(record['heldOn']?.toString() ?? '');
      if (heldOn != null) dated.add(heldOn);
    }
    final anchor = dated.isNotEmpty
        ? dated.reduce((current, next) => next.isAfter(current) ? next : current)
        : DateTime.now();
    return _mondayOfWeek(anchor);
  }

  DateTime _mondayOfWeek(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return d.subtract(Duration(days: d.weekday - DateTime.monday));
  }

  DateTime _firstMondayOfMonth(int year, int month) {
    DateTime d = DateTime(year, month, 1);
    while (d.weekday != DateTime.monday) {
      d = d.add(const Duration(days: 1));
    }
    return d;
  }

  DateTime _termStartMonday(DateTime reference) {
    DateTime? earliestRecordDate;
    for (final record in _attendanceRecords) {
      final heldOn = DateTime.tryParse(record['heldOn']?.toString() ?? '');
      if (heldOn != null) {
        if (earliestRecordDate == null || heldOn.isBefore(earliestRecordDate)) {
          earliestRecordDate = heldOn;
        }
      }
    }

    final year = reference.year;
    if (reference.month >= 7) {
      DateTime base = _firstMondayOfMonth(year, 8);
      if (earliestRecordDate != null &&
          earliestRecordDate.year == year &&
          earliestRecordDate.month == 7) {
        base = _firstMondayOfMonth(year, 7);
      }
      if (earliestRecordDate != null &&
          earliestRecordDate.year == year &&
          _mondayOfWeek(earliestRecordDate).isBefore(base)) {
        return _mondayOfWeek(earliestRecordDate);
      }
      return base;
    } else {
      final base = _firstMondayOfMonth(year, 1);
      if (earliestRecordDate != null &&
          earliestRecordDate.year == year &&
          _mondayOfWeek(earliestRecordDate).isBefore(base)) {
        return _mondayOfWeek(earliestRecordDate);
      }
      return base;
    }
  }

  int _weekNumberFor(DateTime monday) {
    final termStart = _termStartMonday(monday);
    final diffDays = monday.difference(termStart).inDays;
    final num = (diffDays / 7).round() + 1;
    return num < 1 ? 1 : (num > 30 ? 30 : num);
  }

  void _goToPreviousWeek() {
    setState(() {
      _selectedWeekMonday = _activeWeekMonday.subtract(const Duration(days: 7));
    });
  }

  void _goToNextWeek() {
    setState(() {
      _selectedWeekMonday = _activeWeekMonday.add(const Duration(days: 7));
    });
  }

  void _selectWeek(DateTime monday) {
    setState(() {
      _selectedWeekMonday = monday;
    });
  }

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
    final target = _attendanceKey.currentContext;
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
  Widget build(BuildContext context) => PopScope(
    canPop: !_showAttendanceHistory && !_showMarksResults,
    onPopInvokedWithResult: (didPop, _) {
      if (didPop) return;
      if (_showAttendanceHistory || _showMarksResults) {
        setState(() {
          _showAttendanceHistory = false;
          _showMarksResults = false;
        });
      }
    },
    child: Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        titleSpacing: 0,
        leading: ModuleBackButton(
          onPressed: _showAttendanceHistory || _showMarksResults
              ? () => setState(() {
                  _showAttendanceHistory = false;
                  _showMarksResults = false;
                })
              : widget.onExitModule,
        ),
        title: const Text(
          'Academics',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
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
          : RefreshIndicator(
              onRefresh: _refresh,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _timetableCard(),
                    const SizedBox(height: 12),
                    _attendanceHistoryLink(),
                    const SizedBox(height: 12),
                    KeyedSubtree(key: _marksKey, child: _marksResultsLink()),
                    const SizedBox(height: 20),
                    KeyedSubtree(key: _attendanceKey, child: _attendance()),
                  ],
                ),
              ),
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

  void _openTimetable() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TimetableShell(
          session: widget.session,
          scope: PermissionScope.own,
          canConfigure: false,
          onSignOut: () {},
          onExitModule: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  Widget _timetableCard() => Padding(
    padding: EdgeInsets.zero,
    child: Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
      ),
      elevation: 0,
      shadowColor: Colors.black.withValues(alpha: 0.04),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _openTimetable,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Class Timetable',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'Schedule',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF4F46E5),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'View weekly schedule & period timings',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: Color(0xFFF3F4F6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF6B7280),
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _attendance() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'Attendance (overall attendance)',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 4),
      const Text(
        'Overall attendance status and weekly schedule',
        style: TextStyle(color: AppColors.muted, fontSize: 13),
      ),
      const SizedBox(height: 14),
      if (_loadingAttendance && _attendanceSummary == null)
        const ThinkingOrbLoading(
          size: 96,
          padding: EdgeInsets.symmetric(vertical: 48),
        )
      else if (_attendanceError != null && _attendanceSummary == null)
        _attendanceMessage(
          Icons.cloud_off_outlined,
          'Attendance could not be loaded',
          _attendanceError!,
        )
      else ...[
        if (_loadingAttendance) const LinearProgressIndicator(minHeight: 2),
        _weekSelectorBar(),
        _overallAttendanceCard(),
        if (_count('totalClasses') == 0) ...[
          const SizedBox(height: 12),
          _attendanceMessage(
            Icons.fact_check_outlined,
            'No attendance published yet',
            'A subject appears here after its staff member publishes the roll.',
          ),
        ],
      ],
    ],
  );

  Widget _weekSelectorBar() {
    final monday = _activeWeekMonday;
    final friday = monday.add(const Duration(days: 4));
    final weekNum = _weekNumberFor(monday);
    final String dateRangeStr;
    if (monday.year != friday.year) {
      dateRangeStr =
          '${DateFormat('d MMM yyyy').format(monday)} – ${DateFormat('d MMM yyyy').format(friday)}';
    } else {
      dateRangeStr =
          '${DateFormat('d MMM').format(monday)} – ${DateFormat('d MMM yyyy').format(friday)}';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            key: const ValueKey('attendance-prev-week'),
            tooltip: 'Previous week',
            icon: const Icon(Icons.chevron_left_rounded, size: 22),
            onPressed: _goToPreviousWeek,
          ),
          Expanded(
            child: InkWell(
              key: const ValueKey('attendance-week-picker'),
              onTap: () => _openWeekPicker(context),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Week $weekNum',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 18,
                          color: AppColors.muted,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dateRangeStr,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            key: const ValueKey('attendance-next-week'),
            tooltip: 'Next week',
            icon: const Icon(Icons.chevron_right_rounded, size: 22),
            onPressed: _goToNextWeek,
          ),
        ],
      ),
    );
  }

  void _openWeekPicker(BuildContext context) {
    final currentActiveMonday = _activeWeekMonday;
    final termStart = _termStartMonday(currentActiveMonday);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Select Week',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.calendar_month_outlined, size: 18),
                      label: const Text('Pick Date'),
                      onPressed: () async {
                        Navigator.pop(sheetContext);
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: currentActiveMonday,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null) {
                          _selectWeek(_mondayOfWeek(picked));
                        }
                      },
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.55,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: 16,
                  itemBuilder: (itemCtx, index) {
                    final weekNum = index + 1;
                    final weekMon = termStart.add(Duration(days: index * 7));
                    final weekFri = weekMon.add(const Duration(days: 4));
                    final isSelected = isSameDay(weekMon, currentActiveMonday);
                    final isCurrent = isSameDay(
                      weekMon,
                      _mondayOfWeek(DateTime.now()),
                    );

                    final String label;
                    if (weekMon.year != weekFri.year) {
                      label =
                          '${DateFormat('d MMM yyyy').format(weekMon)} – ${DateFormat('d MMM yyyy').format(weekFri)}';
                    } else {
                      label =
                          '${DateFormat('d MMM').format(weekMon)} – ${DateFormat('d MMM yyyy').format(weekFri)}';
                    }

                    return ListTile(
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor: isSelected
                            ? AppColors.gateBlue
                            : isCurrent
                            ? AppColors.gateBlue.withValues(alpha: 0.15)
                            : Colors.grey.shade100,
                        child: Text(
                          '$weekNum',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? Colors.white
                                : isCurrent
                                ? AppColors.gateBlue
                                : const Color(0xFF374151),
                          ),
                        ),
                      ),
                      title: Row(
                        children: [
                          Text(
                            'Week $weekNum',
                            style: TextStyle(
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isSelected
                                  ? AppColors.gateBlue
                                  : Colors.black87,
                            ),
                          ),
                          if (isCurrent) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Current',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      subtitle: Text(
                        label,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(
                              Icons.check_circle_rounded,
                              color: AppColors.gateBlue,
                            )
                          : null,
                      onTap: () {
                        _selectWeek(weekMon);
                        Navigator.pop(sheetContext);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
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
    final monday = _activeWeekMonday;
    for (final (date, record) in dated) {
      final day = DateTime(
        date.year,
        date.month,
        date.day,
      ).difference(DateTime(monday.year, monday.month, monday.day)).inDays;
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
              firstDay: DateTime(DateTime.now().year - 10, 1, 1),
              lastDay: DateTime(DateTime.now().year + 10, 12, 31),
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
              onPageChanged: (focusedDay) {
                setState(() {
                  _focusedAttendanceDay = focusedDay;
                });
              },
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
        'Results are grouped by examination and listed subject-wise.',
        style: TextStyle(color: AppColors.muted),
      ),
      const SizedBox(height: 18),
      if (_loadingAssessments && _assessments.isEmpty)
        const ThinkingOrbLoading(
          size: 96,
          padding: EdgeInsets.symmetric(vertical: 48),
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
        for (final kind in StudentAssessmentKind.values)
          if (_assessments.any((assessment) => assessment.kind == kind))
            _assessmentGroup(
              kind,
              _assessments
                  .where((assessment) => assessment.kind == kind)
                  .toList(growable: false),
            ),
      ],
    ],
  );

  Color _assessmentColor(StudentAssessmentKind kind) => switch (kind) {
    StudentAssessmentKind.semester => const Color(0xFF4A4E9C),
    StudentAssessmentKind.internal => Colors.green,
    StudentAssessmentKind.test => Colors.deepPurple,
  };

  IconData _assessmentIcon(StudentAssessmentKind kind) => switch (kind) {
    StudentAssessmentKind.semester => Icons.school_outlined,
    StudentAssessmentKind.internal => Icons.fact_check_outlined,
    StudentAssessmentKind.test => Icons.assignment_outlined,
  };

  String _assessmentKindLabel(StudentAssessmentKind kind) => switch (kind) {
    StudentAssessmentKind.semester => 'Semester examinations',
    StudentAssessmentKind.internal => 'Internal assessments',
    StudentAssessmentKind.test => 'Other tests',
  };

  Widget _assessmentGroup(
    StudentAssessmentKind kind,
    List<StudentAssessment> assessments,
  ) {
    final color = _assessmentColor(kind);
    final icon = _assessmentIcon(kind);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            color: color.withValues(alpha: .08),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    _assessmentKindLabel(kind),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${assessments.length} ${assessments.length == 1 ? 'subject' : 'subjects'}',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          for (var index = 0; index < assessments.length; index++) ...[
            _assessmentSubjectRow(assessments[index], color),
            if (index != assessments.length - 1)
              const Divider(height: 1, indent: 14, endIndent: 14),
          ],
        ],
      ),
    );
  }

  Widget _assessmentSubjectRow(StudentAssessment assessment, Color color) {
    final kindLabel = switch (assessment.kind) {
      StudentAssessmentKind.semester => 'Semester examination',
      StudentAssessmentKind.internal => 'Internal assessment',
      StudentAssessmentKind.test => 'Other test',
    };
    final semester = assessment.semester == null
        ? kindLabel
        : '$kindLabel  •  Semester ${assessment.semester}';
    final detail = assessment.subjectCode == null
        ? semester
        : '${assessment.subjectCode}  •  $semester';
    final score =
        '${_mark(assessment.marksObtained)} / ${_mark(assessment.maximumMarks)}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      assessment.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    score,
                    style: TextStyle(
                      color: color,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${_mark(assessment.percentage)}%',
                    style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 9),
          LinearProgressIndicator(
            value: assessment.percentage / 100,
            color: color,
            backgroundColor: color.withValues(alpha: .10),
            minHeight: 4,
            borderRadius: BorderRadius.circular(4),
          ),
          if (assessment.notes != null) ...[
            const SizedBox(height: 6),
            Text(
              assessment.notes!,
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ],
        ],
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

}

enum _WeeklyAttendanceStatus { present, absent, onDuty }
