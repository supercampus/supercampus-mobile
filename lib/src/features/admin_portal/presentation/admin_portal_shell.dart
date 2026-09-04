import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/module_section_switcher.dart';
import '../../library/data/librarian_repository.dart';
import '../data/admin_student_repository.dart';

/// Focused admin surface for student management and pending approvals.
class AdminPortalShell extends StatefulWidget {
  const AdminPortalShell({
    super.key,
    required this.libraryRepository,
    required this.studentRepository,
  });

  final LibrarianRepository libraryRepository;
  final AdminStudentRepository studentRepository;

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
