import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/user_facing_error.dart';
import '../../../core/widgets/module_navigation_buttons.dart';
import '../../authentication/data/auth_repository.dart';
import '../data/academic_models.dart';
import '../data/academic_structure_repository.dart';

/// Departments, programmes, classes and subjects as the institution runs
/// them. Everything shown here comes from the backend catalog that the
/// Student Master, attendance, timetable and notification pickers also read,
/// so a change made here shows up across the portal.
class AcademicManagementShell extends StatefulWidget {
  const AcademicManagementShell({
    super.key,
    required this.session,
    required this.onExitModule,
    this.repository,
    this.initialAction,
  });

  final UserSession session;
  final VoidCallback onExitModule;

  /// Null when the app runs without a backend: the page then says so
  /// instead of showing made-up programmes.
  final AcademicStructureRepository? repository;
  final String? initialAction;

  @override
  State<AcademicManagementShell> createState() =>
      _AcademicManagementShellState();
}

enum _Tab { programmes, subjects, classes }

class _AcademicManagementShellState extends State<AcademicManagementShell> {
  late _Tab _tab;
  AcademicCatalog? _catalog;
  Object? _error;
  bool _loading = false;
  bool _showInactive = false;

  /// Department filter for the Subjects and Classes lists; null is all.
  String? _departmentFilter;

  @override
  void initState() {
    super.initState();
    _tab = switch (widget.initialAction) {
      'subjects' => _Tab.subjects,
      'classes' => _Tab.classes,
      _ => _Tab.programmes,
    };
    _load();
  }

