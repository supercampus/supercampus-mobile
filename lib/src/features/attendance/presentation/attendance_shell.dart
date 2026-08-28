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
  Map<String, dynamic>? _summary;
  List<Map<String, dynamic>> _wards = const [];
  List<Map<String, dynamic>> _roster = const [];
  List<Map<String, dynamic>> _sessions = const [];
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
  bool get _isFaculty => !_isLearner && _scope == PermissionScope.section;

  /// Reporting is its own grant now, so reach no longer stands in for it.
  /// `reports` and `create` are the keys authz actually defines — there is no
  /// `attendance.reports.read`, so being able to raise one is what opens the
  /// list.
  bool get _canReport => widget.permissions.can(
    ModuleCatalog.attendance,
    'reports',
    ModuleActions.create,
  );

  /// Whether the report is a department's or the institution's is genuinely a
  /// question of reach, so this one stays scope-driven.
  bool get _isDepartment => _scope == PermissionScope.department;

  /// Publishing a report onward, as opposed to raising one.
  bool get _canRaiseReport => widget.permissions.can(
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
      } else if (_isFaculty) {
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
          _sessions = await widget.repository.sessions();
        } else {
          final values = await Future.wait([
            widget.repository.roster(
              sectionId: sectionId,
              sectionIds: sectionIds,
            ),
            widget.repository.sessions(),
          ]);
          _roster = values[0];
          _sessions = values[1];
          for (final student in _roster) {
            _marks.putIfAbsent(
              student['studentUserId'].toString(),
              () => 'present',
            );
          }
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
        _reports = await widget.repository.reports();
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
                  if (_isFaculty) ..._facultyView(),
                  if (_canReport)
                    KeyedSubtree(
                      key: _reportsKey,
                      child: Column(children: _reportView()),
                    ),
                ],
              ),
            ),
    );
  }

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
    ];
  }

  Widget _historyRow(Map<String, dynamic> session) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(Icons.check_circle, size: 16, color: theme.colorScheme.primary),
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
        ],
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
                      'Publish attendance',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Publish $absent absent, $onDuty on duty',
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
    const SizedBox(height: 14),
    Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.summarize_outlined,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isDepartment ? 'Department report' : 'Weekly report',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Review and submit this week\'s attendance summary',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (_canRaiseReport) ...[
            const SizedBox(width: 10),
            FilledButton.tonalIcon(
              onPressed: () async {
                final report = await widget.repository.createReport();
                await widget.repository.submitReport(report['id'].toString());
                await _load();
              },
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
              icon: const Icon(Icons.send_rounded, size: 18),
              label: const Text('Submit'),
            ),
          ],
        ],
      ),
    ),
    if (_reports.isNotEmpty) ...[
      const SizedBox(height: 18),
      Text(
        _isDepartment ? 'Department reports' : 'Recent reports',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 8),
    ],
    if (_reports.isEmpty)
      Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Text(
          'No reports submitted yet',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    for (final report in _reports)
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.assessment_outlined),
        title: Text(report['title']?.toString() ?? 'Attendance report'),
        subtitle: Text(
          '${report['periodStart'] ?? ''} to ${report['periodEnd'] ?? ''}',
        ),
        trailing: Text(report['status']?.toString() ?? ''),
      ),
  ];
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
