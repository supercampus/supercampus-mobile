import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/media/media_scope.dart';
import '../../../core/media/media_picker.dart';
import '../../../core/widgets/module_section_switcher.dart';
import '../../../core/widgets/announcement_composer.dart';
import '../../../core/widgets/announcement_image_cropper.dart';
import '../../library/data/librarian_repository.dart';
import '../../maintenance/data/maintenance_repository.dart';
import '../data/admin_student_repository.dart';
import '../../academics/data/academic_models.dart';
import '../../academics/presentation/academic_programme_field.dart';
import 'admin_student_directory.dart';
import 'admin_users_page.dart';
import 'admin_roles_page.dart';
import '../data/admin_roles_repository.dart';
import '../../../core/access/effective_permissions.dart';
import '../../../core/utils/user_facing_error.dart';

/// Focused admin surface for student management and pending approvals.
class AdminPortalShell extends StatefulWidget {
  const AdminPortalShell({
    super.key,
    required this.libraryRepository,
    required this.studentRepository,
    required this.maintenanceRepository,
    this.initialSection = 0,
    this.onExitModule,
    this.currentUserEmail,
    this.permissions,
    this.rolesRepository,
  });

  final LibrarianRepository libraryRepository;
  final AdminStudentRepository studentRepository;
  final MaintenanceRepository maintenanceRepository;
  final int initialSection;
  final VoidCallback? onExitModule;

  /// The signed-in administrator; their own account cannot be deactivated.
  final String? currentUserEmail;

  /// The signed-in user's effective permissions. Delete and the Roles
  /// section are offered only when these grant them.
  final EffectivePermissions? permissions;

  /// Role management; the Roles section appears when this is set and the
  /// user may read roles.
  final AdminRolesRepository? rolesRepository;

  /// Index of the Roles section (it follows the four fixed sections).
  static const rolesSection = 4;

  @override
  State<AdminPortalShell> createState() => _AdminPortalShellState();
}

class _AdminPortalShellState extends State<AdminPortalShell> {
  late int _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialSection.clamp(0, _showsRoles ? 4 : 3);
  }

  bool _can(String feature, String action) =>
      widget.permissions?.can('authorization', feature, action) ?? false;

  bool get _showsRoles =>
      widget.rolesRepository != null && _can('roles', 'read');

  @override
  Widget build(BuildContext context) {
    final rolesRepository = widget.rolesRepository;
    final showsRoles = _showsRoles;
    final pages = [
      AdminUsersPage(
        repository: widget.studentRepository,
        currentUserEmail: widget.currentUserEmail,
        canDelete: _can('users', 'delete'),
      ),
      AdminStudentsPage(repository: widget.studentRepository),
      _AdminAnnouncementsPage(repository: widget.libraryRepository),
      _AdminMaintenancePage(repository: widget.maintenanceRepository),
      if (showsRoles && rolesRepository != null)
        AdminRolesPage(
          repository: rolesRepository,
          canCreate: _can('roles', 'create'),
          canUpdate: _can('roles', 'update'),
          canDelete: _can('roles', 'delete'),
        ),
    ];
    final selected = _selected.clamp(0, pages.length - 1);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: widget.onExitModule != null
          ? AppBar(
              titleSpacing: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: widget.onExitModule,
                tooltip: 'Back to Admin Portal',
              ),
              title: const Text('Admin Console'),
              centerTitle: false,
              elevation: 0,
            )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            ModuleSectionSwitcher(
              sections: [
                const ModuleSection(
                  label: 'Users',
                  icon: Icons.manage_accounts_outlined,
                ),
                const ModuleSection(
                  label: 'Students',
                  icon: Icons.school_outlined,
                ),
                const ModuleSection(
                  label: 'Announcements',
                  icon: Icons.campaign_outlined,
                ),
                const ModuleSection(
                  label: 'Maintenance',
                  icon: Icons.construction_rounded,
                ),
                if (showsRoles)
                  const ModuleSection(
                    label: 'Roles',
                    icon: Icons.admin_panel_settings_outlined,
                  ),
              ],
              selectedIndex: selected,
              onSelected: (value) => setState(() => _selected = value),
            ),
            Expanded(
              child: IndexedStack(index: selected, children: pages),
            ),
          ],
        ),
      ),
    );
  }
}

/// Student Master for administrators: browse, filter and edit students.
class AdminStudentsPage extends StatefulWidget {
  const AdminStudentsPage({super.key, required this.repository});
  final AdminStudentRepository repository;

  @override
  State<AdminStudentsPage> createState() => _AdminStudentsPageState();
}

