import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/access/academic_presentation.dart';
import '../../../core/access/effective_permissions.dart';
import '../../../core/access/module_catalog.dart';
import '../../../core/motion/app_motion.dart';
import '../../../core/motion/app_springs.dart';
import '../../../core/widgets/module_navigation_buttons.dart';
import '../../../core/widgets/skeleton_loading.dart';

import '../../authentication/data/auth_repository.dart';
import '../data/attendance_repository.dart';
import '../services/attendance_report_exporter.dart';
import 'attendance_class_picker.dart';
import 'attendance_roster_row.dart';

class AttendanceShell extends StatefulWidget {
  const AttendanceShell({
    super.key,
    required this.session,
    required this.permissions,
    required this.onExitModule,
    required this.repository,
    this.initialTimetableEntryId,
    this.initialSubjectOfferingId,
    this.initialSectionId,
    this.initialSubjectName,
    this.initialPeriodLabel,
    this.openSelectedClassImmediately = false,
    this.initialAction,
  });

  final UserSession session;

  /// What this person may do decides which of the three attendance workspaces
  /// they get. Their role name has no bearing on it.
  final EffectivePermissions permissions;
  final VoidCallback onExitModule;
  final AttendanceRepository repository;
  final String? initialTimetableEntryId;
  final String? initialSubjectOfferingId;
  final String? initialSectionId;
  final String? initialSubjectName;
  final String? initialPeriodLabel;

  /// A class card is already a class choice. When it opens Attendance there is
  /// no reason to ask the teacher to choose or resume the same class again.
  /// Opening Attendance from the module list leaves this false and keeps the
  /// overview/class switcher available.
  final bool openSelectedClassImmediately;
  final String? initialAction;

  @override
  State<AttendanceShell> createState() => _AttendanceShellState();
}

class _AttendanceShellState extends State<AttendanceShell> {
  static const _exporter = AttendanceReportExporter();
  Map<String, dynamic>? _summary;
  List<Map<String, dynamic>> _wards = const [];
  List<Map<String, dynamic>> _roster = const [];
  List<Map<String, dynamic>> _sessions = const [];
  List<Map<String, dynamic>> _departments = const [];
  List<Map<String, dynamic>> _reports = const [];
  List<Map<String, dynamic>> _classes = const [];
  final Map<String, String> _marks = {};
  Map<String, dynamic>? _selectedClass;
  bool _choosingClass = false;
  String? _selectedWard;
  String? _activeSession;
  String? _error;
  bool _busy = true;
  Timer? _timer;
  bool _openedInitialClass = false;
  bool _appliedInitialAction = false;
  final _reportsKey = GlobalKey();

  /// Scope is what separates the three workspaces: your own record, the
  /// sections you teach, or the department and above that you report on.
  PermissionScope get _scope =>
      widget.permissions.scopeFor(ModuleCatalog.attendance);

  bool get _isLearner =>
      academicPresentationFor(widget.permissions) ==
      AcademicPresentation.learner;
  bool get _canTakeAttendance =>
      !_isLearner &&
      widget.permissions.can(
        ModuleCatalog.attendance,
        'session',
        ModuleActions.create,
      );

  Set<String> get _roles => {
    widget.session.roleKey.toLowerCase(),
    ...widget.session.roleIds.map((role) => role.toLowerCase()),
  };

  /// Reporting is its own grant now, so reach no longer stands in for it.
  /// `reports` and `create` are the keys authz actually defines — there is no
  /// `attendance.reports.read`, so being able to raise one is what opens the
  /// list.
  bool get _canReport =>
      widget.permissions.can(
        ModuleCatalog.attendance,
        'reports',
        ModuleActions.create,
      ) ||
      widget.permissions.can(
        ModuleCatalog.attendance,
        'reports',
        ModuleActions.publish,
      );

