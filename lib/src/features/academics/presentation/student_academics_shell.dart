import 'package:flutter/material.dart';

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
  List<StudentAssessment> _assessments = const [];
  bool _loadingAssessments = false;
  String? _assessmentError;
  Map<String, dynamic>? _attendanceSummary;
  bool _loadingAttendance = false;
  String? _attendanceError;

  @override
  void initState() {
    super.initState();
    _loadAssessments();
    _loadAttendance();
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
      setState(() => _attendanceSummary = summary);
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
      backgroundColor: const Color(0xFF4A4E9C),
      foregroundColor: Colors.white,
      leading: ModuleBackButton(
        onPressed: widget.onExitModule,
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
    body: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _attendance(),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),
          _marks(),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),
          _analysis(),
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

  List<Map<String, dynamic>> get _subjects {
    final value = _attendanceSummary?['bySubject'];
    if (value is! List) return const [];
    return value.whereType<Map>().map((item) {
      return item.map((key, value) => MapEntry(key.toString(), value));
    }).toList();
  }

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
        const SizedBox(height: 10),
        for (final subject in _subjects) _subjectAttendanceCard(subject),
      ],
    ],
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

  Widget _subjectAttendanceCard(Map<String, dynamic> subject) {
    int count(String key) => switch (subject[key]) {
      final int value => value,
      final num value => value.round(),
      _ => 0,
    };
    final percentage = _number(subject['percentage']);
    final color = percentage < 75 ? Colors.orange : Colors.green;
    final code = subject['subjectCode']?.toString() ?? '';
    final name = subject['subjectName']?.toString() ?? 'Subject';
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (code.isNotEmpty)
                        Text(
                          code,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.muted,
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  '${percentage.round()}%',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: (percentage / 100).clamp(0, 1),
              color: color,
              backgroundColor: color.withValues(alpha: .12),
              minHeight: 8,
              borderRadius: BorderRadius.circular(8),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 5,
              children: [
                _statusCount('Present', count('presentClasses'), Colors.green),
                _statusCount('Absent', count('absentClasses'), Colors.red),
                _statusCount(
                  'OD',
                  count('onDutyClasses'),
                  const Color(0xFFFFD600),
                ),
                _statusCount('Leave', count('leaveClasses'), Colors.orange),
              ],
            ),
          ],
        ),
      ),
    );
  }

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

  Widget _statusCount(String label, int value, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 4),
      Text(
        '$value $label',
        style: const TextStyle(fontSize: 11, color: AppColors.muted),
      ),
    ],
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
                        semester,
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