class _AdminStudentsPageState extends State<AdminStudentsPage> {
  List<ManagedStudent>? _students;
  String? _error;
  String? _savingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final students = await widget.repository.listStudents();
      if (mounted) setState(() => _students = students);
    } catch (error) {
      if (mounted) setState(() => _error = userFacingError(error));
    }
  }

  Future<void> _change(
    ManagedStudent student,
    ManagedStudentResidency residency,
  ) async {
    if (_savingId != null || student.residency == residency) return;
    setState(() => _savingId = student.id);
    try {
      final saved = await widget.repository.setResidency(student.id, residency);
      if (!mounted) return;
      setState(() {
        _students = [
          for (final item in _students ?? const <ManagedStudent>[])
            if (item.id == student.id)
              item.copyWith(residency: saved)
            else
              item,
        ];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${student.name} changed to ${saved.label}.')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userFacingError(error))));
      }
    } finally {
      if (mounted) setState(() => _savingId = null);
    }
  }

  Future<void> _edit(ManagedStudent student) async {
    final availableDepts = (_students ?? const <ManagedStudent>[])
        .map((s) => s.department.trim())
        .where((d) => d.isNotEmpty)
        .toSet()
        .toList();
    final saved = await showModalBottomSheet<ManagedStudent>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _EditStudentSheet(
        student: student,
        repository: widget.repository,
        availableDepartments: availableDepts,
      ),
    );
    if (saved == null || !mounted) return;
    setState(() {
      _students = [
        for (final item in _students ?? const <ManagedStudent>[])
          if (item.id == saved.id) saved else item,
      ];
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${saved.name} was updated.')));
  }

  void _showStudentProfile(ManagedStudent student) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => _StudentProfileSheet(
        student: student,
        onEdit: () {
          Navigator.pop(sheetContext);
          _edit(student);
        },
        onChangeResidency: (residency) {
          Navigator.pop(sheetContext);
          _change(student, residency);
        },
        onSetPhoto: () async {
          Navigator.pop(sheetContext);
          final asset = await pickAndUploadPhoto(
            context,
            repository: MediaScope.of(context),
          );
          if (asset == null || !mounted) return;
          try {
            await widget.repository.setStudentPhoto(
              student.id,
              asset.secureUrl,
            );
            await _load();
          } catch (error) {
            if (mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(userFacingError(error))));
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final students = _students;
    return Scaffold(
      body: _error != null && students == null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            )
          : students == null
          ? const Center(child: CircularProgressIndicator())
          : StudentDirectoryView(
              students: students,
              busyStudentId: _savingId,
              onOpen: _showStudentProfile,
              onEdit: (student) {
                if (_savingId == null) _edit(student);
              },
              onRefresh: _load,
            ),
    );
  }
}


class ParsedDepartment {
  const ParsedDepartment({required this.programme, required this.course});
  final String programme;
  final String course;
}

ParsedDepartment parseDepartmentAndProgramme(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return const ParsedDepartment(
      programme: 'B.Tech',
      course: 'Artificial Intelligence & Data Science',
    );
  }

  String prog = '';
  String coursePart = trimmed;
  if (trimmed.toLowerCase().contains(' in ')) {
    final idx = trimmed.toLowerCase().indexOf(' in ');
    prog = trimmed.substring(0, idx).trim();
    coursePart = trimmed.substring(idx + 4).trim();
  }

  // Normalize programme
  final progUpper = prog.toUpperCase().replaceAll('.', '').replaceAll(' ', '');
  String normalizedProg;
  if (progUpper == 'BE') {
    normalizedProg = 'B.E';
  } else if (progUpper == 'BTECH') {
    normalizedProg = 'B.Tech';
  } else if (progUpper == 'ME') {
    normalizedProg = 'M.E';
  } else if (progUpper == 'MTECH') {
    normalizedProg = 'M.Tech';
  } else if (progUpper == 'MBA') {
    normalizedProg = 'MBA';
  } else if (progUpper == 'MCA') {
    normalizedProg = 'MCA';
  } else {
    normalizedProg = prog.isNotEmpty ? prog : '';
  }

  // Match coursePart against known courses or fuzzy match
  final courseUpper = coursePart.toUpperCase();
  String normalizedCourse;

  if (courseUpper.contains('ARTIFICIAL INTELLIGENCE') &&
      (courseUpper.contains('MACHINE') || courseUpper.contains('AIML'))) {
    normalizedCourse =
        'Computer Science & Engineering (Artificial Intelligence & Machine Learning)';
    if (normalizedProg.isEmpty) normalizedProg = 'B.E';
  } else if (courseUpper.contains('ARTIFICIAL INTELLIGENCE') ||
      courseUpper.contains('DATA SCIENCE') ||
      courseUpper.contains('AIDS')) {
    normalizedCourse = 'Artificial Intelligence & Data Science';
    if (normalizedProg.isEmpty) normalizedProg = 'B.Tech';
  } else if (courseUpper.contains('CYBER')) {
    normalizedCourse =
        'Computer Science & Engineering (Cyber Security)';
    if (normalizedProg.isEmpty) normalizedProg = 'B.E';
  } else if (courseUpper.contains('BUSINESS') || courseUpper.contains('CSBS')) {
    normalizedCourse = 'Computer Science & Business Systems';
    if (normalizedProg.isEmpty) normalizedProg = 'B.E';
  } else if (courseUpper.contains('INFORMATION') || courseUpper == 'IT') {
    normalizedCourse = 'Information Technology';
    if (normalizedProg.isEmpty) normalizedProg = 'B.Tech';
  } else if (courseUpper.contains('COMPUTER SCIENCE') || courseUpper == 'CSE') {
    normalizedCourse = 'Computer Science & Engineering';
    if (normalizedProg.isEmpty) normalizedProg = 'B.E';
  } else if (courseUpper.contains('ELECTRONICS & COMM') ||
      courseUpper.contains('ELECTRONICS AND COMM') ||
      courseUpper.contains('ECE')) {
    normalizedCourse = 'Electronics & Communication Engineering';
    if (normalizedProg.isEmpty) normalizedProg = 'B.E';
  } else if (courseUpper.contains('ELECTRICAL') || courseUpper.contains('EEE')) {
    normalizedCourse = 'Electrical & Electronics Engineering';
    if (normalizedProg.isEmpty) normalizedProg = 'B.E';
  } else if (courseUpper.contains('MECHANICAL')) {
    normalizedCourse = 'Mechanical Engineering';
    if (normalizedProg.isEmpty) normalizedProg = 'B.E';
  } else if (courseUpper.contains('CIVIL')) {
    normalizedCourse = 'Civil Engineering';
    if (normalizedProg.isEmpty) normalizedProg = 'B.E';
  } else {
    normalizedCourse = coursePart;
    if (normalizedProg.isEmpty) normalizedProg = 'B.E';
  }

  return ParsedDepartment(
    programme: normalizedProg,
    course: normalizedCourse,
  );
}

