import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/module_section_switcher.dart';
import '../../library/data/librarian_repository.dart';
import '../../maintenance/data/maintenance_repository.dart';
import '../data/admin_student_repository.dart';

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
              ManagedStudent(
                id: item.id,
                name: item.name,
                rollNumber: item.rollNumber,
                department: item.department,
                residency: saved,
                photoUrl: item.photoUrl,
              )
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

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final rows = (_students ?? const <ManagedStudent>[])
        .where(
          (student) =>
              query.isEmpty ||
              '${student.name} ${student.rollNumber} ${student.department}'
                  .toLowerCase()
                  .contains(query),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student residency'),
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
                hintText: 'Search name, roll number or department',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Text(
              'Residency controls hostel outpass eligibility and connected student services.',
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
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                    itemCount: rows.length,
                    itemBuilder: (context, index) {
                      final student = rows[index];
                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                student.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                '${student.rollNumber} • ${student.department}',
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 12),
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
                                onSelectionChanged: _savingId == null
                                    ? (value) => _change(student, value.first)
                                    : null,
                              ),
                              if (_savingId == student.id) ...[
                                const SizedBox(height: 8),
                                const LinearProgressIndicator(minHeight: 2),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
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
          _items = values.where((value) => value.status == 'pending').toList();
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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Pending approvals')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _items.isEmpty
        ? const Center(child: Text('No pending approvals'))
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _items.length,
            itemBuilder: (context, index) => Card(
              elevation: 0,
              child: ListTile(
                leading: const Icon(Icons.campaign_outlined),
                title: Text(_items[index].title),
                subtitle: Text(
                  '${_items[index].bookTitle ?? _items[index].message}\nSubmitted by ${_items[index].createdByName}',
                ),
                isThreeLine: true,
                trailing: PopupMenuButton<String>(
                  onSelected: (value) => _decide(_items[index], value),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'approve', child: Text('Approve')),
                    PopupMenuItem(value: 'reject', child: Text('Reject')),
                  ],
                ),
              ),
            ),
          ),
  );
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
