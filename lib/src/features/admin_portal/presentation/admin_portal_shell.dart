import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../access_control/presentation/admin_access_control_screen.dart';
import '../../authentication/data/auth_repository.dart';

/// Deliberately limited mobile admin surface. Full operations belong in the
/// web portal; mobile is reserved for urgent approvals and response actions.
class AdminPortalShell extends StatefulWidget {
  const AdminPortalShell({
    super.key,
    required this.session,
    required this.onSignOut,
  });

  final UserSession session;
  final VoidCallback onSignOut;

  @override
  State<AdminPortalShell> createState() => _AdminPortalShellState();
}

class _AdminPortalShellState extends State<AdminPortalShell> {
  var _selected = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      _AdminOverview(onSelectTab: (value) => setState(() => _selected = value)),
      AdminAccessControlScreen(
        session: widget.session,
        onSignOut: widget.onSignOut,
      ),
      const _AdminApprovalsPage(),
      const _AdminEmergencyPage(),
    ];
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: IndexedStack(index: _selected, children: pages),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selected,
        onDestinationSelected: (value) => setState(() => _selected = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            label: 'Desk',
          ),
          NavigationDestination(
            icon: Icon(Icons.admin_panel_settings_outlined),
            label: 'Access',
          ),
          NavigationDestination(
            icon: Icon(Icons.approval_outlined),
            label: 'Approvals',
          ),
          NavigationDestination(
            icon: Icon(Icons.emergency_outlined),
            label: 'Emergency',
          ),
        ],
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
              onTap: () => onSelectTab(1),
            ),
            _DomainTile(
              title: 'Emergency response',
              subtitle: 'Campus alert, lockdown and escalation actions',
              icon: Icons.emergency_outlined,
              onTap: () => onSelectTab(3),
            ),
          ]),
        ),
      ),
    ],
  );
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
  const _AdminApprovalsPage();
  @override
  State<_AdminApprovalsPage> createState() => _AdminApprovalsPageState();
}

class _AdminApprovalsPageState extends State<_AdminApprovalsPage> {
  final _items = <String>[
    'Library access · ABC user',
    'Gatepass approval · Student 22EC101',
    'Attendance correction · ECE / 4th year',
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Pending approvals')),
    body: _items.isEmpty
        ? const Center(child: Text('No pending approvals'))
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _items.length,
            itemBuilder: (context, index) => Card(
              elevation: 0,
              child: ListTile(
                title: Text(_items[index]),
                subtitle: const Text('Review required'),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) => setState(() => _items.removeAt(index)),
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
