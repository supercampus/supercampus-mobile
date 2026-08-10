import 'package:flutter/material.dart';

import '../../../../core/access/effective_permissions.dart';
import '../../../../core/access/module_catalog.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../authentication/data/auth_repository.dart';
import '../../../insights/data/insight.dart';

/// Shared chrome: rounded top, grab handle, title.
Future<T?> showHomeSheet<T>({
  required BuildContext context,
  required String title,
  required Widget child,
  bool expand = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight:
                MediaQuery.of(context).size.height * (expand ? 0.85 : 0.7),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Flexible(child: child),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Searches the catalog the user can actually see — modules by name and
/// tagline, and the features they hold a grant on. Matching a feature opens
/// its module, because that is the only place the feature exists.
class CampusSearchSheet extends StatefulWidget {
  const CampusSearchSheet({
    super.key,
    required this.permissions,
    required this.onOpenModule,
  });

  final EffectivePermissions permissions;
  final ValueChanged<String> onOpenModule;

  @override
  State<CampusSearchSheet> createState() => _CampusSearchSheetState();
}

class _CampusSearchSheetState extends State<CampusSearchSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final results = _search(_query);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
          child: TextField(
            key: const ValueKey('search-field'),
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'search anything',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
        ),
        Flexible(
          child: results.isEmpty
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                  child: Text(
                    _query.trim().isEmpty
                        ? 'Search across every campus service you have access to.'
                        : 'Nothing matches “$_query”.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 20),
                  itemCount: results.length,
                  itemBuilder: (context, i) {
                    final result = results[i];
                    final ready = result.module.status != ModuleStatus.planned;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: result.module.color.withValues(
                          alpha: 0.12,
                        ),
                        child: Icon(
                          result.module.icon,
                          color: result.module.color,
                          size: 20,
                        ),
                      ),
                      title: Text(result.title),
                      subtitle: Text(
                        ready ? result.subtitle : 'Coming soon',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      enabled: ready,
                      onTap: () {
                        Navigator.of(context).pop();
                        widget.onOpenModule(result.module.id);
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  List<_SearchResult> _search(String raw) {
    final query = raw.trim().toLowerCase();
    if (query.isEmpty) {
      return [
        for (final m in widget.permissions.visibleModules())
          _SearchResult(module: m, title: m.title, subtitle: m.tagline),
      ];
    }

    final results = <_SearchResult>[];
    for (final module in widget.permissions.visibleModules()) {
      final matchesModule =
          module.title.toLowerCase().contains(query) ||
          module.tagline.toLowerCase().contains(query);

      if (matchesModule) {
        results.add(
          _SearchResult(
            module: module,
            title: module.title,
            subtitle: module.tagline,
          ),
        );
      }

      for (final feature in widget.permissions.grantedFeatures(module)) {
        if (!feature.label.toLowerCase().contains(query)) continue;
        results.add(
          _SearchResult(
            module: module,
            title: feature.label,
            subtitle: 'in ${module.displayName}',
          ),
        );
      }
    }
    return results;
  }
}

class _SearchResult {
  const _SearchResult({
    required this.module,
    required this.title,
    required this.subtitle,
  });

  final ModuleDescriptor module;
  final String title;
  final String subtitle;
}

/// The full module catalog opened from the primary Modules tab.
class ModuleListSheet extends StatelessWidget {
  const ModuleListSheet({
    super.key,
    required this.permissions,
    required this.onOpenModule,
  });

  final EffectivePermissions permissions;
  final ValueChanged<String> onOpenModule;

  @override
  Widget build(BuildContext context) {
    final modules = ModuleCatalog.all;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      itemCount: modules.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final module = modules[index];
        final available =
            module.status != ModuleStatus.planned &&
            permissions.canSeeModule(module.id);
        final hasAccess = permissions.canSeeModule(module.id);
        return _ModuleListCard(
          module: module,
          available: available,
          subtitle: module.status == ModuleStatus.planned
              ? 'Coming soon'
              : hasAccess
              ? module.tagline
              : 'Not enabled for your account',
          onTap: available
              ? () {
                  Navigator.of(context).pop();
                  onOpenModule(module.id);
                }
              : null,
        );
      },
    );
  }
}

class _ModuleListCard extends StatelessWidget {
  const _ModuleListCard({
    required this.module,
    required this.available,
    required this.subtitle,
    required this.onTap,
  });

  final ModuleDescriptor module;
  final bool available;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = available ? module.color : AppColors.muted;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(module.icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      module.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: available
                            ? AppColors.muted
                            : AppColors.muted.withValues(alpha: 0.8),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                available ? Icons.chevron_right : Icons.lock_outline,
                color: AppColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The full ranked insight list, so the rotating card on the home screen is
/// not the only way to reach one that has already scrolled past.
class InsightListSheet extends StatelessWidget {
  const InsightListSheet({super.key, required this.insights, this.emptyText});

  final List<Insight> insights;
  final String? emptyText;

  @override
  Widget build(BuildContext context) {
    if (insights.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        child: Text(
          emptyText ?? 'Nothing needs your attention right now.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      itemCount: insights.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final insight = insights[i];
        final accent = toneColor(insight.tone);

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accent.withValues(alpha: 0.22)),
          ),
          child: Row(
            children: [
              Icon(insight.icon, color: accent, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      insight.headline,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (insight.supporting != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        insight.supporting!,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ],
                ),
              ),
              if (insight.metric != null)
                Text(
                  insight.metric!.label,
                  style: TextStyle(
                    color: accent,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

Color toneColor(InsightTone tone) => switch (tone) {
  InsightTone.positive => AppColors.success,
  InsightTone.caution => const Color(0xFFB77500),
  InsightTone.urgent => const Color(0xFFC62828),
  InsightTone.neutral => AppColors.violet,
};

/// Who you are signed in as, and the way out.
class ProfileSheet extends StatelessWidget {
  const ProfileSheet({
    super.key,
    required this.session,
    required this.permissions,
    required this.onOpenModule,
    required this.onSignOut,
  });

  final UserSession session;
  final EffectivePermissions permissions;
  final ValueChanged<String> onOpenModule;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final modules = permissions.visibleModules();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        _ProfileIdentityCard(session: session, modules: modules.length),
        const SizedBox(height: 16),
        _ProfileAction(
          icon: Icons.badge_outlined,
          title: 'Digital ID card',
          subtitle: 'Your campus identity and credentials',
          onTap: () => _openProfileDetail(
            context,
            title: 'Digital ID card',
            icon: Icons.badge_outlined,
            items: [
              _ProfileDetailItem('Name', session.displayName),
              _ProfileDetailItem('Student ID', session.idNumber ?? 'SC2600142'),
              _ProfileDetailItem('Email', session.email),
              _ProfileDetailItem(
                'Department',
                session.departmentOrWard ?? 'Computer Science',
              ),
              const _ProfileDetailItem('Status', 'Active student'),
            ],
          ),
        ),
        _ProfileAction(
          icon: Icons.school_outlined,
          title: 'Academic history',
          subtitle: 'Programme, semester and performance',
          onTap: () => _openProfileDetail(
            context,
            title: 'Academic history',
            icon: Icons.school_outlined,
            items: const [
              _ProfileDetailItem('Programme', 'B.Tech Computer Science'),
              _ProfileDetailItem('Current semester', 'Semester 6'),
              _ProfileDetailItem('Section', 'CS-3A'),
              _ProfileDetailItem('Academic year', '2025–2026'),
              _ProfileDetailItem('Current CGPA', '8.42'),
            ],
          ),
        ),
        _ProfileAction(
          icon: Icons.folder_copy_outlined,
          title: 'Documents and certificates',
          subtitle: 'Submitted documents and generated certificates',
          onTap: () => _openProfileDetail(
            context,
            title: 'Documents and certificates',
            icon: Icons.folder_copy_outlined,
            items: const [
              _ProfileDetailItem(
                'Bonafide certificate',
                'Available to generate',
              ),
              _ProfileDetailItem('Transfer certificate', 'Verified'),
              _ProfileDetailItem('Semester 5 marksheet', 'Verified'),
              _ProfileDetailItem('Student ID proof', 'Verified'),
            ],
          ),
        ),
        _ProfileAction(
          icon: Icons.contact_emergency_outlined,
          title: 'Emergency contacts',
          subtitle: 'People to contact in an emergency',
          onTap: () => _openProfileDetail(
            context,
            title: 'Emergency contacts',
            icon: Icons.contact_emergency_outlined,
            items: const [
              _ProfileDetailItem('Primary contact', 'Robert Johnson'),
              _ProfileDetailItem('Relationship', 'Parent'),
              _ProfileDetailItem('Phone', '+91 98765 43210'),
              _ProfileDetailItem('Address', 'Bengaluru, Karnataka'),
            ],
          ),
        ),
        _ProfileAction(
          icon: Icons.family_restroom_outlined,
          title: 'Parents details',
          subtitle: 'Parent and guardian information',
          onTap: () => _openProfileDetail(
            context,
            title: 'Parents details',
            icon: Icons.family_restroom_outlined,
            items: const [
              _ProfileDetailItem('Parent / guardian', 'Robert Johnson'),
              _ProfileDetailItem('Email', 'robert.johnson@example.com'),
              _ProfileDetailItem('Mobile', '+91 98765 43210'),
              _ProfileDetailItem('Portal access', 'Enabled'),
            ],
          ),
        ),
        _ProfileAction(
          icon: Icons.medical_information_outlined,
          title: 'Medical information',
          subtitle: 'Health details shared with the institution',
          onTap: () => _openProfileDetail(
            context,
            title: 'Medical information',
            icon: Icons.medical_information_outlined,
            items: const [
              _ProfileDetailItem('Blood group', 'O positive'),
              _ProfileDetailItem('Allergies', 'None reported'),
              _ProfileDetailItem('Insurance', 'Campus coverage active'),
              _ProfileDetailItem('Emergency note', 'No special instructions'),
            ],
          ),
        ),
        _ProfileAction(
          icon: Icons.history,
          title: 'Activity history',
          subtitle: 'Recent module access and updates',
          onTap: () => _openProfileDetail(
            context,
            title: 'Activity history',
            icon: Icons.history,
            items: const [
              _ProfileDetailItem('Today', 'Library pass created'),
              _ProfileDetailItem('Yesterday', 'Canteen order placed'),
              _ProfileDetailItem('08 Aug 2026', 'Gatepass request submitted'),
            ],
          ),
        ),
        _ProfileAction(
          icon: Icons.notifications_outlined,
          title: 'Notifications',
          subtitle: 'Alerts, reminders and announcements',
          onTap: () {},
        ),
        _ProfileAction(
          icon: Icons.event_available_outlined,
          title: 'Leave applications',
          subtitle: 'Apply for leave and track approval status',
          onTap: () => _openLeaveApplications(context),
        ),
        _ProfileAction(
          icon: Icons.lock_outline,
          title: 'Privacy and security',
          subtitle: 'Password, sessions and account safety',
          onTap: () {},
        ),
        _ProfileAction(
          icon: Icons.feedback_outlined,
          title: 'Feedback',
          subtitle: 'Share feedback or raise a concern',
          onTap: () {
            Navigator.of(context).pop();
            onOpenModule('feedback');
          },
        ),
        _ProfileAction(
          icon: Icons.help_outline,
          title: 'Help and support',
          subtitle: 'Create and track a campus support ticket',
          onTap: () => _openHelpdesk(context),
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          key: const ValueKey('profile-sign-out'),
          onPressed: () {
            Navigator.of(context).pop();
            onSignOut();
          },
          icon: const Icon(Icons.logout),
          label: const Text('Sign out'),
        ),
      ],
    );
  }
}

void _openHelpdesk(BuildContext context) => showHomeSheet(
  context: context,
  title: 'Helpdesk',
  expand: true,
  child: const _HelpdeskSheet(),
);

class _SupportTicket {
  const _SupportTicket(
    this.category,
    this.subject,
    this.description,
    this.status,
  );
  final String category;
  final String subject;
  final String description;
  final String status;
}

class _HelpdeskSheet extends StatefulWidget {
  const _HelpdeskSheet();

  @override
  State<_HelpdeskSheet> createState() => _HelpdeskSheetState();
}

class _HelpdeskSheetState extends State<_HelpdeskSheet> {
  final _tickets = <_SupportTicket>[
    const _SupportTicket(
      'Library access',
      'QR pass not appearing',
      'My booked library pass was delayed.',
      'In review',
    ),
    const _SupportTicket(
      'Canteen and payments',
      'Wallet top-up query',
      'Please verify a wallet transaction.',
      'Resolved',
    ),
  ];

  Future<void> _createTicket() async {
    final ticket = await showModalBottomSheet<_SupportTicket>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (_) => const _CreateSupportTicketSheet(),
    );
    if (ticket != null && mounted) setState(() => _tickets.insert(0, ticket));
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
    children: [
      FilledButton.icon(
        onPressed: _createTicket,
        icon: const Icon(Icons.add),
        label: const Text('Create support ticket'),
      ),
      const SizedBox(height: 18),
      const Text(
        'MY TICKETS',
        style: TextStyle(
          color: AppColors.muted,
          letterSpacing: 1.2,
          fontSize: 11,
        ),
      ),
      const SizedBox(height: 10),
      for (final ticket in _tickets) ...[
        _SupportTicketCard(ticket: ticket),
        const SizedBox(height: 10),
      ],
    ],
  );
}

class _SupportTicketCard extends StatelessWidget {
  const _SupportTicketCard({required this.ticket});
  final _SupportTicket ticket;

  @override
  Widget build(BuildContext context) {
    final color = ticket.status == 'Resolved'
        ? AppColors.success
        : const Color(0xFFB77500);
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  ticket.subject,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Chip(
                label: Text(ticket.status),
                labelStyle: TextStyle(color: color, fontSize: 11),
                backgroundColor: color.withValues(alpha: .1),
                side: BorderSide.none,
              ),
            ],
          ),
          Text(ticket.category, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 4),
          Text(
            ticket.description,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _CreateSupportTicketSheet extends StatefulWidget {
  const _CreateSupportTicketSheet();

  @override
  State<_CreateSupportTicketSheet> createState() =>
      _CreateSupportTicketSheetState();
}

class _CreateSupportTicketSheetState extends State<_CreateSupportTicketSheet> {
  final _subject = TextEditingController();
  final _description = TextEditingController();
  var _category = 'Technical support';

  @override
  void dispose() {
    _subject.dispose();
    _description.dispose();
    super.dispose();
  }

  void _submit() {
    if (_subject.text.trim().isEmpty || _description.text.trim().isEmpty) {
      return;
    }
    Navigator.of(context).pop(
      _SupportTicket(
        _category,
        _subject.text.trim(),
        _description.text.trim(),
        'Submitted',
      ),
    );
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'New support ticket',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: const [
                DropdownMenuItem(
                  value: 'Technical support',
                  child: Text('Technical support'),
                ),
                DropdownMenuItem(
                  value: 'Library access',
                  child: Text('Library access'),
                ),
                DropdownMenuItem(
                  value: 'Canteen and payments',
                  child: Text('Canteen and payments'),
                ),
                DropdownMenuItem(
                  value: 'ID card and documents',
                  child: Text('ID card and documents'),
                ),
              ],
              onChanged: (value) =>
                  setState(() => _category = value ?? _category),
            ),
            TextField(
              controller: _subject,
              decoration: const InputDecoration(labelText: 'Subject'),
            ),
            TextField(
              controller: _description,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Describe the issue',
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _submit,
              child: const Text('Submit ticket'),
            ),
          ],
        ),
      ),
    ),
  );
}

void _openLeaveApplications(BuildContext context) => showHomeSheet(
  context: context,
  title: 'Leave applications',
  expand: true,
  child: const _StudentLeaveSheet(),
);

class _StudentLeaveRequest {
  const _StudentLeaveRequest(
    this.type,
    this.start,
    this.end,
    this.reason,
    this.status,
  );
  final String type;
  final DateTime start;
  final DateTime end;
  final String reason;
  final String status;
}

class _StudentLeaveSheet extends StatefulWidget {
  const _StudentLeaveSheet();
  @override
  State<_StudentLeaveSheet> createState() => _StudentLeaveSheetState();
}

class _StudentLeaveSheetState extends State<_StudentLeaveSheet> {
  final _requests = <_StudentLeaveRequest>[
    _StudentLeaveRequest(
      'Medical leave',
      DateTime(2026, 8, 12),
      DateTime(2026, 8, 13),
      'Medical appointment',
      'Approved',
    ),
    _StudentLeaveRequest(
      'Personal leave',
      DateTime(2026, 8, 20),
      DateTime(2026, 8, 20),
      'Family commitment',
      'Pending',
    ),
  ];

  Future<void> _create() async {
    final request = await showModalBottomSheet<_StudentLeaveRequest>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (_) => const _CreateLeaveSheet(),
    );
    if (request != null && mounted) {
      setState(() => _requests.insert(0, request));
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
    children: [
      FilledButton.icon(
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: const Text('Apply for leave'),
      ),
      const SizedBox(height: 18),
      const Text(
        'REQUEST HISTORY',
        style: TextStyle(
          color: AppColors.muted,
          letterSpacing: 1.2,
          fontSize: 11,
        ),
      ),
      const SizedBox(height: 10),
      for (final request in _requests) ...[
        _LeaveRequestCard(request: request),
        const SizedBox(height: 10),
      ],
    ],
  );
}

class _LeaveRequestCard extends StatelessWidget {
  const _LeaveRequestCard({required this.request});
  final _StudentLeaveRequest request;

  @override
  Widget build(BuildContext context) {
    final color = request.status == 'Approved'
        ? AppColors.success
        : const Color(0xFFB77500);
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  request.type,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Chip(
                label: Text(request.status),
                labelStyle: TextStyle(color: color, fontSize: 11),
                backgroundColor: color.withValues(alpha: .1),
                side: BorderSide.none,
              ),
            ],
          ),
          Text('${_date(request.start)} – ${_date(request.end)}'),
          const SizedBox(height: 4),
          Text(request.reason, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }

  String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
}

class _CreateLeaveSheet extends StatefulWidget {
  const _CreateLeaveSheet();
  @override
  State<_CreateLeaveSheet> createState() => _CreateLeaveSheetState();
}

class _CreateLeaveSheetState extends State<_CreateLeaveSheet> {
  final _reason = TextEditingController();
  var _type = 'Personal leave';
  var _start = DateTime.now().add(const Duration(days: 1));
  var _end = DateTime.now().add(const Duration(days: 1));

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _pick(bool end) async {
    final value = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: end ? _end : _start,
    );
    if (value == null) return;
    setState(() {
      if (end) {
        _end = value;
      } else {
        _start = value;
        if (_end.isBefore(value)) _end = value;
      }
    });
  }

  void _submit() {
    if (_reason.text.trim().isEmpty) return;
    Navigator.of(context).pop(
      _StudentLeaveRequest(_type, _start, _end, _reason.text.trim(), 'Pending'),
    );
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'New leave application',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Leave type'),
              items: const [
                DropdownMenuItem(
                  value: 'Personal leave',
                  child: Text('Personal leave'),
                ),
                DropdownMenuItem(
                  value: 'Medical leave',
                  child: Text('Medical leave'),
                ),
                DropdownMenuItem(
                  value: 'On-duty leave',
                  child: Text('On-duty leave'),
                ),
              ],
              onChanged: (value) => setState(() => _type = value ?? _type),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => _pick(false),
              icon: const Icon(Icons.calendar_today_outlined),
              label: Text('Start: ${_date(_start)}'),
            ),
            OutlinedButton.icon(
              onPressed: () => _pick(true),
              icon: const Icon(Icons.event_outlined),
              label: Text('End: ${_date(_end)}'),
            ),
            TextField(
              controller: _reason,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Reason'),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _submit,
              child: const Text('Submit application'),
            ),
          ],
        ),
      ),
    ),
  );

  String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
}