  Future<void> _load() async {
    final repository = widget.repository;
    if (repository == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final catalog = await repository.loadCatalog(
        includeInactive: _showInactive,
      );
      if (!mounted) return;
      setState(() => _catalog = catalog);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  AcademicStructureAccess get _access =>
      _catalog?.access ?? const AcademicStructureAccess();

  bool get _canCreateHere => switch (_tab) {
    _Tab.subjects => _access.createSubjects,
    _ => _access.createProgrammes,
  };

  bool get _canEditAnything =>
      _access.updateProgrammes || _access.updateSubjects;

  /// Runs a write, reloads the catalog and reports the outcome. Returns the
  /// error message, or null when it worked.
  Future<String?> _write(
    Future<void> Function(AcademicStructureRepository repository) change,
    String done,
  ) async {
    final repository = widget.repository;
    if (repository == null) return 'Connect to the campus server first.';
    try {
      await change(repository);
    } catch (error) {
      return userFacingError(error);
    }
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(done)));
    }
    return null;
  }

  Future<void> _openSheet(Widget sheet) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: context.palette.surfaceRaised,
    builder: (_) => sheet,
  );

  Future<void> _add() async {
    final catalog = _catalog;
    if (catalog == null) return;
    switch (_tab) {
      case _Tab.programmes:
        final choice = await showModalBottomSheet<String>(
          context: context,
          showDragHandle: true,
          backgroundColor: context.palette.surfaceRaised,
          builder: (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.school_outlined),
                  title: const Text('Programme'),
                  subtitle: const Text('A degree a department offers'),
                  enabled: catalog.activeDepartments.isNotEmpty,
                  onTap: () => Navigator.pop(context, 'programme'),
                ),
                ListTile(
                  leading: const Icon(Icons.account_tree_outlined),
                  title: const Text('Department'),
                  subtitle: const Text('Runs programmes and subjects'),
                  onTap: () => Navigator.pop(context, 'department'),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
        if (!mounted || choice == null) return;
        if (choice == 'department') {
          await _openSheet(_DepartmentSheet(onSave: _saveDepartment));
        } else {
          await _openSheet(
            _ProgrammeSheet(
              departments: catalog.activeDepartments,
              onSave: _saveProgramme,
            ),
          );
        }
      case _Tab.subjects:
        await _openSheet(
          _SubjectSheet(
            departments: catalog.activeDepartments,
            initialDepartmentId: _departmentFilter,
            onSave: _saveSubject,
          ),
        );
      case _Tab.classes:
        await _openSheet(
          _ClassSheet(
            programmes: catalog.activeProgrammes,
            onSave: _saveClass,
          ),
        );
    }
  }

  Future<String?> _saveDepartment(
    AcademicDepartment? existing,
    String code,
    String name, {
    bool? active,
  }) => _write(
    (repository) => existing == null
        ? repository.createDepartment(code: code, name: name)
        : repository.updateDepartment(
            existing.id,
            code: code,
            name: name,
            active: active,
          ),
    existing == null
        ? '$name was added.'
        : active == null
        ? '$name was updated.'
        : active
        ? '$name is active again.'
        : '$name was deactivated.',
  );

  Future<String?> _saveProgramme(
    AcademicProgramme? existing,
    String departmentId,
    String code,
    String name,
    int? durationTerms, {
    bool? active,
  }) => _write(
    (repository) => existing == null
        ? repository.createProgramme(
            departmentId: departmentId,
            code: code,
            name: name,
            durationTerms: durationTerms,
          )
        : repository.updateProgramme(
            existing.id,
            departmentId: departmentId,
            code: code,
            name: name,
            durationTerms: durationTerms,
            active: active,
          ),
    _doneMessage(name, existing == null, active),
  );

  Future<String?> _saveClass(
    AcademicClass? existing,
    String programmeId,
    int yearOfStudy,
    String sectionCode,
    int? capacity, {
    bool? active,
  }) => _write(
    (repository) => existing == null
        ? repository.createClass(
            programmeId: programmeId,
            yearOfStudy: yearOfStudy,
            sectionCode: sectionCode,
            capacity: capacity,
          )
        : repository.updateClass(
            existing.id,
            sectionCode: sectionCode,
            capacity: capacity,
            active: active,
          ),
    _doneMessage('Section $sectionCode', existing == null, active),
  );

  Future<String?> _saveSubject(
    AcademicSubject? existing,
    String departmentId,
    String code,
    String name,
    double? credits, {
    bool? active,
  }) => _write(
    (repository) => existing == null
        ? repository.createSubject(
            departmentId: departmentId,
            code: code,
            name: name,
            credits: credits,
          )
        : repository.updateSubject(
            existing.id,
            departmentId: departmentId,
            code: code,
            name: name,
            credits: credits,
            active: active,
          ),
    _doneMessage(name, existing == null, active),
  );

  static String _doneMessage(String name, bool created, bool? active) =>
      created
      ? '$name was added.'
      : active == null
      ? '$name was updated.'
      : active
      ? '$name is active again.'
      : '$name was deactivated.';

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final catalog = _catalog;
    return Scaffold(
      backgroundColor: palette.surfaceSunken,
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: palette.surfaceSunken,
        surfaceTintColor: Colors.transparent,
        leading: ModuleBackButton(onPressed: widget.onExitModule),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Academic Management'),
            if (catalog != null && catalog.academicYearName.isNotEmpty)
              Text(
                catalog.academicYearName,
                style: TextStyle(fontSize: 12, color: palette.inkSecondary),
              ),
          ],
        ),
        actions: [
          if (_canEditAnything)
            PopupMenuButton<String>(
              tooltip: 'More',
              onSelected: (_) {
                setState(() => _showInactive = !_showInactive);
                _load();
              },
              itemBuilder: (context) => [
                CheckedPopupMenuItem(
                  value: 'inactive',
                  checked: _showInactive,
                  child: const Text('Show inactive'),
                ),
              ],
            ),
          if (_canCreateHere)
            IconButton(
              key: const ValueKey('academic-add'),
              tooltip: 'Add',
              onPressed: _add,
              icon: const Icon(Icons.add_rounded),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<_Tab>(
                segments: const [
                  ButtonSegment(value: _Tab.programmes, label: Text('Programmes')),
                  ButtonSegment(value: _Tab.subjects, label: Text('Subjects')),
                  ButtonSegment(value: _Tab.classes, label: Text('Classes')),
                ],
                selected: {_tab},
                showSelectedIcon: false,
                onSelectionChanged: (value) =>
                    setState(() => _tab = value.first),
              ),
            ),
          ),
          if (_loading && catalog != null)
            const LinearProgressIndicator(minHeight: 2),
          Expanded(child: _body(context)),
        ],
      ),
    );
  }

  Widget _body(BuildContext context) {
    final catalog = _catalog;
    if (widget.repository == null) {
      return const _Message(
        icon: Icons.cloud_off_rounded,
        title: 'Not connected',
        body:
            'Academic structure is read from the campus server. Sign in '
            'against it to see and edit programmes, subjects and classes.',
      );
    }
    if (catalog == null) {
      if (_error != null) {
        return _Message(
          icon: Icons.error_outline_rounded,
          title: 'Could not load the academic structure',
          body: userFacingError(_error),
          action: FilledButton(onPressed: _load, child: const Text('Try again')),
        );
      }
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: switch (_tab) {
        _Tab.programmes => _programmesList(context, catalog),
        _Tab.subjects => _subjectsList(context, catalog),
        _Tab.classes => _classesList(context, catalog),
      },
    );
  }

  Widget _scroll(List<Widget> children) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
    children: children,
  );

  Widget _departmentFilterBar(AcademicCatalog catalog) {
    final departments = catalog.departments;
    if (departments.length < 2) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _FilterChip(
              label: 'All',
              selected: _departmentFilter == null,
              onTap: () => setState(() => _departmentFilter = null),
            ),
            for (final department in departments)
              _FilterChip(
                label: department.code,
                selected: _departmentFilter == department.id,
                onTap: () => setState(() => _departmentFilter = department.id),
              ),
          ],
        ),
      ),
    );
  }

  Widget _programmesList(BuildContext context, AcademicCatalog catalog) {
    if (catalog.departments.isEmpty) {
      return _scroll([
        const _EmptyGroup(
          text:
              'No departments yet. Add a department, then the programmes it '
              'offers.',
        ),
      ]);
    }
    return _scroll([
      if (catalog.unlinkedStudentCount > 0) ...[
        _Notice(
          text:
              '${catalog.unlinkedStudentCount} active '
              '${catalog.unlinkedStudentCount == 1 ? 'student is' : 'students are'} '
              'not linked to a department. Pick their programme in the '
              'Student directory.',
        ),
        const SizedBox(height: 16),
      ],
      for (final department in catalog.departments) ...[
        _Group(
          title: '${department.name} · ${department.code}',
          trailing: _access.updateProgrammes
              ? TextButton(
                  onPressed: () => _openSheet(
                    _DepartmentSheet(
                      department: department,
                      onSave: _saveDepartment,
                    ),
                  ),
                  child: const Text('Edit'),
                )
              : null,
          inactive: !department.active,
          rows: [
            for (final programme in catalog.programmes.where(
              (item) => item.departmentId == department.id,
            ))
              _Row(
                key: ValueKey('programme-${programme.id}'),
                icon: Icons.school_outlined,
                title: programme.name,
                subtitle: [
                  programme.code,
                  if (programme.durationLabel.isNotEmpty)
                    programme.durationLabel,
                ].join(' · '),
                trailing: _count(programme.studentCount, 'student'),
                active: programme.active,
                onTap: _access.updateProgrammes
                    ? () => _openSheet(
                        _ProgrammeSheet(
                          programme: programme,
                          departments: catalog.departments,
                          onSave: _saveProgramme,
                        ),
                      )
                    : null,
              ),
          ],
          empty: 'No programmes in this department yet.',
        ),
        const SizedBox(height: 20),
      ],
    ]);
  }

  Widget _subjectsList(BuildContext context, AcademicCatalog catalog) {
    final subjects = catalog.subjects
        .where(
          (item) =>
              _departmentFilter == null ||
              item.departmentId == _departmentFilter,
        )
        .toList();
    return _scroll([
      _departmentFilterBar(catalog),
      _Group(
        title: _departmentFilter == null
            ? 'All subjects'
            : '${catalog.departmentById(_departmentFilter)?.name ?? 'Department'} subjects',
        rows: [
          for (final subject in subjects)
            _Row(
              key: ValueKey('subject-${subject.id}'),
              icon: Icons.menu_book_outlined,
              title: subject.name,
              subtitle: [
                subject.code,
                if (_departmentFilter == null && subject.departmentCode.isNotEmpty)
                  subject.departmentCode,
              ].join(' · '),
              trailing: subject.creditsLabel,
              active: subject.active,
              onTap: _access.updateSubjects
                  ? () => _openSheet(
                      _SubjectSheet(
                        subject: subject,
                        departments: catalog.departments,
                        onSave: _saveSubject,
                      ),
                    )
                  : null,
            ),
        ],
        empty: 'No subjects yet.',
      ),
    ]);
  }

  Widget _classesList(BuildContext context, AcademicCatalog catalog) {
    final classes = catalog.classes
        .where(
          (item) =>
              _departmentFilter == null ||
              item.departmentId == _departmentFilter,
        )
        .toList();
    final byProgramme = <String, List<AcademicClass>>{};
    for (final item in classes) {
      byProgramme.putIfAbsent(item.programmeName, () => []).add(item);
    }
    return _scroll([
      _departmentFilterBar(catalog),
      if (byProgramme.isEmpty)
        const _EmptyGroup(
          text: 'No classes yet. Add a section for a programme and year.',
        ),
      for (final entry in byProgramme.entries) ...[
        _Group(
          title: entry.key,
          rows: [
            for (final item in entry.value)
              _Row(
                key: ValueKey('class-${item.id}'),
                icon: Icons.groups_outlined,
                title: [
                  if (item.yearOfStudy != null) 'Year ${item.yearOfStudy}',
                  'Section ${item.code}',
                ].join(' · '),
                subtitle: [
                  if (item.batchName.isNotEmpty) item.batchName,
                  if (item.capacity != null) 'Capacity ${item.capacity}',
                ].join(' · '),
                trailing: _count(item.studentCount, 'student'),
                active: item.active,
                onTap: _access.updateProgrammes
                    ? () => _openSheet(
                        _ClassSheet(
                          academicClass: item,
                          programmes: catalog.programmes,
                          onSave: _saveClass,
                        ),
                      )
                    : null,
              ),
          ],
          empty: '',
        ),
        const SizedBox(height: 20),
      ],
    ]);
  }

  static String _count(int value, String noun) =>
      '$value ${value == 1 ? noun : '${noun}s'}';
}