String formatDepartment({required String programme, required String course}) {
  final cleanProg = programme.trim();
  final cleanCourse = course.trim();
  if (cleanProg.isEmpty) return cleanCourse;
  if (cleanCourse.isEmpty) return cleanProg;
  return '$cleanProg in $cleanCourse';
}

String recommendProgrammeForCourse(String course, {String? current}) {
  final c = course.toUpperCase();
  if (c.contains('INFORMATION TECHNOLOGY') ||
      c.contains('ARTIFICIAL INTELLIGENCE & DATA SCIENCE')) {
    return 'B.Tech';
  }
  return 'B.E';
}

const _defaultStandardCourses = [
  'Artificial Intelligence & Data Science',
  'Computer Science & Engineering',
  'Computer Science & Engineering (Artificial Intelligence & Machine Learning)',
  'Computer Science & Engineering (Cyber Security)',
  'Computer Science & Business Systems',
  'Information Technology',
  'Electronics & Communication Engineering',
  'Electrical & Electronics Engineering',
  'Mechanical Engineering',
  'Civil Engineering',
];

class _StudentProfileSheet extends StatelessWidget {
  const _StudentProfileSheet({
    required this.student,
    required this.onEdit,
    required this.onChangeResidency,
    required this.onSetPhoto,
  });

