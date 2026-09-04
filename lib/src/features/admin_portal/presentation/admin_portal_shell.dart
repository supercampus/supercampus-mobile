import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/module_section_switcher.dart';
import '../../access_control/presentation/admin_access_control_screen.dart';
import '../../authentication/data/auth_repository.dart';
import '../../library/data/librarian_repository.dart';
import '../data/admin_student_repository.dart';

/// Deliberately limited mobile admin surface. Full operations belong in the
/// web portal; mobile is reserved for urgent approvals and response actions.
class AdminPortalShell extends StatefulWidget {
  const AdminPortalShell({
    super.key,
    required this.session,
    required this.onSignOut,
    required this.libraryRepository,
    required this.studentRepository,
  });

  final UserSession session;
  final VoidCallback onSignOut;
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
      _AdminOverview(onSelectTab: (value) => setState(() => _selected = value)),
      _AdminStudentsPage(repository: widget.studentRepository),
      AdminAccessControlScreen(
        session: widget.session,
        onSignOut: widget.onSignOut,
      ),
      _AdminApprovalsPage(repository: widget.libraryRepository),
      const _AdminEmergencyPage(),
    ];
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            ModuleSectionSwitcher(
              sections: const [
                ModuleSection(label: 'Desk', icon: Icons.dashboard_outlined),
                ModuleSection(label: 'Students', icon: Icons.school_outlined),
                ModuleSection(
                  label: 'Access',
                  icon: Icons.admin_panel_settings_outlined,
                ),
                ModuleSection(
                  label: 'Approvals',
                  icon: Icons.approval_outlined,
                ),
                ModuleSection(
                  label: 'Emergency',
                  icon: Icons.emergency_outlined,
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

class _AdminOverview extends StatelessWidget {
  const _AdminOverview({required this.onSelectTab});
  final ValueChanged<int> onSelectTab;

  @override
  Widget build(BuildContext context) => CustomScrollView(
    slivers: [
      SliverAppBar(
        pinned: true,
        backgroundColor: AppColors.ink,
        foregroundColor: Colors.white,
        title: const Text('Admin quick desk'),
      ),
      SliverPadding(
        padding: const EdgeInsets.all(20),
        sliver: SliverList(
          delegate: SliverChildListDelegate([
            Text(
              'Approval & emergency desk',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            const Text(
              'Operational module management is available in the web portal.',
            ),
            const SizedBox(height: 20),
            const _MetricCard(
              label: 'Pending approvals',
              value: '18',
              icon: Icons.pending_actions_outlined,
            ),
            const SizedBox(height: 10),
            const _MetricCard(
              label: 'Open emergency alerts',
              value: '06',
              icon: Icons.warning_amber_outlined,
            ),
            const SizedBox(height: 24),
            _DomainTile(
              title: 'Access approvals',
              subtitle: 'Approve or revoke urgent user access',
              icon: Icons.admin_panel_settings_outlined,
              onTap: () => onSelectTab(2),
            ),
            _DomainTile(
              title: 'Emergency response',
              subtitle: 'Campus alert, lockdown and escalation actions',
              icon: Icons.emergency_outlined,
              onTap: () => onSelectTab(4),
            ),
          ]),
        ),
      ),
    ],
  );
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

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    child: ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.violet.withValues(alpha: .1),
        child: Icon(icon, color: AppColors.violet),
      ),
      title: Text(
        value,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(label),
    ),
  );
}

class _DomainTile extends StatelessWidget {
  const _DomainTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    child: ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: AppColors.violet.withValues(alpha: .1),
        child: Icon(icon, color: AppColors.violet),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
    ),
  );
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

class _AdminEmergencyPage extends StatelessWidget {
  const _AdminEmergencyPage();

  Future<void> _confirm(
    BuildContext context,
    String title,
    String message,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$title initiated')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Emergency response')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Use only for verified incidents.',
          style: TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 18),
        _EmergencyAction(
          title: 'Send campus alert',
          subtitle: 'Notify security, staff and students',
          icon: Icons.campaign_outlined,
          color: Colors.orange,
          onTap: () => _confirm(
            context,
            'Campus alert',
            'Send an emergency notification to the campus?',
          ),
        ),
        _EmergencyAction(
          title: 'Lockdown campus access',
          subtitle: 'Temporarily restrict gatepass and visitor entry',
          icon: Icons.lock_outline,
          color: Colors.red,
          onTap: () =>
              _confirm(context, 'Lockdown', 'Restrict campus access now?'),
        ),
        _EmergencyAction(
          title: 'Contact security desk',
          subtitle: 'Escalate the active incident',
          icon: Icons.phone_in_talk_outlined,
          color: AppColors.violet,
          onTap: () => _confirm(
            context,
            'Security escalation',
            'Escalate this incident to the security desk?',
          ),
        ),
      ],
    ),
  );
}

class _EmergencyAction extends StatelessWidget {
  const _EmergencyAction({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    child: ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: .12),
        child: Icon(icon, color: color),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
    ),
  );
}