void _openProfileDetail(
  BuildContext context, {
  required String title,
  required IconData icon,
  required List<_ProfileDetailItem> items,
}) {
  showHomeSheet(
    context: context,
    title: title,
    expand: true,
    child: _ProfileDetailSheet(icon: icon, items: items),
  );
}

class _ProfileDetailItem {
  const _ProfileDetailItem(this.label, this.value);

  final String label;
  final String value;
}

class _ProfileDetailSheet extends StatelessWidget {
  const _ProfileDetailSheet({required this.icon, required this.items});

  final IconData icon;
  final List<_ProfileDetailItem> items;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = items[index];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.canvas,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.violet, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.value,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProfileIdentityCard extends StatelessWidget {
  const _ProfileIdentityCard({required this.session, required this.modules});

  final UserSession session;
  final int modules;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.violet, AppColors.violetBright],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
            ),
            child: Text(
              initialsOf(session.displayName),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  session.email,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.82)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _ProfileChip(text: session.roleLabel),
                    if (session.idNumber != null)
                      _ProfileChip(text: session.idNumber!),
                    _ProfileChip(text: '$modules modules'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileChip extends StatelessWidget {
  const _ProfileChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }
}

class _ProfileAction extends StatelessWidget {
  const _ProfileAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.violet.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: AppColors.violet, size: 21),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodyMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Up to two initials, e.g. `Alex Johnson` -> `AJ`.
String initialsOf(String name) {
  final parts = name
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty && RegExp(r'[A-Za-z]').hasMatch(p))
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
      .toUpperCase();
}