  final ManagedStudent student;
  final VoidCallback onEdit;
  final ValueChanged<ManagedStudentResidency> onChangeResidency;
  final VoidCallback onSetPhoto;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final parsedDept = parseDepartmentAndProgramme(student.department);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: colors.primaryContainer,
                child: Text(
                  student.name.isNotEmpty
                      ? student.name.substring(0, 1).toUpperCase()
                      : 'S',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: colors.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${student.rollNumber} • ${student.department}',
                      style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Year ${student.yearOfStudy}${student.section != null && student.section!.isNotEmpty ? ' • Section ${student.section}' : ''}',
                      style: TextStyle(color: context.palette.inkSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),
          Text(
            'Academic & Identity Details',
            style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          _detailRow(context, Icons.pin_outlined, 'Roll number', student.rollNumber),
          _detailRow(context, Icons.school_outlined, 'Programme', parsedDept.programme),
          _detailRow(context, Icons.domain_outlined, 'Department (Course)', parsedDept.course),
          _detailRow(context, Icons.calendar_today_outlined, 'Year of study', 'Year ${student.yearOfStudy}'),
          if (student.section != null && student.section!.isNotEmpty)
            _detailRow(context, Icons.class_outlined, 'Section', student.section!),
          _detailRow(context, Icons.email_outlined, 'Email', student.email.isEmpty ? 'Not registered' : student.email),
          _detailRow(context, Icons.phone_outlined, 'Phone', student.mobileNumber.isEmpty ? 'Not provided' : student.mobileNumber),
          const SizedBox(height: 14),
          Text(
            'Residency Status',
            style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          SegmentedButton<ManagedStudentResidency>(
            showSelectedIcon: true,
            segments: const [
              ButtonSegment(
                value: ManagedStudentResidency.dayScholar,
                label: Text('Day scholar'),
                icon: Icon(Icons.directions_bus_outlined),
              ),
              ButtonSegment(
                value: ManagedStudentResidency.hosteller,
                label: Text('Hosteller'),
                icon: Icon(Icons.apartment_outlined),
              ),
            ],
            selected: {student.residency},
            onSelectionChanged: (value) => onChangeResidency(value.first),
          ),
          if (student.guardianName.isNotEmpty || student.guardianPhone.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Guardian / Parent Contacts',
              style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            _detailRow(context, Icons.family_restroom_outlined, 'Guardian', '${student.guardianName} (${student.guardianRelationship.isEmpty ? 'Guardian' : student.guardianRelationship})'),
            _detailRow(context, Icons.chat_outlined, 'WhatsApp Phone', student.guardianPhone.isEmpty ? 'Not provided' : student.guardianPhone),
          ],
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onSetPhoto,
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: const Text('Update photo'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit student'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detailRow(BuildContext context, IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Icon(icon, size: 16, color: context.palette.inkSecondary),
        const SizedBox(width: 8),
        Text('$label: ', style: TextStyle(fontSize: 12, color: context.palette.inkSecondary)),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}

class _EditStudentSheet extends StatefulWidget {
  const _EditStudentSheet({
    required this.student,
    required this.repository,
    this.availableDepartments = const [],
  });

  final ManagedStudent student;
  final AdminStudentRepository repository;
  final List<String> availableDepartments;

  @override
  State<_EditStudentSheet> createState() => _EditStudentSheetState();
}

class _EditStudentSheetState extends State<_EditStudentSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _roll;
  late final TextEditingController _mobile;
  late final TextEditingController _email;
  late final TextEditingController _section;
  late final TextEditingController _guardianName;
  late final TextEditingController _guardianPhone;
  late final TextEditingController _guardianRelationship;
  /// Null when the record has no year yet; the admin must choose one rather
  /// than the form silently saving "2nd year".
  int? _year;
  late String _status;
  late ManagedStudentResidency _residency;
  late String _selectedProgramme;
  late String _selectedCourse;
  late final List<String> _programmeOptions;
  late final List<String> _courseOptions;
  AcademicCatalog? _catalog;
  bool _catalogLoading = true;
  AcademicProgramme? _programme;
  String? _classId;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final student = widget.student;
    _name = TextEditingController(text: student.name);
    _roll = TextEditingController(text: student.rollNumber);
    _mobile = TextEditingController(text: student.mobileNumber);
    _email = TextEditingController(text: student.email);
    _section = TextEditingController(text: student.section ?? '');
    _guardianName = TextEditingController(text: student.guardianName);
    _guardianPhone = TextEditingController(text: student.guardianPhone);
    _guardianRelationship = TextEditingController(
      text: student.guardianRelationship,
    );
    _year = student.yearOfStudy;
    const statuses = {
      'active',
      'inactive',
      'suspended',
      'withdrawn',
      'graduated',
    };
    _status = statuses.contains(student.status) ? student.status : 'active';
    _residency = student.residency;

    final parsed = parseDepartmentAndProgramme(student.department);
    _selectedProgramme = parsed.programme;
    _selectedCourse = parsed.course;

    final progSet = <String>{
      'B.E',
      'B.Tech',
      'M.E',
      'M.Tech',
      'MBA',
      'MCA',
      if (_selectedProgramme.isNotEmpty) _selectedProgramme,
    };
    _programmeOptions = progSet.toList()..sort();

    final dynamicCourses = <String>{};
    for (final raw in widget.availableDepartments) {
      final p = parseDepartmentAndProgramme(raw);
      if (p.course.isNotEmpty) dynamicCourses.add(p.course);
    }
    final courseSet = <String>{
      ..._defaultStandardCourses,
      ...dynamicCourses,
      if (_selectedCourse.isNotEmpty) _selectedCourse,
    };
    _courseOptions = courseSet.toList()..sort();
    _loadCatalog();
  }

  @override
  void dispose() {
    _name.dispose();
    _roll.dispose();
    _mobile.dispose();
    _email.dispose();
    _section.dispose();
    _guardianName.dispose();
    _guardianPhone.dispose();
    _guardianRelationship.dispose();
    super.dispose();
  }

  /// Loads the institution's programmes and classes. The hardcoded lists
  /// below stay as the fallback when the catalog cannot be read (offline, no
  /// permission, or a catalog without programmes).
  Future<void> _loadCatalog() async {
    AcademicCatalog? catalog;
    try {
      catalog = await widget.repository.loadAcademicCatalog();
      if (catalog.programmes.isEmpty) catalog = null;
    } catch (_) {
      catalog = null;
    }
    if (!mounted) return;
    final student = widget.student;
    final programme = catalog == null
        ? null
        : AcademicProgrammeField.initialFor(
            catalog,
            programmeId: student.programmeId,
            departmentId: student.departmentId,
            departmentLabel: student.department,
          );
    final classId = catalog != null &&
            programme != null &&
            catalog
                .classesForProgramme(programme.id)
                .any((item) => item.id == student.sectionId)
        ? student.sectionId
        : null;
    setState(() {
      _catalog = catalog;
      _catalogLoading = false;
      _programme = programme;
      _classId = classId;
    });
  }

  void _chooseClass(String? classId) {
    final chosen = _catalog?.classes
        .where((item) => item.id == classId)
        .firstOrNull;
    setState(() {
      _classId = classId;
      if (chosen != null) {
        if (chosen.code.trim().isNotEmpty) _section.text = chosen.code.trim();
        _year = chosen.yearOfStudy ?? _year;
      }
    });
  }

  List<Widget> _programmeFields(BuildContext context) {
    if (_catalogLoading) {
      return const [
        InputDecorator(
          decoration: InputDecoration(labelText: 'Programme'),
          child: SizedBox(
            height: 20,
            child: Align(
              alignment: Alignment.centerLeft,
              child: SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
        ),
      ];
    }
    final catalog = _catalog;
    if (catalog != null) {
      final programme = _programme;
      final classes = programme == null
          ? const <AcademicClass>[]
          : catalog
                .classesForProgramme(programme.id)
                .where((item) => item.active || item.id == _classId)
                .toList();
      return [
        AcademicProgrammeField(
          key: const Key('student-programme-field'),
          catalog: catalog,
          initialProgrammeId: programme?.id,
          currentDepartmentId: widget.student.departmentId,
          currentDepartmentLabel: widget.student.department,
          onChanged: (value) => setState(() {
            if (value.id != _programme?.id) _classId = null;
            _programme = value;
          }),
        ),
        if (classes.isNotEmpty) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            key: ValueKey('student-class-${programme?.id}-$_classId'),
            initialValue: _classId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Class (optional)'),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Not assigned'),
              ),
              for (final item in classes)
                DropdownMenuItem<String?>(
                  value: item.id,
                  child: Text(item.label, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: _chooseClass,
          ),
        ],
      ];
    }
    return [
      DropdownButtonFormField<String>(
        key: ValueKey('programme_$_selectedProgramme'),
        initialValue: _programmeOptions.contains(_selectedProgramme)
            ? _selectedProgramme
            : _programmeOptions.first,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Programme (BE / B.Tech / etc.)',
          prefixIcon: Icon(Icons.school_outlined),
        ),
        items: [
          for (final p in _programmeOptions)
            DropdownMenuItem(value: p, child: Text(p)),
        ],
        onChanged: (val) {
          if (val != null) setState(() => _selectedProgramme = val);
        },
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        key: ValueKey('course_$_selectedCourse'),
        initialValue: _courseOptions.contains(_selectedCourse)
            ? _selectedCourse
            : _courseOptions.first,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Department (Course)',
          prefixIcon: Icon(Icons.domain_outlined),
        ),
        items: [
          for (final c in _courseOptions)
            DropdownMenuItem(
              value: c,
              child: Text(
                c,
                style: const TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: (val) {
          if (val != null) {
            setState(() {
              _selectedCourse = val;
              _selectedProgramme = recommendProgrammeForCourse(
                val,
                current: _selectedProgramme,
              );
            });
          }
        },
      ),
      const SizedBox(height: 6),
      Text(
        'Saved as: ${formatDepartment(programme: _selectedProgramme, course: _selectedCourse)}',
        style: TextStyle(fontSize: 12, color: context.palette.inkSecondary),
        overflow: TextOverflow.ellipsis,
      ),
    ];
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Required' : null;

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final programme = _catalog == null ? null : _programme;
      final formattedDepartment =
          programme?.name ??
          formatDepartment(
            programme: _selectedProgramme,
            course: _selectedCourse,
          );
      final saved = await widget.repository.updateStudent(
        widget.student.copyWith(
          name: _name.text.trim(),
          rollNumber: _roll.text.trim(),
          department: formattedDepartment,
          departmentId: programme?.departmentId,
          programmeId: programme?.id,
          sectionId: programme == null ? null : _classId,
          mobileNumber: _mobile.text.trim(),
          email: _email.text.trim().toLowerCase(),
          section: _section.text.trim(),
          yearOfStudy: _year,
          status: _status,
          residency: _residency,
          guardianName: _guardianName.text.trim(),
          guardianPhone: _guardianPhone.text.trim(),
          guardianRelationship: _guardianRelationship.text.trim(),
        ),
      );
      if (mounted) Navigator.of(context).pop(saved);
    } catch (error) {
      if (mounted) setState(() => _error = userFacingError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).dividerColor,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Edit student',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Full name'),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _roll,
                decoration: const InputDecoration(labelText: 'Roll number'),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (value) {
                  final requiredError = _required(value);
                  if (requiredError != null) return requiredError;
                  return value!.contains('@') ? null : 'Enter a valid email';
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _mobile,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Mobile number'),
              ),
              const SizedBox(height: 12),
              ..._programmeFields(context),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      key: ValueKey('student-year-$_year'),
                      initialValue: _year,
                      decoration: const InputDecoration(labelText: 'Year'),
                      hint: const Text('Select year'),
                      validator: (value) =>
                          value == null ? 'Choose the year of study' : null,
                      items: [
                        for (var year = 1; year <= 6; year++)
                          DropdownMenuItem(
                            value: year,
                            child: Text('Year $year'),
                          ),
                      ],
                      onChanged: (value) =>
                          setState(() => _year = value ?? _year),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _section,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(labelText: 'Section'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<ManagedStudentResidency>(
                initialValue: _residency,
                decoration: const InputDecoration(labelText: 'Residency'),
                items: [
                  for (final value in ManagedStudentResidency.values)
                    DropdownMenuItem(value: value, child: Text(value.label)),
                ],
                onChanged: (value) =>
                    setState(() => _residency = value ?? _residency),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(labelText: 'Account status'),
                items: const [
                  DropdownMenuItem(value: 'active', child: Text('Active')),
                  DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                  DropdownMenuItem(
                    value: 'suspended',
                    child: Text('Suspended'),
                  ),
                  DropdownMenuItem(
                    value: 'withdrawn',
                    child: Text('Withdrawn'),
                  ),
                  DropdownMenuItem(
                    value: 'graduated',
                    child: Text('Graduated'),
                  ),
                ],
                onChanged: (value) =>
                    setState(() => _status = value ?? _status),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Icon(
                    Icons.family_restroom_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Primary parent / guardian',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'This contact receives attendance, fee and outpass WhatsApp messages for this student.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _guardianName,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Parent / guardian full name',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                validator: (value) {
                  if (_guardianPhone.text.trim().isNotEmpty &&
                      (value == null || value.trim().isEmpty)) {
                    return 'Enter the parent or guardian name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _guardianRelationship,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Relationship',
                  hintText: 'Father, mother or guardian',
                  prefixIcon: Icon(Icons.people_outline_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _guardianPhone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'WhatsApp number',
                  hintText: '916379173918',
                  helperText:
                      'Include the country code, without spaces if possible',
                  prefixIcon: Icon(Icons.chat_outlined),
                ),
                validator: (value) {
                  final phone = value?.trim() ?? '';
                  if (_guardianName.text.trim().isNotEmpty && phone.isEmpty) {
                    return 'Enter the WhatsApp number';
                  }
                  if (phone.isNotEmpty &&
                      phone.replaceAll(RegExp(r'\D'), '').length < 8) {
                    return 'Enter a valid WhatsApp number';
                  }
                  return null;
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_saving ? 'Saving…' : 'Save changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminAnnouncementsPage extends StatefulWidget {
  const _AdminAnnouncementsPage({required this.repository});
  final LibrarianRepository repository;
  @override
  State<_AdminAnnouncementsPage> createState() => _AdminAnnouncementsPageState();
}

class _AdminAnnouncementsPageState extends State<_AdminAnnouncementsPage> {
  List<LibraryAnnouncement> _items = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final values = await widget.repository.announcements();
      if (mounted) {
        setState(() {
          _items = values;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _decide(LibraryAnnouncement item, String decision) async {
    try {
      await widget.repository.decideAnnouncement(item.id, decision);
      await _load();
      _snack('Library announcement $decision.');
    } catch (error) {
      _snack(userFacingError(error));
    }
  }

  Future<void> _publishAnnouncement() async {
    final draft = await showAnnouncementComposer(
      context,
      heading: 'Publish campus announcement',
      submitLabel: 'Publish now',
      supportingText:
          'This appears immediately on the Campus Wall for students and faculty. Attach a circular PDF or cover image.',
      coverImageOnly: false,
    );
    if (draft == null) return;
    try {
      await widget.repository.createAnnouncement(
        type: draft.type,
        announcementDate: draft.date,
        title: draft.title,
        message: draft.description,
        attachmentName: draft.attachmentName,
        attachmentUrl: draft.attachmentUrl,
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Campus announcement published.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userFacingError(error))));
      }
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _editAnnouncement(LibraryAnnouncement item) async {
    final draft = await showAnnouncementComposer(
      context,
      heading: 'Edit announcement',
      submitLabel: 'Save changes',
      supportingText: 'Changes appear on the Campus Wall right away.',
      coverImageOnly: false,
      initial: AnnouncementDraft(
        type: item.type,
        date: item.announcementDate,
        title: item.title,
        description: item.message,
        attachmentName: item.attachmentName,
        attachmentUrl: item.attachmentUrl,
      ),
    );
    if (draft == null) return;
    try {
      await widget.repository.updateAnnouncement(
        item.id,
        type: draft.type,
        announcementDate: draft.date,
        title: draft.title,
        message: draft.description,
        bookTitle: item.bookTitle,
        author: item.author,
        attachmentName: draft.attachmentName,
        attachmentUrl: draft.attachmentUrl,
      );
      await _load();
      _snack('Announcement updated.');
    } catch (error) {
      _snack(userFacingError(error));
    }
  }

  Future<void> _deleteAnnouncement(LibraryAnnouncement item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete announcement?'),
        content: Text(
          '"${item.title}" will be removed from the Campus Wall for everyone. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.repository.deleteAnnouncement(item.id);
      await _load();
      _snack('Announcement deleted.');
    } catch (error) {
      _snack(userFacingError(error));
    }
  }

  Future<void> _openAttachment(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null &&
        await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      return;
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open attachment.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Announcements'),
      actions: [
        IconButton(
          tooltip: 'Publish announcement',
          onPressed: _publishAnnouncement,
          icon: const Icon(Icons.add_photo_alternate_outlined),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _publishAnnouncement,
      icon: const Icon(Icons.campaign_outlined),
      label: const Text('New announcement'),
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _items.isEmpty
        ? const Center(child: Text('No announcements yet'))
        : ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 104),
            itemCount: _items.length,
            itemBuilder: (context, index) {
              final item = _items[index];
              final hasImage = _announcementHasImage(item);
              final hasPdf = _announcementHasPdf(item);
              final hasAttachment = item.attachmentUrl != null;

              return Card(
                elevation: 0,
                child: ListTile(
                  onTap: hasAttachment ? () => _openAttachment(item.attachmentUrl!) : null,
                  leading: hasImage
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            item.attachmentUrl!,
                            width: 52,
                            height: 52,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const SizedBox.square(
                              dimension: 52,
                              child: Icon(Icons.broken_image_outlined),
                            ),
                          ),
                        )
                      : hasPdf
                      ? Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: context.palette.danger.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.picture_as_pdf_rounded,
                            color: context.palette.danger,
                            size: 24,
                          ),
                        )
                      : const Icon(Icons.campaign_outlined),
                  title: Text(item.title),
                  subtitle: Text(
                    '${item.message}\n'
                    '${item.status.toUpperCase()} · ${item.createdByName}'
                    '${item.attachmentName != null ? ' · 📎 ${item.attachmentName}' : ''}',
                  ),
                  isThreeLine: true,
                  trailing: PopupMenuButton<String>(
                    tooltip: 'Manage ${item.title}',
                    onSelected: (value) {
                      switch (value) {
                        case 'approved' || 'rejected':
                          _decide(item, value);
                        case 'open':
                          _openAttachment(item.attachmentUrl!);
                        case 'edit':
                          _editAnnouncement(item);
                        case 'delete':
                          _deleteAnnouncement(item);
                      }
                    },
                    itemBuilder: (_) => [
                      if (item.status == 'pending') ...const [
                        PopupMenuItem(
                          value: 'approved',
                          child: Text('Approve'),
                        ),
                        PopupMenuItem(
                          value: 'rejected',
                          child: Text('Reject'),
                        ),
                        PopupMenuDivider(),
                      ],
                      if (hasAttachment)
                        PopupMenuItem(
                          value: 'open',
                          child: Text(
                            hasPdf ? 'Open PDF circular' : 'Open attachment',
                          ),
                        ),
                      const PopupMenuItem(
                        value: 'edit',
                        child: Text('Edit'),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          'Delete',
                          style: TextStyle(color: context.palette.danger),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
  );
}

bool _announcementHasImage(LibraryAnnouncement item) {
  return isAnnouncementImageAttachment(item.attachmentName, item.attachmentUrl);
}

bool _announcementHasPdf(LibraryAnnouncement item) {
  final name = (item.attachmentName ?? '').toLowerCase();
  final url = (item.attachmentUrl ?? '').toLowerCase();
  return name.endsWith('.pdf') || url.contains('.pdf');
}

class _AdminMaintenancePage extends StatefulWidget {
  const _AdminMaintenancePage({required this.repository});

  final MaintenanceRepository repository;

  @override
  State<_AdminMaintenancePage> createState() => _AdminMaintenancePageState();
}

class _AdminMaintenancePageState extends State<_AdminMaintenancePage> {
  final _messageController = TextEditingController(
    text: 'We are making a few improvements. Please check back shortly.',
  );
  DateTime _startsAt = DateTime.now();
  DateTime _endsAt = DateTime.now().add(const Duration(hours: 1));
  bool _enabled = false;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final window = await widget.repository.adminStatus();
      if (!mounted) return;
      setState(() {
        _enabled = window.enabled;
        _startsAt = window.startsAt ?? DateTime.now();
        _endsAt = window.endsAt ?? DateTime.now().add(const Duration(hours: 1));
        if (window.message.isNotEmpty) _messageController.text = window.message;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = userFacingError(error);
        });
      }
    }
  }

  Future<void> _pick(bool start) async {
    final initial = start ? _startsAt : _endsAt;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return;
    final value = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() {
      if (start) {
        _startsAt = value;
        if (_endsAt.isBefore(value.add(const Duration(minutes: 1)))) {
          _endsAt = value.add(const Duration(hours: 1));
        }
      } else {
        _endsAt = value;
      }
    });
  }

  Future<void> _save() async {
    if (_endsAt.isBefore(_startsAt) || _endsAt.isAtSameMomentAs(_startsAt)) {
      setState(() => _error = 'End time must be after the start time.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await widget.repository.save(
        enabled: _enabled,
        startsAt: _startsAt,
        endsAt: _endsAt,
        message: _messageController.text,
      );
      if (!mounted) return;
      setState(() {
        _enabled = saved.enabled;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            saved.enabled
                ? 'Maintenance window scheduled.'
                : 'Maintenance mode is off.',
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = userFacingError(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Maintenance control'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: _enabled
                        ? context.adaptive(light: const Color(0xFFFFECEC), dark: const Color(0x2EE53935))
                        : context.adaptive(light: const Color(0xFFF0ECFF), dark: const Color(0x2E9D4EDD)),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: _enabled,
                    activeThumbColor: Colors.red.shade700,
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _enabled = value),
                    title: Text(
                      _enabled
                          ? 'Maintenance scheduled'
                          : 'Maintenance mode off',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: const Text(
                      'During the active window, only an administrator can sign in.',
                    ),
                    secondary: Icon(
                      Icons.construction_rounded,
                      color: _enabled
                          ? context.adaptive(light: Colors.red.shade700, dark: Colors.red.shade300)
                          : context.palette.brandInk,
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  'Time window',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                _TimeTile(
                  label: 'Starts',
                  value: _formatDateTime(_startsAt),
                  onTap: () => _pick(true),
                ),
                const SizedBox(height: 10),
                _TimeTile(
                  label: 'Ends',
                  value: _formatDateTime(_endsAt),
                  onTap: () => _pick(false),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: _messageController,
                  maxLength: 280,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Message shown to users',
                    alignLabelWithHint: true,
                    prefixIcon: Icon(Icons.message_outlined),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: TextStyle(color: context.adaptive(light: Colors.red.shade700, dark: Colors.red.shade300))),
                ],
                const SizedBox(height: 18),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: _enabled
                        ? Colors.red.shade700
                        : context.palette.brand,
                    minimumSize: const Size.fromHeight(52),
                  ),
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.schedule_send_rounded),
                  label: Text(
                    _enabled ? 'Schedule maintenance' : 'Save as off',
                  ),
                ),
              ],
            ),
    );
  }

  String _formatDateTime(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final period = value.hour >= 12 ? 'PM' : 'AM';
    return '${value.day}/${value.month}/${value.year}  $hour:$minute $period';
  }
}

class _TimeTile extends StatelessWidget {
  const _TimeTile({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: p.surface,
      borderRadius: BorderRadius.circular(16),
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: context.adaptive(light: const Color(0xFFE5DDF8), dark: p.border),
          ),
        ),
        leading: Icon(Icons.event_outlined, color: p.brandInk),
        title: Text(label),
        subtitle: Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        trailing: const Icon(Icons.edit_calendar_outlined),
        onTap: onTap,
      ),
    );
  }
}
