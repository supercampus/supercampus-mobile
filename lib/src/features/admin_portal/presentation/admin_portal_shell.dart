import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/media/media_scope.dart';
import '../../../core/media/media_picker.dart';
import '../../../core/students/student_year.dart';
import '../../../core/widgets/module_section_switcher.dart';
import '../../../core/widgets/announcement_composer.dart';
import '../../../core/widgets/announcement_image_cropper.dart';
import '../../library/data/librarian_repository.dart';
import '../../maintenance/data/maintenance_repository.dart';
import '../data/admin_student_repository.dart';
import 'admin_users_page.dart';

/// Focused admin surface for student management and pending approvals.
class AdminPortalShell extends StatefulWidget {
  const AdminPortalShell({
    super.key,
    required this.libraryRepository,
    required this.studentRepository,
    required this.maintenanceRepository,
  });

  final LibrarianRepository libraryRepository;
  final AdminStudentRepository studentRepository;
  final MaintenanceRepository maintenanceRepository;

  @override
  State<AdminPortalShell> createState() => _AdminPortalShellState();
}

class _AdminPortalShellState extends State<AdminPortalShell> {
  var _selected = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      AdminUsersPage(repository: widget.studentRepository),
      _AdminStudentsPage(repository: widget.studentRepository),
      _AdminApprovalsPage(repository: widget.libraryRepository),
      _AdminMaintenancePage(repository: widget.maintenanceRepository),
    ];
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            ModuleSectionSwitcher(
              sections: const [
                ModuleSection(
                  label: 'Users',
                  icon: Icons.manage_accounts_outlined,
                ),
                ModuleSection(label: 'Students', icon: Icons.school_outlined),
                ModuleSection(
                  label: 'Approvals',
                  icon: Icons.approval_outlined,
                ),
                ModuleSection(
                  label: 'Maintenance',
                  icon: Icons.construction_rounded,
                ),
              ],
              selectedIndex: _selected,
              onSelected: (value) => setState(() => _selected = value),
            ),
            Expanded(
              child: IndexedStack(index: _selected, children: pages),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminStudentsPage extends StatefulWidget {
  const _AdminStudentsPage({required this.repository});
  final AdminStudentRepository repository;

  @override
  State<_AdminStudentsPage> createState() => _AdminStudentsPageState();
}

class _AdminStudentsPageState extends State<_AdminStudentsPage> {
  List<ManagedStudent>? _students;
  String _query = '';
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
      if (mounted) setState(() => _error = error.toString());
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
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _savingId = null);
    }
  }

  Future<void> _edit(ManagedStudent student) async {
    final saved = await showModalBottomSheet<ManagedStudent>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) =>
          _EditStudentSheet(student: student, repository: widget.repository),
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

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final rows = (_students ?? const <ManagedStudent>[])
        .where(
          (student) =>
              query.isEmpty ||
              '${student.name} ${student.rollNumber} ${student.department} ${student.email} ${student.mobileNumber} ${student.section ?? ''}'
                  .toLowerCase()
                  .contains(query),
        )
        .toList();
    final groups = groupStudentsByYear(rows, (student) => student.yearOfStudy);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student management'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: TextField(
              onChanged: (value) => setState(() => _query = value),
              decoration: const InputDecoration(
                hintText: 'Search students',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Text(
              'Edit student identity, academic, contact and residency details.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ),
          Expanded(
            child: _error != null
                ? Center(
                    child: FilledButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry'),
                    ),
                  )
                : _students == null
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                    children: [
                      for (final group in groups) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(2, 10, 2, 8),
                          child: Row(
                            children: [
                              Text(
                                group.label,
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const Spacer(),
                              Text(
                                '${group.students.length}',
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        for (final student in group.students)
                          Card(
                            elevation: 0,
                            margin: const EdgeInsets.only(bottom: 10),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          student.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Edit student',
                                        onPressed: _savingId == null
                                            ? () => _edit(student)
                                            : null,
                                        icon: const Icon(Icons.edit_outlined),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '${student.rollNumber} • ${student.department}',
                                    style: const TextStyle(
                                      color: AppColors.muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                  if ((student.section ?? '').isNotEmpty ||
                                      student.email.isNotEmpty)
                                    Text(
                                      [
                                        if ((student.section ?? '').isNotEmpty)
                                          'Section ${student.section}',
                                        if (student.email.isNotEmpty)
                                          student.email,
                                      ].join(' • '),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppColors.muted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  if (student.guardianName.isNotEmpty ||
                                      student.guardianPhone.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.family_restroom_outlined,
                                          size: 15,
                                          color: AppColors.muted,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            [
                                                  student.guardianName,
                                                  if (student
                                                      .guardianRelationship
                                                      .isNotEmpty)
                                                    student
                                                        .guardianRelationship,
                                                  student.guardianPhone,
                                                ]
                                                .where(
                                                  (value) => value.isNotEmpty,
                                                )
                                                .join(' • '),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: AppColors.muted,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  OutlinedButton.icon(
                                    icon: const Icon(
                                      Icons.add_a_photo_outlined,
                                    ),
                                    label: const Text('Set profile photo'),
                                    onPressed: () async {
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
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(error.toString()),
                                            ),
                                          );
                                        }
                                      }
                                    },
                                  ),
                                  SegmentedButton<ManagedStudentResidency>(
                                    showSelectedIcon: true,
                                    segments: const [
                                      ButtonSegment(
                                        value:
                                            ManagedStudentResidency.dayScholar,
                                        label: Text('Day scholar'),
                                        icon: Icon(
                                          Icons.directions_bus_outlined,
                                        ),
                                      ),
                                      ButtonSegment(
                                        value:
                                            ManagedStudentResidency.hosteller,
                                        label: Text('Hosteller'),
                                        icon: Icon(Icons.apartment_outlined),
                                      ),
                                    ],
                                    selected: {student.residency},
                                    onSelectionChanged: _savingId == null
                                        ? (value) =>
                                              _change(student, value.first)
                                        : null,
                                  ),
                                  if (_savingId == student.id) ...[
                                    const SizedBox(height: 8),
                                    const LinearProgressIndicator(minHeight: 2),
                                  ],
                                ],
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _EditStudentSheet extends StatefulWidget {
  const _EditStudentSheet({required this.student, required this.repository});

  final ManagedStudent student;
  final AdminStudentRepository repository;

  @override
  State<_EditStudentSheet> createState() => _EditStudentSheetState();
}

class _EditStudentSheetState extends State<_EditStudentSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _roll;
  late final TextEditingController _department;
  late final TextEditingController _mobile;
  late final TextEditingController _email;
  late final TextEditingController _section;
  late final TextEditingController _guardianName;
  late final TextEditingController _guardianPhone;
  late final TextEditingController _guardianRelationship;
  late int _year;
  late String _status;
  late ManagedStudentResidency _residency;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final student = widget.student;
    _name = TextEditingController(text: student.name);
    _roll = TextEditingController(text: student.rollNumber);
    _department = TextEditingController(text: student.department);
    _mobile = TextEditingController(text: student.mobileNumber);
    _email = TextEditingController(text: student.email);
    _section = TextEditingController(text: student.section ?? '');
    _guardianName = TextEditingController(text: student.guardianName);
    _guardianPhone = TextEditingController(text: student.guardianPhone);
    _guardianRelationship = TextEditingController(
      text: student.guardianRelationship,
    );
    _year = student.yearOfStudy ?? 2;
    const statuses = {
      'active',
      'inactive',
      'suspended',
      'withdrawn',
      'graduated',
    };
    _status = statuses.contains(student.status) ? student.status : 'active';
    _residency = student.residency;
  }

  @override
  void dispose() {
    _name.dispose();
    _roll.dispose();
    _department.dispose();
    _mobile.dispose();
    _email.dispose();
    _section.dispose();
    _guardianName.dispose();
    _guardianPhone.dispose();
    _guardianRelationship.dispose();
    super.dispose();
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
      final saved = await widget.repository.updateStudent(
        widget.student.copyWith(
          name: _name.text.trim(),
          rollNumber: _roll.text.trim(),
          department: _department.text.trim(),
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
      if (mounted) setState(() => _error = error.toString());
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
              TextFormField(
                controller: _department,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'Department'),
                validator: _required,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _year,
                      decoration: const InputDecoration(labelText: 'Year'),
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

class _AdminApprovalsPage extends StatefulWidget {
  const _AdminApprovalsPage({required this.repository});
  final LibrarianRepository repository;
  @override
  State<_AdminApprovalsPage> createState() => _AdminApprovalsPageState();
}

class _AdminApprovalsPageState extends State<_AdminApprovalsPage> {
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
    await widget.repository.decideAnnouncement(item.id, decision);
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Library announcement $decision.')),
      );
    }
  }

  Future<void> _publishAnnouncement() async {
    final draft = await showAnnouncementComposer(
      context,
      heading: 'Publish campus announcement',
      submitLabel: 'Publish now',
      supportingText:
          'This appears immediately on every account in your campus. Add a cover image to make the update easier to notice.',
      coverImageOnly: true,
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
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
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
            itemBuilder: (context, index) => Card(
              elevation: 0,
              child: ListTile(
                leading: _announcementHasImage(_items[index])
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          _items[index].attachmentUrl!,
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const SizedBox.square(
                            dimension: 52,
                            child: Icon(Icons.broken_image_outlined),
                          ),
                        ),
                      )
                    : const Icon(Icons.campaign_outlined),
                title: Text(_items[index].title),
                subtitle: Text(
                  '${_items[index].message}\n'
                  '${_items[index].status.toUpperCase()} · ${_items[index].createdByName}',
                ),
                isThreeLine: true,
                trailing: _items[index].status == 'pending'
                    ? PopupMenuButton<String>(
                        onSelected: (value) => _decide(_items[index], value),
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'approved',
                            child: Text('Approve'),
                          ),
                          PopupMenuItem(
                            value: 'rejected',
                            child: Text('Reject'),
                          ),
                        ],
                      )
                    : null,
              ),
            ),
          ),
  );
}

bool _announcementHasImage(LibraryAnnouncement item) {
  return isAnnouncementImageAttachment(item.attachmentName, item.attachmentUrl);
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
          _error = error.toString();
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
          _error = error.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Maintenance control'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
        ],
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
                        ? const Color(0xFFFFECEC)
                        : const Color(0xFFF0ECFF),
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
                      color: _enabled ? Colors.red.shade700 : AppColors.primary,
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
                  Text(_error!, style: TextStyle(color: Colors.red.shade700)),
                ],
                const SizedBox(height: 18),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: _enabled
                        ? Colors.red.shade700
                        : AppColors.primary,
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
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE5DDF8)),
        ),
        leading: const Icon(Icons.event_outlined, color: AppColors.primary),
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