// ---------------------------------------------------------------------------
// Lists
// ---------------------------------------------------------------------------

class _Group extends StatelessWidget {
  const _Group({
    required this.title,
    required this.rows,
    required this.empty,
    this.trailing,
    this.inactive = false,
  });

  final String title;
  final List<Widget> rows;
  final String empty;
  final Widget? trailing;
  final bool inactive;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 4, 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                    color: palette.inkSecondary,
                  ),
                ),
              ),
              if (inactive) const _InactivePill(),
              ?trailing,
            ],
          ),
        ),
        if (rows.isEmpty && empty.isNotEmpty)
          _EmptyGroup(text: empty)
        else if (rows.isNotEmpty)
          Material(
            color: palette.surface,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      thickness: 0.5,
                      indent: 62,
                      color: palette.divider,
                    ),
                  rows[i],
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.active,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String trailing;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final ink = active ? palette.ink : palette.inkDisabled;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 11, 12, 11),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: active ? palette.brandSoft : palette.surfaceMuted,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                icon,
                size: 19,
                color: active ? palette.brandInk : palette.inkDisabled,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: ink,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: palette.inkSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (!active)
              const _InactivePill()
            else if (trailing.isNotEmpty)
              Text(
                trailing,
                style: TextStyle(fontSize: 13, color: palette.inkSecondary),
              ),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: palette.inkTertiary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InactivePill extends StatelessWidget {
  const _InactivePill();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: palette.surfaceMuted,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        'Inactive',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: palette.inkSecondary,
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onTap(),
    ),
  );
}