  /// Guardians are not a role — they are accounts that have wards. Asking the
  /// data is both truthful and self-correcting: an account with no wards never
  /// sees the picker, whatever anyone calls it.
  bool get _hasWards => _wards.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _load(silent: true),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() {
        _busy = true;
        _error = null;
      });
    }
    try {
      if (_isLearner) {
        // Whose record this is depends on what the account holds, not on what
        // it is called. Wards first: an account that has them is a guardian and
        // reads a ward's attendance; one that has none reads its own.
        try {
          _wards = await widget.repository.wards();
        } on Exception {
          _wards = const [];
        }
        if (_wards.isNotEmpty) {
          _selectedWard ??= _wards.first['studentUserId']?.toString();
        }
        _summary = await widget.repository.summary(_selectedWard ?? 'me');
      } else if (_canTakeAttendance) {
        // A section belongs to a student, not to a teacher: `session.sectionId`
        // is empty for staff, and asking for a roster without one is rejected.
        // The classes have to be looked up, and which class is being marked is
        // then a choice the teacher makes.
        if (_classes.isEmpty) {
          _classes = await widget.repository.teachingClasses();
        }
        _selectedClass ??= _initialClass(_classes);
        final sectionId = _selectedClass?['sectionId']?.toString();
        final sectionIds =
            (_selectedClass?['sectionIds'] as List?)
                ?.map((value) => value.toString())
                .where((value) => value.isNotEmpty)
                .toList() ??
            const <String>[];
        if (sectionId == null || sectionId.isEmpty) {
          _roster = const [];
          _acceptReviewWorkspace(await widget.repository.reviewWorkspace());
        } else {
          final values = await Future.wait([
            widget.repository.roster(
              sectionId: sectionId,
              sectionIds: sectionIds,
            ),
            widget.repository.reviewWorkspace(),
          ]);
          _roster = values[0] as List<Map<String, dynamic>>;
          _acceptReviewWorkspace(values[1] as Map<String, dynamic>);
          for (final student in _roster) {
            _marks.putIfAbsent(
              student['studentUserId'].toString(),
              () => 'present',
            );
          }
        }
        if (_canReport) {
          _reports = await widget.repository.reports();
        }

        if (widget.openSelectedClassImmediately && !_openedInitialClass) {
          _openedInitialClass = true;
          final draft = _draftForSelectedClass();
          if (draft != null) {
            _activeSession = draft['id']?.toString();
          } else {
            final chosen = _selectedClass;
            if (chosen != null) {
              final now = TimeOfDay.fromDateTime(DateTime.now());
              final created = await widget.repository.createSession(
                timetableEntryId: chosen['timetableEntryId']?.toString() ?? '',
                subjectName: chosen['subjectName']?.toString() ?? 'Class',
                periodLabel:
                    chosen['periodLabel']?.toString().isNotEmpty == true
                    ? chosen['periodLabel'].toString()
                    : '${now.hour.toString().padLeft(2, '0')}:'
                          '${now.minute.toString().padLeft(2, '0')}',
              );
              _activeSession = created['id']?.toString();
            }
          }
          for (final student in _roster) {
            _marks[student['studentUserId'].toString()] =
                AttendanceMark.present.wire;
          }
        }
      } else {
        final values = await Future.wait([
          widget.repository.reviewWorkspace(),
          widget.repository.reports(),
        ]);
        _acceptReviewWorkspace(values[0] as Map<String, dynamic>);
        _reports = values[1] as List<Map<String, dynamic>>;
      }
      if (mounted) {
        setState(() {
          _busy = false;
          _error = null;
          if (!_appliedInitialAction && widget.initialAction == 'roster') {
            _choosingClass = true;
          }
        });
        _applyInitialAction();
      }
    } catch (error) {
      if (mounted && !silent) {
        setState(() {
          _busy = false;
          _error = error is AttendanceException
              ? error.message
              : 'Attendance is unavailable.';
        });
      }
    }
  }

  void _acceptReviewWorkspace(Map<String, dynamic> workspace) {
    _sessions = (workspace['sessions'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
    _departments = (workspace['departments'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  void _applyInitialAction() {
    if (_appliedInitialAction) return;
    _appliedInitialAction = true;
    if (widget.initialAction != 'reports') return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _reportsKey.currentContext;
      if (mounted && target != null) {
        Scrollable.ensureVisible(target, duration: Duration.zero, alignment: 0);
      }
    });
  }

  Map<String, dynamic>? _initialClass(List<Map<String, dynamic>> classes) {
    if (classes.isEmpty) return null;

    bool same(String key, String? expected) =>
        expected != null &&
        expected.isNotEmpty &&
        classes.any((value) => value[key]?.toString() == expected);

    final timetableEntryId = widget.initialTimetableEntryId;
    if (same('timetableEntryId', timetableEntryId)) {
      return classes.firstWhere(
        (value) => value['timetableEntryId']?.toString() == timetableEntryId,
      );
    }

    final exact = classes.where((value) {
      bool matches(String key, String? expected) =>
          expected == null ||
          expected.isEmpty ||
          value[key]?.toString() == expected;
      return matches('subjectOfferingId', widget.initialSubjectOfferingId) &&
          matches('sectionId', widget.initialSectionId) &&
          matches('subjectName', widget.initialSubjectName) &&
          matches('periodLabel', widget.initialPeriodLabel);
    });
    return exact.isEmpty ? classes.first : exact.first;
  }

  /// Switching class throws away marks that were never published — they belong
  /// to the roster that is being left behind, and carrying them across would
  /// silently mark the wrong students.
  void _selectClass(Map<String, dynamic> value) {
    setState(() {
      _selectedClass = value;
      _choosingClass = false;
      _activeSession = null;
      _roster = const [];
      _marks.clear();
    });
    _load();
  }

  Future<void> _startSession() async {
    final chosen = _selectedClass;
    if (chosen == null) return;
    final now = TimeOfDay.fromDateTime(DateTime.now());
    final created = await widget.repository.createSession(
      timetableEntryId: chosen['timetableEntryId']?.toString() ?? '',
      subjectName: chosen['subjectName']?.toString() ?? 'Class',
      periodLabel: chosen['periodLabel']?.toString().isNotEmpty == true
          ? chosen['periodLabel'].toString()
          : '${now.hour.toString().padLeft(2, '0')}:'
                '${now.minute.toString().padLeft(2, '0')}',
    );
    setState(() => _activeSession = created['id']?.toString());
  }

  /// Picks an interrupted roll back up. The marks are not recovered — entries
  /// only reach the server on publish — so it reopens at all-present, which is
  /// where a fresh roll starts anyway.
  void _resumeSession(String sessionId) {
    setState(() {
      _activeSession = sessionId;
      _marks.clear();
      for (final student in _roster) {
        _marks[student['studentUserId'].toString()] =
            AttendanceMark.present.wire;
      }
    });
  }

  Future<void> _publish() async {
    final sessionId = _activeSession;
    if (sessionId == null) return;
    setState(() => _busy = true);
    try {
      await widget.repository.saveEntries(sessionId, [
        for (final student in _roster)
          {
            'studentUserId': student['studentUserId'].toString(),
            'studentName': student['studentName']?.toString() ?? 'Student',
            'status': _marks[student['studentUserId'].toString()] ?? 'present',
          },
      ]);
      await widget.repository.publish(sessionId);
      _activeSession = null;
      await _load();
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error is AttendanceException
              ? error.message
              : 'Could not publish attendance.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: ModuleBackButton(onPressed: widget.onExitModule),
        title: const Text('Attendance'),
        actions: [
          IconButton(
            onPressed: _load,
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
          ),
          ModuleHomeButton(onPressed: widget.onExitModule),
        ],
      ),
      body: _busy && _summary == null && _roster.isEmpty && _reports.isEmpty
          ? const AttendanceLoadingSkeleton()
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                // The application shell floats its navigation bar over module
                // content. Keep the final attendance actions completely above
                // it instead of letting the report button collide with it.
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
                children: [
                  if (_error != null) _ErrorBanner(_error!),
                  if (_isLearner) ..._summaryView(),
                  // A timetable card is an explicit request to work on one
                  // class. Do not prepend the advisor/HOD review inbox here;
                  // that queue remains available from the Attendance module.
                  if (_canReport && !_isFocusedClassLaunch)
                    KeyedSubtree(
                      key: _reportsKey,
                      child: Column(children: _reportView()),
                    ),
                  if (_canTakeAttendance) ..._facultyView(),
                ],
              ),
            ),
    );
  }

  bool get _isFocusedClassLaunch =>
      widget.openSelectedClassImmediately && _selectedClass != null;

  List<Widget> _summaryView() {
    final summary = _summary ?? const <String, dynamic>{};
    final records = (summary['records'] as List? ?? const [])
        .whereType<Map<String, dynamic>>();
    return [
      if (_hasWards)
        DropdownButtonFormField<String>(
          initialValue: _selectedWard,
          decoration: const InputDecoration(labelText: 'Student'),
          items: [
            for (final ward in _wards)
              DropdownMenuItem(
                value: ward['studentUserId'].toString(),
                child: Text(ward['studentName']?.toString() ?? 'Student'),
              ),
          ],
          onChanged: (value) {
            setState(() => _selectedWard = value);
            _load();
          },
        ),
      const SizedBox(height: 16),
      Row(
        children: [
          _Metric(label: 'Attendance', value: '${summary['percentage'] ?? 0}%'),
          _Metric(
            label: 'Attended',
            value: '${summary['attendedClasses'] ?? 0}',
          ),
          _Metric(label: 'Absent', value: '${summary['absences'] ?? 0}'),
        ],
      ),
      const SizedBox(height: 24),
      Text('Attendance records', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      if (records.isEmpty)
        const ListTile(title: Text('No published attendance yet')),
      for (final record in records)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            record['status'] == 'present'
                ? Icons.check_circle
                : Icons.cancel_outlined,
          ),
          title: Text(record['subjectName']?.toString() ?? 'Class'),
          subtitle: Text(
            '${record['heldOn'] ?? ''}  ${record['periodLabel'] ?? ''}',
          ),
          trailing: Text(record['status']?.toString().toUpperCase() ?? ''),
        ),
    ];
  }

  List<Widget> _facultyView() {
    if (_classes.isEmpty) {
      return [ClassesEmptyState(busy: _busy)];
    }

    final chosen = _selectedClass;
    final marking = _activeSession != null;

    return [
      // Which class is being marked is the first question this screen has to
      // answer, so it is the first thing on it — and it stays visible while
      // marking, because a roster with no class above it is a roster of nobody
      // in particular.
      ClassHeader(
        chosen: chosen,
        count: _classes.length,
        expanded: _choosingClass,
        // Changing class mid-roll would discard marks, so it is refused while
        // a session is open rather than silently dropping them.
        onToggle: marking
            ? null
            : () => setState(() => _choosingClass = !_choosingClass),
      ),
      AnimatedSize(
        duration: prefersReducedMotion(context)
            ? Duration.zero
            : AppMotion.standard,
        curve: AppMotion.curve,
        alignment: Alignment.topCenter,
        child: _choosingClass && !marking
            ? Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  children: [
                    for (final option in _classes)
                      ClassOption(
                        option: option,
                        selected:
                            option['id']?.toString() ==
                            chosen?['id']?.toString(),
                        onTap: () => _selectClass(option),
                      ),
                  ],
                ),
              )
            : const SizedBox(width: double.infinity),
      ),
      const SizedBox(height: 18),
      _attendanceApprovalCard(),
      const SizedBox(height: 18),
      if (marking) ..._markingView() else ..._idleView(),
    ];
  }

  /// Before a roll is open: one obvious thing to do, and what was done before.
  List<Widget> _idleView() {
    final theme = Theme.of(context);
    final draft = _draftForSelectedClass();
    final history = _publishedSessions();

    return [
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: _selectedClass == null
              ? null
              : (draft == null
                    ? _startSession
                    : () => _resumeSession(draft['id'].toString())),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          icon: Icon(
            draft == null ? Icons.play_arrow_rounded : Icons.edit_outlined,
          ),
          label: Text(
            draft == null ? 'Start attendance' : 'Resume unfinished roll',
          ),
        ),
      ),
      if (draft != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            'Started ${_timeOf(draft)} and not published yet',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      const SizedBox(height: 26),
      Text(
        'Recent rolls',
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          letterSpacing: 0.2,
        ),
      ),
      const SizedBox(height: 8),
      if (history.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            'Nothing published yet',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        )
      else
        // Five is a glance. The full history belongs behind the module, not on
        // the screen someone opened to take a roll.
        ...history.take(5).map(_historyRow),
      if (history.isNotEmpty)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const ValueKey('attendance-full-history'),
            onPressed: _showAttendanceHistory,
            icon: const Icon(Icons.history_rounded),
            label: Text(
              'View all attendance history (${_publishedSessionsAll().length})',
            ),
          ),
        ),
    ];
  }

  Future<void> _showAttendanceHistory() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      final history = _publishedSessionsAll();
      return SafeArea(
        child: FractionallySizedBox(
          heightFactor: .82,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Attendance history',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${history.length} submitted records across assigned classes',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: history.isEmpty
                    ? const Center(child: Text('No attendance history yet'))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                        itemCount: history.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final session = history[index];
                          return ListTile(
                            leading: const Icon(Icons.fact_check_outlined),
                            title: Text(
                              session['subjectName']?.toString() ?? 'Class',
                            ),
                            subtitle: Text(
                              '${session['heldOn'] ?? ''} · ${session['periodLabel'] ?? ''}',
                            ),
                            trailing: _AttendanceStatusChip(
                              status: session['status']?.toString() ?? '',
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              Future<void>.delayed(
                                Duration.zero,
                                () => _showPresentStudents(session),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      );
    },
  );

  Widget _historyRow(Map<String, dynamic> session) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _showPresentStudents(session),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Row(
          children: [
            Icon(
              Icons.check_circle,
              size: 16,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                session['subjectName']?.toString() ?? 'Class',
                style: theme.textTheme.bodyMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '${session['heldOn'] ?? ''}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded, size: 18),
          ],
        ),
      ),
    );
  }

  /// With a roll open the screen is the roll and nothing else.
  List<Widget> _markingView() {
    final theme = Theme.of(context);
    if (_roster.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text(
            'No students are enrolled in this section',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ];
    }

    int countOf(AttendanceMark mark) => _roster
        .where(
          (student) =>
              AttendanceMark.fromWire(
                _marks[student['studentUserId'].toString()],
              ) ==
              mark,
        )
        .length;

    final absent = countOf(AttendanceMark.absent);
    final onDuty = countOf(AttendanceMark.onDuty);

    return [
      RollTally(
        present: countOf(AttendanceMark.present),
        absent: absent,
        onDuty: onDuty,
        onReset: absent + onDuty == 0
            ? null
            : () => setState(() {
                for (final student in _roster) {
                  _marks[student['studentUserId'].toString()] =
                      AttendanceMark.present.wire;
                }
              }),
      ),
      const SizedBox(height: 10),
      ..._roster.map((student) {
        final id = student['studentUserId'].toString();
        return AttendanceRosterRow(
          key: ValueKey(id),
          name: student['studentName']?.toString() ?? 'Student',
          number: student['studentNumber']?.toString() ?? '',
          programme: student['programmeName']?.toString(),
          department: student['departmentCode']?.toString(),
          photoUrl: student['photoUrl']?.toString(),
          mark: AttendanceMark.fromWire(_marks[id]),
          onMark: (value) => setState(() => _marks[id] = value.wire),
        );
      }),
      const SizedBox(height: 16),
      SizedBox(
        width: double.infinity,
        child: FilledButton(
          key: const ValueKey('submit-attendance-for-review'),
          onPressed: _publish,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.publish_rounded),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Submit attendance',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _roles.contains('class_advisor')
                          ? 'Send $absent absent, $onDuty on duty to HOD'
                          : 'Send $absent absent, $onDuty on duty to class advisor',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onPrimary.withValues(
                          alpha: 0.78,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_rounded),
            ],
          ),
        ),
      ),
    ];
  }

  /// An unpublished roll for the class in front of the teacher. A draft is an
  /// interrupted roll, so it is offered back rather than listed as history.
  Map<String, dynamic>? _draftForSelectedClass() {
    for (final session in _sessions) {
      if (session['status']?.toString() == 'draft' &&
          _sessionMatchesSelectedClass(session)) {
        return session;
      }
    }
    return null;
  }

  List<Map<String, dynamic>> _publishedSessions() => [
    for (final session in _sessions)
      if (session['status']?.toString() != 'draft' &&
          _sessionMatchesSelectedClass(session))
        session,
  ];

  List<Map<String, dynamic>> _publishedSessionsAll() => [
    for (final session in _sessions)
      if (!{'draft', 'returned'}.contains(session['status']?.toString()))
        session,
  ];

  Widget _attendanceApprovalCard() {
    final status = _publishedSessions().isEmpty
        ? 'draft'
        : _publishedSessions().first['status']?.toString() ?? 'draft';
    const steps = ['Class advisor', 'HOD', 'Principal'];
    final current = switch (status) {
      'submitted_to_advisor' => 0,
      'published_to_hod' || 'submitted_to_hod' => 1,
      'submitted_to_principal' => 2,
      'approved' => 3,
      _ => -1,
    };
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Submission matrix',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Faculty submits once. Each reviewer receives only their scoped queue.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          for (var index = 0; index < steps.length; index++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 13,
                    backgroundColor: index <= current
                        ? colors.primary
                        : colors.surfaceContainerHighest,
                    foregroundColor: index <= current
                        ? colors.onPrimary
                        : colors.onSurfaceVariant,
                    child: index < current
                        ? const Icon(Icons.check, size: 15)
                        : Text(
                            '${index + 1}',
                            style: const TextStyle(fontSize: 10),
                          ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(steps[index])),
                  Text(
                    index < current
                        ? 'Approved'
                        : index == current
                        ? 'Pending'
                        : 'Next',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  bool _sessionMatchesSelectedClass(Map<String, dynamic> session) {
    final chosen = _selectedClass;
    if (chosen == null ||
        session['subjectName']?.toString() !=
            chosen['subjectName']?.toString()) {
      return false;
    }

    bool matchesIdentityWhenPresent(String key) {
      final actual = session[key]?.toString() ?? '';
      if (actual.isEmpty) return true;
      return chosen[key]?.toString() == actual;
    }

    if (!matchesIdentityWhenPresent('subjectOfferingId') ||
        !matchesIdentityWhenPresent('sectionId')) {
      return false;
    }

    // Older sessions did not persist offering/section identity. Subject is the
    // only safe compatibility key for those records; current sessions carry
    // identity, and then period separates repeated meetings of the same class.
    final hasIdentity =
        (session['subjectOfferingId']?.toString() ?? '').isNotEmpty ||
        (session['sectionId']?.toString() ?? '').isNotEmpty;
    if (!hasIdentity) return true;
    final period = session['periodLabel']?.toString() ?? '';
    return period.isEmpty || period == chosen['periodLabel']?.toString();
  }

  String _timeOf(Map<String, dynamic> session) =>
      session['periodLabel']?.toString() ?? 'earlier';

  List<Widget> _reportView() => [
    const SizedBox(height: 4),
    _reviewHero(),
    const SizedBox(height: 16),
    if (_reviewSessions().isEmpty)
      Card(
        child: ListTile(
          leading: const Icon(Icons.inbox_outlined),
          title: Text(
            _roles.contains('principal')
                ? 'No attendance received yet'
                : 'No attendance waiting for review',
          ),
          subtitle: Text(
            _roles.contains('principal')
                ? 'Attendance sent by HODs will remain available here.'
                : 'New submissions will appear here automatically.',
          ),
        ),
      ),
    ..._reviewSessionCards(),
    if (_canTakeAttendance) ...[
      const SizedBox(height: 18),
      const Divider(),
      const SizedBox(height: 10),
      Text(
        'Take attendance for your hour',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 4),
      Text(
        'Your assigned timetable classes are below.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ],
  ];

  Widget _reviewHero() {
    final colors = Theme.of(context).colorScheme;
    final sessions = _reviewSessions();
    final pending = sessions.where(_canReviewSession).length;
    final departments = sessions
        .map((session) => session['departmentCode']?.toString() ?? '')
        .where((code) => code.isNotEmpty)
        .toSet()
        .length;
    final secondaryLabel = _roles.contains('principal')
        ? 'Departments'
        : 'Completed';
    final secondaryValue = _roles.contains('principal')
        ? departments
        : sessions.length - pending;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.primary,
            Color.lerp(colors.primary, Colors.black, .28)!,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: .22),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: colors.onPrimary.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  _roles.contains('principal')
                      ? Icons.account_balance_rounded
                      : Icons.fact_check_rounded,
                  color: colors.onPrimary,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _reviewWorkspaceTitle(),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: colors.onPrimary,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _reviewWorkspaceSubtitle(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onPrimary.withValues(alpha: .8),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _ReviewHeroMetric(
                value: '${sessions.length}',
                label: _roles.contains('principal') ? 'Received' : 'Reports',
              ),
              const SizedBox(width: 10),
              _ReviewHeroMetric(
                value: '$secondaryValue',
                label: secondaryLabel,
              ),
              if (!_roles.contains('principal')) ...[
                const SizedBox(width: 10),
                _ReviewHeroMetric(value: '$pending', label: 'Action needed'),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _reviewWorkspaceTitle() {
    if (_roles.contains('principal')) return 'Principal attendance records';
    if (_roles.contains('hod')) return 'Department attendance review';
    return 'Class advisor review queue';
  }

  String _reviewWorkspaceSubtitle() {
    if (_roles.contains('principal')) {
      return '${_reviewScopeLabel()} · Final attendance received from HODs.';
    }
    if (_roles.contains('hod')) {
      return '${_reviewScopeLabel()} · Review pending attendance and view submission history.';
    }
    return '${_reviewScopeLabel()} · Review attendance by subject and department.';
  }

  List<Widget> _reviewSessionCards() {
    final sessions = [..._reviewSessions()]
      ..sort((a, b) {
        final pendingA = _canReviewSession(a) ? 0 : 1;
        final pendingB = _canReviewSession(b) ? 0 : 1;
        if (pendingA != pendingB) return pendingA.compareTo(pendingB);
        final department = (a['departmentCode'] ?? '').toString();
        return department.compareTo((b['departmentCode'] ?? '').toString());
      });
    final grouped = _roles.contains('principal') || _roles.contains('hod');
    if (grouped && _departments.isNotEmpty) {
      final widgets = <Widget>[];
      final orderedDepartments = [..._departments]
        ..sort((a, b) {
          bool hasReports(Map<String, dynamic> department) {
            final code = department['code']?.toString() ?? '';
            return sessions.any(
              (session) => session['departmentCode']?.toString() == code,
            );
          }

          final reportOrder = (hasReports(b) ? 1 : 0).compareTo(
            hasReports(a) ? 1 : 0,
          );
          if (reportOrder != 0) return reportOrder;
          return (a['code']?.toString() ?? '').compareTo(
            b['code']?.toString() ?? '',
          );
        });
      for (final department in orderedDepartments) {
        final code = department['code']?.toString() ?? 'Department';
        final name = department['name']?.toString() ?? code;
        final departmentSessions = sessions
            .where((session) => session['departmentCode']?.toString() == code)
            .toList(growable: false);
        widgets.add(
          _departmentHeading(code, name, count: departmentSessions.length),
        );
        if (departmentSessions.isEmpty) {
          widgets.add(
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: const ListTile(
                leading: Icon(Icons.inbox_outlined),
                title: Text('No attendance submitted'),
                subtitle: Text('No class attendance has reached this queue.'),
              ),
            ),
          );
        } else {
          widgets.addAll(departmentSessions.map(_sessionReviewCard));
        }
      }
      return widgets;
    }
    final widgets = <Widget>[];
    String? previousDepartment;
    for (final session in sessions) {
      final department = (session['departmentCode'] ?? 'Department').toString();
      if ((_roles.contains('principal') || _roles.contains('hod')) &&
          department != previousDepartment) {
        widgets.add(
          _departmentHeading(
            department,
            session['departmentName']?.toString() ?? department,
          ),
        );
        previousDepartment = department;
      }
      widgets.add(_sessionReviewCard(session));
    }
    return widgets;
  }

  Widget _departmentHeading(String code, String name, {int? count}) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 16, 2, 8),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              Icons.apartment_rounded,
              size: 19,
              color: colors.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  code,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.primary,
                  ),
                ),
                if (code != name)
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          if (count != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$count ${count == 1 ? 'report' : 'reports'}',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
        ],
      ),
    );
  }

  Widget _sessionReviewCard(Map<String, dynamic> session) {
    final colors = Theme.of(context).colorScheme;
    final pending = _canReviewSession(session);
    final accent = pending ? colors.tertiary : colors.primary;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: .18)),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: .07),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('attendance-review-${session['id']}'),
          borderRadius: BorderRadius.circular(18),
          onTap: () => _showPresentStudents(session),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 12, 13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(
                        pending
                            ? Icons.pending_actions_rounded
                            : Icons.fact_check_outlined,
                        color: accent,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            session['subjectName']?.toString() ?? 'Class',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            '${session['heldOn'] ?? ''} · ${session['periodLabel'] ?? ''}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    _AttendanceStatusChip(
                      status: session['status']?.toString() ?? '',
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: colors.onSurfaceVariant,
                      size: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    _AttendanceCountChip(
                      label: 'Present',
                      value: _count(session['presentCount']),
                      color: const Color(0xFF16845B),
                    ),
                    _AttendanceCountChip(
                      label: 'Absent',
                      value: _count(session['absentCount']),
                      color: const Color(0xFFC63C35),
                    ),
                    _AttendanceCountChip(
                      label: 'OD',
                      value: _count(session['onDutyCount']),
                      color: const Color(0xFF8A6500),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  int _count(dynamic value) => switch (value) {
    int number => number,
    num number => number.toInt(),
    _ => int.tryParse(value?.toString() ?? '') ?? 0,
  };

  List<Map<String, dynamic>> _reviewSessions() => [
    for (final session in _sessions)
      if (_isVisibleReviewSession(session)) session,
  ];

  bool _isVisibleReviewSession(Map<String, dynamic> session) {
    final status = session['status']?.toString();
    if (_roles.contains('principal')) {
      return const {'submitted_to_principal', 'approved'}.contains(status);
    }
    if (_roles.contains('hod')) {
      return const {
        'submitted_to_hod',
        'submitted_to_principal',
        'approved',
      }.contains(status);
    }
    return _roles.contains('class_advisor') && status == 'submitted_to_advisor';
  }

  bool _canReviewSession(Map<String, dynamic> session) {
    final status = session['status']?.toString();
    if (_roles.contains('principal')) return false;
    if (_roles.contains('hod')) {
      return status == 'submitted_to_hod';
    }
    if (_roles.contains('class_advisor')) {
      return status == 'submitted_to_advisor';
    }
    return false;
  }

  Future<void> _review(Map<String, dynamic> session, String decision) async {
    final id = session['id']?.toString() ?? '';
    if (id.isEmpty) return;
    String? note;
    if (decision != 'approve') {
      final controller = TextEditingController();
      note = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            decision == 'enquire'
                ? 'Request clarification'
                : 'Reject attendance',
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Reason',
              hintText: 'Explain what must be corrected',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Send'),
            ),
          ],
        ),
      );
      controller.dispose();
      if (note == null || note.isEmpty) return;
    }
    try {
      await widget.repository.reviewSession(id, decision: decision, note: note);
      if (mounted) Navigator.of(context).pop();
      await _load();
    } on AttendanceException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  String _reviewScopeLabel() {
    final roles = {
      widget.session.roleKey.toLowerCase(),
      widget.session.roleLabel.toLowerCase(),
      ...widget.session.roleIds.map((role) => role.toLowerCase()),
    }.join(' ');
    if (roles.contains('principal')) return 'Institution view';
    if (roles.contains('hod') || _scope == PermissionScope.department) {
      return 'Department view';
    }
    return 'Assigned-class view';
  }

  Future<void> _showPresentStudents(Map<String, dynamic> session) async {
    final sessionId = session['id']?.toString() ?? '';
    if (sessionId.isEmpty) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: .82,
        child: FutureBuilder<Map<String, dynamic>>(
          future: widget.repository.sessionRoster(sessionId),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Could not load this attendance roster.'),
                ),
              );
            }

            final entries = (snapshot.data?['entries'] as List? ?? const [])
                .whereType<Map<String, dynamic>>()
                .toList(growable: false);
            final present = entries
                .where((entry) => entry['status']?.toString() == 'present')
                .toList(growable: false);
            final absent = entries
                .where((entry) => entry['status']?.toString() == 'absent')
                .toList(growable: false);
            final onDuty = entries
                .where((entry) => entry['status']?.toString() == 'od')
                .toList(growable: false);

            return SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primaryContainer.withValues(alpha: .55),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: Icon(
                                Icons.groups_2_rounded,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                session['subjectName']?.toString() ?? 'Class',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today_outlined, size: 15),
                            const SizedBox(width: 6),
                            Text(
                              '${session['heldOn'] ?? ''} · ${session['periodLabel'] ?? ''}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${present.length} present · ${absent.length} absent · ${onDuty.length} OD',
                          key: const ValueKey('present-student-count'),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 10),
                        _AttendanceExportControl(
                          onPdf: () => _exporter.savePdf(session, entries),
                          onCsv: () => _exporter.saveCsv(session, entries),
                          onXlsx: () => _exporter.saveXlsx(session, entries),
                        ),
                        if (_canReviewSession(session)) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _review(session, 'enquire'),
                                  icon: const Icon(Icons.help_outline_rounded),
                                  label: const Text('Enquire'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: () => _review(session, 'approve'),
                                  icon: const Icon(Icons.check_rounded),
                                  label: const Text('Approve & send'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  Expanded(
                    child: entries.isEmpty
                        ? const Center(
                            child: Text('No attendance entries were submitted'),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(12, 2, 12, 24),
                            itemCount: entries.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 7),
                            itemBuilder: (context, index) {
                              final student = entries[index];
                              final number = student['studentNumber']
                                  ?.toString();
                              final status =
                                  student['status']?.toString() ?? 'absent';
                              final color = _attendanceStatusColor(status);
                              return Container(
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: color.withValues(alpha: .2),
                                  ),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 3,
                                  ),
                                  leading: _StudentAttendanceAvatar(
                                    name:
                                        student['studentName']?.toString() ??
                                        'Student',
                                    photoUrl: student['photoUrl']?.toString(),
                                    status: status,
                                  ),
                                  title: Text(
                                    student['studentName']?.toString() ??
                                        'Student',
                                  ),
                                  subtitle: number == null || number.isEmpty
                                      ? null
                                      : Text(number),
                                  trailing: _EntryAttendanceStatus(status),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AttendanceStatusChip extends StatelessWidget {
  const _AttendanceStatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      'submitted_to_advisor' => 'With advisor',
      'published_to_hod' || 'submitted_to_hod' => 'With HOD',
      'submitted_to_principal' => 'Received by principal',
      'approved' => 'Approved',
      'returned' => 'Returned',
      _ => status.replaceAll('_', ' '),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}

class _ReviewHeroMetric extends StatelessWidget {
  const _ReviewHeroMetric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
        decoration: BoxDecoration(
          color: colors.onPrimary.withValues(alpha: .13),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.onPrimary.withValues(alpha: .12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: colors.onPrimary,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colors.onPrimary.withValues(alpha: .75),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _AttendanceExportFormat { pdf, csv, xlsx }

class _AttendanceExportControl extends StatefulWidget {
  const _AttendanceExportControl({
    required this.onPdf,
    required this.onCsv,
    required this.onXlsx,
  });

  final Future<void> Function() onPdf;
  final Future<void> Function() onCsv;
  final Future<void> Function() onXlsx;

  @override
  State<_AttendanceExportControl> createState() =>
      _AttendanceExportControlState();
}

class _AttendanceExportControlState extends State<_AttendanceExportControl> {
  _AttendanceExportFormat _format = _AttendanceExportFormat.pdf;
  bool _downloading = false;

  Future<void> _download() async {
    if (_downloading) return;
    setState(() => _downloading = true);
    try {
      await switch (_format) {
        _AttendanceExportFormat.pdf => widget.onPdf(),
        _AttendanceExportFormat.csv => widget.onCsv(),
        _AttendanceExportFormat.xlsx => widget.onXlsx(),
      };
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<_AttendanceExportFormat>(
            key: const ValueKey('attendance-export-format'),
            initialValue: _format,
            isExpanded: true,
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            decoration: InputDecoration(
              labelText: 'File format',
              filled: true,
              fillColor: colors.surface.withValues(alpha: .72),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: colors.outlineVariant),
              ),
            ),
            items: const [
              DropdownMenuItem(
                value: _AttendanceExportFormat.pdf,
                child: Text('PDF'),
              ),
              DropdownMenuItem(
                value: _AttendanceExportFormat.csv,
                child: Text('CSV'),
              ),
              DropdownMenuItem(
                value: _AttendanceExportFormat.xlsx,
                child: Text('Excel / XLSX'),
              ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _format = value);
            },
          ),
        ),
        const SizedBox(width: 10),
        FilledButton.icon(
          key: const ValueKey('download-attendance-report'),
          onPressed: _downloading ? null : _download,
          style: FilledButton.styleFrom(
            minimumSize: const Size(128, 54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          icon: _downloading
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download_rounded, size: 20),
          label: const Text('Download'),
        ),
      ],
    );
  }
}

class _AttendanceCountChip extends StatelessWidget {
  const _AttendanceCountChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      '$label $value',
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: color,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

Color _attendanceStatusColor(String status) => switch (status) {
  'present' => const Color(0xFF16845B),
  'od' => const Color(0xFF8A6500),
  'leave' => const Color(0xFF5F5A70),
  _ => const Color(0xFFC63C35),
};

class _StudentAttendanceAvatar extends StatelessWidget {
  const _StudentAttendanceAvatar({
    required this.name,
    required this.photoUrl,
    required this.status,
  });

  final String name;
  final String? photoUrl;
  final String status;

  String get _initials {
    final parts = name.split(RegExp(r'\s+')).where((part) => part.isNotEmpty);
    if (parts.isEmpty) return '?';
    return parts.take(2).map((part) => part[0]).join().toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final url = photoUrl?.trim() ?? '';
    final colors = Theme.of(context).colorScheme;
    final statusColor = _attendanceStatusColor(status);
    final fallback = Container(
      color: colors.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Text(
        _initials,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: colors.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    return Semantics(
      image: true,
      label: '$name student photo',
      child: Container(
        width: 48,
        height: 48,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: statusColor, width: 2),
        ),
        child: ClipOval(
          child: url.isEmpty
              ? fallback
              : Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => fallback,
                ),
        ),
      ),
    );
  }
}

class _EntryAttendanceStatus extends StatelessWidget {
  const _EntryAttendanceStatus(this.status);

  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'present' => ('PRESENT', const Color(0xFF16845B)),
      'od' => ('OD', const Color(0xFF8A6500)),
      'leave' => ('LEAVE', const Color(0xFF5F5A70)),
      _ => ('ABSENT', const Color(0xFFC63C35)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          Text(value, style: Theme.of(context).textTheme.headlineMedium),
          Text(label),
        ],
      ),
    ),
  );
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.errorContainer,
    child: Padding(padding: const EdgeInsets.all(12), child: Text(message)),
  );
}