class _EmptyGroup extends StatelessWidget {
  const _EmptyGroup({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: context.palette.surface,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 14, color: context.palette.inkSecondary),
    ),
  );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.warningSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 20, color: palette.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, color: palette.ink),
            ),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: palette.inkTertiary),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.inkSecondary),
            ),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Edit sheets
// ---------------------------------------------------------------------------

/// Frame shared by every edit sheet: a title, the fields, an inline error,
/// Save, and (when editing) a deactivate / reactivate action.
class _SheetFrame extends StatelessWidget {
  const _SheetFrame({
    required this.title,
    required this.children,
    required this.saving,
    required this.error,
    required this.onSave,
    this.onToggleActive,
    this.active = true,
  });

  final String title;
  final List<Widget> children;
  final bool saving;
  final String? error;
  final VoidCallback onSave;
  final VoidCallback? onToggleActive;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            for (final child in children) ...[
              child,
              const SizedBox(height: 12),
            ],
            if (error != null) ...[
              Text(error!, style: TextStyle(color: palette.danger)),
              const SizedBox(height: 12),
            ],
            FilledButton(
              onPressed: saving ? null : onSave,
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
            if (onToggleActive != null) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: saving ? null : onToggleActive,
                style: TextButton.styleFrom(
                  foregroundColor: active ? palette.danger : palette.brandInk,
                ),
                child: Text(active ? 'Deactivate' : 'Reactivate'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Future<bool> _confirmDeactivate(BuildContext context, String name) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Deactivate $name?'),
        content: const Text(
          'It stops appearing in pickers across the portal. Records that '
          'already use it are kept, and you can reactivate it later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    ) ??
    false;

String? _required(String? value) =>
    value == null || value.trim().isEmpty ? 'Required' : null;

/// Mixin for the sheets' shared save / toggle flow.
mixin _SheetState<T extends StatefulWidget> on State<T> {
  final formKey = GlobalKey<FormState>();
  bool saving = false;
  String? error;

  Future<void> run(Future<String?> Function() action) async {
    setState(() {
      saving = true;
      error = null;
    });
    final failure = await action();
    if (!mounted) return;
    if (failure == null) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        saving = false;
        error = failure;
      });
    }
  }

  Future<void> toggle(String name, bool active, Future<String?> Function() action) async {
    if (active && !await _confirmDeactivate(context, name)) return;
    await run(action);
  }
}

typedef _DepartmentSave =
    Future<String?> Function(
      AcademicDepartment? existing,
      String code,
      String name, {
      bool? active,
    });

class _DepartmentSheet extends StatefulWidget {
  const _DepartmentSheet({required this.onSave, this.department});

  final AcademicDepartment? department;
  final _DepartmentSave onSave;

  @override
  State<_DepartmentSheet> createState() => _DepartmentSheetState();
}

class _DepartmentSheetState extends State<_DepartmentSheet>
    with _SheetState<_DepartmentSheet> {
  late final _code = TextEditingController(text: widget.department?.code);
  late final _name = TextEditingController(text: widget.department?.name);

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.department;
    return Form(
      key: formKey,
      child: _SheetFrame(
        title: existing == null ? 'New department' : 'Edit department',
        saving: saving,
        error: error,
        active: existing?.active ?? true,
        onSave: () {
          if (!formKey.currentState!.validate()) return;
          run(() => widget.onSave(existing, _code.text.trim(), _name.text.trim()));
        },
        onToggleActive: existing == null
            ? null
            : () => toggle(
                existing.name,
                existing.active,
                () => widget.onSave(
                  existing,
                  existing.code,
                  existing.name,
                  active: !existing.active,
                ),
              ),
        children: [
          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'Computer Science and Business Systems',
            ),
            validator: _required,
          ),
          TextFormField(
            controller: _code,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'Code', hintText: 'CSBS'),
            validator: _required,
          ),
        ],
      ),
    );
  }
}

typedef _ProgrammeSave =
    Future<String?> Function(
      AcademicProgramme? existing,
      String departmentId,
      String code,
      String name,
      int? durationTerms, {
      bool? active,
    });

class _ProgrammeSheet extends StatefulWidget {
  const _ProgrammeSheet({
    required this.departments,
    required this.onSave,
    this.programme,
  });

  final AcademicProgramme? programme;
  final List<AcademicDepartment> departments;
  final _ProgrammeSave onSave;

  @override
  State<_ProgrammeSheet> createState() => _ProgrammeSheetState();
}

class _ProgrammeSheetState extends State<_ProgrammeSheet>
    with _SheetState<_ProgrammeSheet> {
  late final _code = TextEditingController(text: widget.programme?.code);
  late final _name = TextEditingController(text: widget.programme?.name);
  late String? _departmentId =
      widget.programme?.departmentId ??
      (widget.departments.length == 1 ? widget.departments.first.id : null);
  late int? _years = widget.programme?.durationYears ?? 4;

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.programme;
    // Keep the saved semester count when the years did not change (a
    // 5-semester programme should not silently become 6).
    int? terms() => existing != null && _years == existing.durationYears
        ? existing.durationTerms
        : _years == null
        ? null
        : _years! * 2;
    return Form(
      key: formKey,
      child: _SheetFrame(
        title: existing == null ? 'New programme' : 'Edit programme',
        saving: saving,
        error: error,
        active: existing?.active ?? true,
        onSave: () {
          if (!formKey.currentState!.validate()) return;
          run(
            () => widget.onSave(
              existing,
              _departmentId!,
              _code.text.trim(),
              _name.text.trim(),
              terms(),
            ),
          );
        },
        onToggleActive: existing == null
            ? null
            : () => toggle(
                existing.name,
                existing.active,
                () => widget.onSave(
                  existing,
                  existing.departmentId,
                  existing.code,
                  existing.name,
                  existing.durationTerms,
                  active: !existing.active,
                ),
              ),
        children: [
          DropdownButtonFormField<String>(
            initialValue: _departmentId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Department'),
            items: [
              for (final department in widget.departments)
                DropdownMenuItem(
                  value: department.id,
                  child: Text(
                    '${department.name} (${department.code})',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            validator: (value) => value == null ? 'Choose a department' : null,
            onChanged: (value) => setState(() => _departmentId = value),
          ),
          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Programme name',
              hintText: 'B.E. Computer Science and Business Systems',
            ),
            validator: _required,
          ),
          TextFormField(
            controller: _code,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Code',
              hintText: 'BE-CSBS',
            ),
            validator: _required,
          ),
          DropdownButtonFormField<int>(
            initialValue: _years,
            decoration: const InputDecoration(labelText: 'Duration'),
            items: [
              for (var years = 1; years <= 6; years++)
                DropdownMenuItem(
                  value: years,
                  child: Text('$years ${years == 1 ? 'year' : 'years'}'),
                ),
            ],
            onChanged: (value) => setState(() => _years = value),
          ),
        ],
      ),
    );
  }
}

typedef _ClassSave =
    Future<String?> Function(
      AcademicClass? existing,
      String programmeId,
      int yearOfStudy,
      String sectionCode,
      int? capacity, {
      bool? active,
    });

class _ClassSheet extends StatefulWidget {
  const _ClassSheet({
    required this.programmes,
    required this.onSave,
    this.academicClass,
  });

  final AcademicClass? academicClass;
  final List<AcademicProgramme> programmes;
  final _ClassSave onSave;

  @override
  State<_ClassSheet> createState() => _ClassSheetState();
}

class _ClassSheetState extends State<_ClassSheet>
    with _SheetState<_ClassSheet> {
  late final _section = TextEditingController(
    text: widget.academicClass?.code,
  );
  late final _capacity = TextEditingController(
    text: widget.academicClass?.capacity?.toString() ?? '60',
  );
  late String? _programmeId =
      widget.academicClass?.programmeId ??
      (widget.programmes.length == 1 ? widget.programmes.first.id : null);
  late int _year = widget.academicClass?.yearOfStudy ?? 1;

  @override
  void dispose() {
    _section.dispose();
    _capacity.dispose();
    super.dispose();
  }

  int get _maxYear {
    for (final programme in widget.programmes) {
      if (programme.id == _programmeId) return programme.durationYears ?? 6;
    }
    return 6;
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.academicClass;
    final editing = existing != null;
    final maxYear = _maxYear.clamp(1, 8);
    if (_year > maxYear) _year = maxYear;
    int? capacity() => int.tryParse(_capacity.text.trim());
    return Form(
      key: formKey,
      child: _SheetFrame(
        title: editing ? 'Edit ${existing.label}' : 'New class',
        saving: saving,
        error: error,
        active: existing?.active ?? true,
        onSave: () {
          if (!formKey.currentState!.validate()) return;
          run(
            () => widget.onSave(
              existing,
              _programmeId!,
              _year,
              _section.text.trim(),
              capacity(),
            ),
          );
        },
        onToggleActive: existing == null
            ? null
            : () => toggle(
                existing.label,
                existing.active,
                () => widget.onSave(
                  existing,
                  existing.programmeId,
                  existing.yearOfStudy ?? 1,
                  existing.code,
                  existing.capacity,
                  active: !existing.active,
                ),
              ),
        children: [
          // Programme and year place the class in a yearly batch; moving a
          // class to another batch would move its students, so they are
          // fixed once the class exists.
          DropdownButtonFormField<String>(
            initialValue: _programmeId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Programme'),
            items: [
              for (final programme in widget.programmes)
                DropdownMenuItem(
                  value: programme.id,
                  child: Text(programme.name, overflow: TextOverflow.ellipsis),
                ),
            ],
            validator: (value) => value == null ? 'Choose a programme' : null,
            onChanged: editing
                ? null
                : (value) => setState(() => _programmeId = value),
          ),
          DropdownButtonFormField<int>(
            initialValue: _year,
            decoration: const InputDecoration(labelText: 'Year of study'),
            items: [
              for (var year = 1; year <= maxYear; year++)
                DropdownMenuItem(value: year, child: Text('Year $year')),
            ],
            onChanged: editing
                ? null
                : (value) => setState(() => _year = value ?? 1),
          ),
          TextFormField(
            controller: _section,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Section',
              hintText: 'A',
            ),
            validator: _required,
          ),
          TextFormField(
            controller: _capacity,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Capacity'),
            validator: (value) {
              final text = value?.trim() ?? '';
              if (text.isEmpty) return null;
              final number = int.tryParse(text);
              return number == null || number < 1 ? 'Enter a number' : null;
            },
          ),
        ],
      ),
    );
  }
}

typedef _SubjectSave =
    Future<String?> Function(
      AcademicSubject? existing,
      String departmentId,
      String code,
      String name,
      double? credits, {
      bool? active,
    });

class _SubjectSheet extends StatefulWidget {
  const _SubjectSheet({
    required this.departments,
    required this.onSave,
    this.subject,
    this.initialDepartmentId,
  });

  final AcademicSubject? subject;
  final List<AcademicDepartment> departments;
  final String? initialDepartmentId;
  final _SubjectSave onSave;

  @override
  State<_SubjectSheet> createState() => _SubjectSheetState();
}

class _SubjectSheetState extends State<_SubjectSheet>
    with _SheetState<_SubjectSheet> {
  late final _code = TextEditingController(text: widget.subject?.code);
  late final _name = TextEditingController(text: widget.subject?.name);
  late final _credits = TextEditingController(
    text: widget.subject?.credits == null
        ? ''
        : widget.subject!.creditsLabel.split(' ').first,
  );
  late String? _departmentId =
      widget.subject?.departmentId ??
      (widget.departments.any((item) => item.id == widget.initialDepartmentId)
          ? widget.initialDepartmentId
          : null);

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _credits.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.subject;
    double? credits() => double.tryParse(_credits.text.trim());
    return Form(
      key: formKey,
      child: _SheetFrame(
        title: existing == null ? 'New subject' : 'Edit subject',
        saving: saving,
        error: error,
        active: existing?.active ?? true,
        onSave: () {
          if (!formKey.currentState!.validate()) return;
          run(
            () => widget.onSave(
              existing,
              _departmentId!,
              _code.text.trim(),
              _name.text.trim(),
              credits(),
            ),
          );
        },
        onToggleActive: existing == null
            ? null
            : () => toggle(
                existing.name,
                existing.active,
                () => widget.onSave(
                  existing,
                  existing.departmentId,
                  existing.code,
                  existing.name,
                  existing.credits,
                  active: !existing.active,
                ),
              ),
        children: [
          DropdownButtonFormField<String>(
            initialValue: _departmentId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Department'),
            items: [
              for (final department in widget.departments)
                DropdownMenuItem(
                  value: department.id,
                  child: Text(
                    '${department.name} (${department.code})',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            validator: (value) => value == null ? 'Choose a department' : null,
            onChanged: (value) => setState(() => _departmentId = value),
          ),
          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Subject name',
              hintText: 'Data Structures',
            ),
            validator: _required,
          ),
          TextFormField(
            controller: _code,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Code',
              hintText: 'CS3301',
            ),
            validator: _required,
          ),
          TextFormField(
            controller: _credits,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Credits'),
            validator: (value) {
              final text = value?.trim() ?? '';
              if (text.isEmpty) return null;
              final number = double.tryParse(text);
              return number == null || number < 0 ? 'Enter a number' : null;
            },
          ),
        ],
      ),
    );
  }
}
