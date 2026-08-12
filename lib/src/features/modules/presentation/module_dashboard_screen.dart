import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/access/effective_permissions.dart';
import '../../../core/access/module_catalog.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/slice_nav_bar.dart';
import '../../authentication/data/auth_repository.dart';
import '../../faculty/data/faculty_models.dart';
import '../../faculty/data/mock_faculty_repository.dart';
import '../../insights/data/insight.dart';
import 'module_stack.dart';
import 'widgets/home_sheets.dart';
import 'widgets/home_top_bar.dart';

/// One portal for every user. The module list is a projection of
/// [EffectivePermissions] over [ModuleCatalog] — there are no role checks in
/// this file. Granting a module in the admin console makes a bar appear;
/// changing the granted actions changes what it says.
///
/// The page scrolls under a floating [SliceNavBar], which collapses to the
/// scan button as you read down and reopens as you come back up.
class ModuleDashboardScreen extends StatefulWidget {
  const ModuleDashboardScreen({
    super.key,
    required this.session,
    required this.permissions,
    required this.onOpenModule,
    required this.onSignOut,
    required this.onThemeModeChanged,
    this.onQuickAction,
    this.onScan,
    this.dashboard,
  });

  final UserSession session;
  final EffectivePermissions permissions;
  final ValueChanged<String> onOpenModule;
  final VoidCallback onSignOut;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final void Function(
    String moduleId,
    String actionId,
    String featureId,
    String requiredAction,
  )?
  onQuickAction;

  /// The scan button in the middle of the nav bar. Hidden when null. Takes
  /// the caller's context so the owner of navigation can push the scanner
  /// without this screen knowing what a scanner is.
  final void Function(BuildContext context)? onScan;

  /// Replaces the insight surface below the greeting.
  final Widget? dashboard;

  @override
  State<ModuleDashboardScreen> createState() => _ModuleDashboardScreenState();
}

class _ModuleDashboardScreenState extends State<ModuleDashboardScreen> {
  bool _navCollapsed = false;
  List<Insight> _insights = const [];

  /// Reading down closes the bar, coming back up reopens it. Driven by the
  /// gesture direction rather than by the offset, so a short page that only
  /// scrolls a little still behaves the same as a long one.
  bool _onScroll(UserScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;

    final collapsed = switch (notification.direction) {
      ScrollDirection.reverse => true,
      ScrollDirection.forward => false,
      ScrollDirection.idle => _navCollapsed,
    };

    if (collapsed != _navCollapsed) setState(() => _navCollapsed = collapsed);
    return false;
  }

  List<Insight> get _alerts => [
    for (final i in _insights)
      if (i.tone == InsightTone.caution || i.tone == InsightTone.urgent) i,
  ];

  @override
  Widget build(BuildContext context) {
    final modules = widget.permissions.visibleModules();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                HomeTopBar(
                  onSparkleTap: _openInsights,
                  onSearchTap: _openSearch,
                  onAlertsTap: _openAlerts,
                  hasAlerts: _alerts.isNotEmpty,
                ),
                Expanded(
                  child: Stack(
                    children: [
                      NotificationListener<UserScrollNotification>(
                        onNotification: _onScroll,
                        child: _Feed(
                          session: widget.session,
                          permissions: widget.permissions,
                          modules: modules,
                          dashboard: widget.dashboard,
                          onOpenModule: widget.onOpenModule,
                          onQuickAction: widget.onQuickAction,
                          onInsightsChanged: (insights) {
                            if (mounted) setState(() => _insights = insights);
                          },
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: MediaQuery.paddingOf(context).bottom + 10,
                        child: SliceNavBar(
                          destinations: _destinations(),
                          selectedId: 'home',
                          onSelect: (id) {
                            if (id == 'home') return;
                            if (id == 'profile') {
                              _openProfile();
                              return;
                            }
                            if (id == 'modules') {
                              _openModules();
                              return;
                            }
                            widget.onOpenModule(id);
                          },
                          onCenterTap: widget.onScan == null
                              ? null
                              : () => widget.onScan!(context),
                          centerTooltip: 'Scanner',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Fixed primary navigation for the student portal.
  List<SliceNavDestination> _destinations() => const [
    SliceNavDestination(id: 'home', label: 'Home', icon: Icons.home_rounded),
    SliceNavDestination(
      id: ModuleCatalog.academics,
      label: 'Academics',
      icon: Icons.school_outlined,
    ),
    SliceNavDestination(
      id: 'modules',
      label: 'Modules',
      icon: Icons.grid_view_rounded,
    ),
    SliceNavDestination(
      id: 'profile',
      label: 'Profile',
      icon: Icons.person_outline,
    ),
  ];

  void _openSearch() => showHomeSheet(
    context: context,
    title: 'Search',
    expand: true,
    child: CampusSearchSheet(
      permissions: widget.permissions,
      onOpenModule: widget.onOpenModule,
    ),
  );

  void _openInsights() => showHomeSheet(
    context: context,
    title: 'What matters now',
    child: InsightListSheet(
      insights: _insights,
      emptyText: 'Nothing to report yet — check back after your first class.',
    ),
  );

  void _openAlerts() => showHomeSheet(
    context: context,
    title: 'Alerts',
    child: InsightListSheet(
      insights: _alerts,
      emptyText: 'You are all clear. Nothing needs attention.',
    ),
  );

  void _openProfile() => showHomeSheet(
    context: context,
    title: 'Profile',
    expand: true,
    child: ProfileSheet(
      session: widget.session,
      permissions: widget.permissions,
      onOpenModule: widget.onOpenModule,
      onSignOut: widget.onSignOut,
      onThemeModeChanged: widget.onThemeModeChanged,
    ),
  );

  void _openModules() => showHomeSheet(
    context: context,
    title: 'Modules',
    expand: true,
    child: ModuleListSheet(
      permissions: widget.permissions,
      onOpenModule: widget.onOpenModule,
    ),
  );
}

class _Feed extends StatelessWidget {
  const _Feed({
    required this.session,
    required this.permissions,
    required this.modules,
    required this.dashboard,
    required this.onOpenModule,
    this.onQuickAction,
    required this.onInsightsChanged,
  });

  final UserSession session;
  final EffectivePermissions permissions;
  final List<ModuleDescriptor> modules;
  final Widget? dashboard;
  final ValueChanged<String> onOpenModule;
  final void Function(
    String moduleId,
    String actionId,
    String featureId,
    String requiredAction,
  )?
  onQuickAction;
  final ValueChanged<List<Insight>> onInsightsChanged;

  @override
  Widget build(BuildContext context) {
    final planned = [
      for (final m in ModuleCatalog.all)
        if (m.status == ModuleStatus.planned && !modules.contains(m)) m,
    ];

    return ListView(
      padding: EdgeInsets.fromLTRB(
        0,
        4,
        0,
        SliceNavBar.height + MediaQuery.paddingOf(context).bottom + 20,
      ),
      children: [
        _Greeting(session: session),
        SizedBox(
          height: 154,
          child:
              dashboard ??
              _PriorityDashboardCard(
                session: session,
                permissions: permissions,
                onOpenModule: onOpenModule,
                onQuickAction: onQuickAction,
              ),
        ),
        const SizedBox(height: 22),
        if (modules.isEmpty)
          const _NoAccessState()
        else ...[
          const _SectionLabel('Your modules'),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 8, 0),
            child: ModuleStack(
              modules: modules,
              permissions: permissions,
              onOpenModule: onOpenModule,
              onQuickAction: onQuickAction,
            ),
          ),
          const SizedBox(height: 24),
          _DashboardOverview(
            permissions: permissions,
            onOpenModule: onOpenModule,
          ),
        ],
        if (planned.isNotEmpty) ...[
          const SizedBox(height: 26),
          const _SectionLabel('Coming next'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                for (final m in planned) ...[
                  Expanded(child: _PlannedTile(module: m)),
                  if (m != planned.last) const SizedBox(width: 12),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _DashboardOverview extends StatelessWidget {
  const _DashboardOverview({
    required this.permissions,
    required this.onOpenModule,
  });

  final EffectivePermissions permissions;
  final ValueChanged<String> onOpenModule;

  @override
  Widget build(BuildContext context) {
    final brandPrimary = Theme.of(context).colorScheme.primary;
    final brandSecondary = Theme.of(context).colorScheme.secondary;
    final items = <_OverviewItem>[
      if (permissions.can(
        ModuleCatalog.academics,
        'attendance',
        ModuleActions.read,
      ))
        _OverviewItem(
          moduleId: ModuleCatalog.academics,
          icon: Icons.fact_check_outlined,
          label: 'Attendance',
          value: '74%',
          detail: 'Current semester',
          color: brandPrimary,
        ),
      if (!permissions.can(
            ModuleCatalog.academics,
            'attendance',
            ModuleActions.read,
          ) &&
          permissions.can(
            ModuleCatalog.attendance,
            'roster',
            ModuleActions.read,
          ))
        _OverviewItem(
          moduleId: ModuleCatalog.attendance,
          icon: Icons.fact_check_outlined,
          label: 'Attendance roster',
          value: '3 pending',
          detail: 'Needs review',
          color: brandPrimary,
        ),
      if (permissions.can(
        ModuleCatalog.timetable,
        'schedule',
        ModuleActions.read,
      ))
        _OverviewItem(
          moduleId: ModuleCatalog.timetable,
          icon: Icons.calendar_today_outlined,
          label: 'Next class',
          value: '11:00 AM',
          detail: 'Microwave Engineering',
          color: brandSecondary,
        ),
      if (permissions.can(
        ModuleCatalog.examination,
        'grades',
        ModuleActions.read,
      ))
        _OverviewItem(
          moduleId: ModuleCatalog.examination,
          icon: Icons.school_outlined,
          label: 'Current CGPA',
          value: '8.42',
          detail: 'Semester 6 results',
          color: brandPrimary,
        ),
      if (permissions.can(
        ModuleCatalog.gatepass,
        'outpass',
        ModuleActions.read,
      ))
        _OverviewItem(
          moduleId: ModuleCatalog.gatepass,
          icon: Icons.directions_walk_outlined,
          label: 'Gatepass',
          value: '1 pending',
          detail: 'Request status',
          color: brandSecondary,
        ),
      if (permissions.can(ModuleCatalog.canteen, 'order', ModuleActions.read))
        _OverviewItem(
          moduleId: ModuleCatalog.canteen,
          icon: Icons.restaurant_outlined,
          label: 'Canteen order',
          value: 'Ready',
          detail: 'Pickup status',
          color: brandPrimary,
        ),
      if (permissions.can(ModuleCatalog.library, 'qr_pass', ModuleActions.read))
        _OverviewItem(
          moduleId: ModuleCatalog.library,
          icon: Icons.local_library_outlined,
          label: 'Library pass',
          value: 'Active',
          detail: 'Today\'s access',
          color: brandSecondary,
        ),
      if (permissions.can(
        ModuleCatalog.vendorManagement,
        'purchase_orders',
        ModuleActions.read,
      ))
        _OverviewItem(
          moduleId: ModuleCatalog.vendorManagement,
          icon: Icons.receipt_long_outlined,
          label: 'Purchase orders',
          value: '4 open',
          detail: 'Vendor workflow',
          color: brandPrimary,
        ),
      if (permissions.can(
        ModuleCatalog.tuitionFee,
        'invoice',
        ModuleActions.read,
      ))
        _OverviewItem(
          moduleId: ModuleCatalog.tuitionFee,
          icon: Icons.account_balance_outlined,
          label: 'Fee balance',
          value: '₹18,500',
          detail: 'Due this term',
          color: brandSecondary,
        ),
    ];

    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Today at a glance'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              mainAxisExtent: 140,
            ),
            itemBuilder: (context, index) {
              final item = items[index];
              return _OverviewCard(
                item: item,
                onTap: () => onOpenModule(item.moduleId),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _OverviewItem {
  const _OverviewItem({
    required this.moduleId,
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
    required this.color,
  });

  final String moduleId;
  final IconData icon;
  final String label;
  final String value;
  final String detail;
  final Color color;
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.item, required this.onTap});

  final _OverviewItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(item.icon, color: item.color, size: 21),
              const Spacer(),
              Text(
                item.label,
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                item.value,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: item.color,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                item.detail,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PriorityDashboardCard extends StatelessWidget {
  const _PriorityDashboardCard({
    required this.session,
    required this.permissions,
    required this.onOpenModule,
    required this.onQuickAction,
  });

  final UserSession session;
  final EffectivePermissions permissions;
  final ValueChanged<String> onOpenModule;
  final void Function(
    String moduleId,
    String actionId,
    String featureId,
    String requiredAction,
  )?
  onQuickAction;

  @override
  Widget build(BuildContext context) {
    final notices = MockFacultyRepository().getNotices();
    final notice = notices.isEmpty ? null : notices.first;
    final scheme = Theme.of(context).colorScheme;
    final postedAt = notice?.postedAt.toLocal();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
      child: Material(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.72),
        clipBehavior: Clip.none,
        child: InkWell(
          onTap: notice == null ? null : () => _openNoticePdf(context, notice),
          child: Row(
            children: [
              Container(
                width: 64,
                height: double.infinity,
                color: scheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.campaign_outlined,
                      color: scheme.onPrimary,
                      size: 20,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      postedAt == null
                          ? 'NEW'
                          : postedAt.day.toString().padLeft(2, '0'),
                      style: TextStyle(
                        color: scheme.onPrimary,
                        fontSize: 18,
                        height: 1,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      postedAt == null ? 'UPDATE' : _monthName(postedAt.month),
                      style: TextStyle(
                        color: scheme.onPrimary.withValues(alpha: 0.76),
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notice?.title ?? 'No new announcements',
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontSize: 16,
                          height: 1.15,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        notice?.content ??
                            'You are all caught up. New notices will appear here.',
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 12,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Text(
                            notice?.pdfUrl == null
                                ? 'View update'
                                : 'View details',
                            style: TextStyle(
                              color: scheme.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 3),
                          Icon(
                            Icons.arrow_forward_rounded,
                            color: scheme.primary,
                            size: 14,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* Legacy announcement layout removed.
              const Text(
                'ANNOUNCEMENT',
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 10,
                  letterSpacing: 1.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                notice?.title ?? 'No new announcements',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 9),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            notice?.content ??
                                'You are all caught up. New notices will appear here.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.82),
                              fontSize: 12,
                              height: 1.35,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            notice == null
                                ? 'Management notices'
                                : '${notice.author}  ·  ${_formatNoticeDate(notice.postedAt)}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.58),
                              fontSize: 10.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Visibility(
                            visible: false,
                            child: Text(
                              'Attendance is 74% · next class 11:00 AM',
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (notice?.pdfUrl != null) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Open notice PDF',
                        onPressed: () => _openNoticePdf(context, notice!),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white12,
                          shape: const CircleBorder(),
                          padding: const EdgeInsets.all(9),
                        ),
                        icon: const Icon(
                          Icons.picture_as_pdf_outlined,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
String _formatNoticeDate(DateTime date) {
*/

String _monthName(int month) => const [
  '',
  'JAN',
  'FEB',
  'MAR',
  'APR',
  'MAY',
  'JUN',
  'JUL',
  'AUG',
  'SEP',
  'OCT',
  'NOV',
  'DEC',
][month.clamp(1, 12).toInt()];

Future<void> _openNoticePdf(
  BuildContext context,
  DepartmentNotice notice,
) async {
  final url = notice.pdfUrl;
  if (url == null) return;

  final opened = await launchUrl(
    Uri.parse(url),
    mode: LaunchMode.externalApplication,
  );
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Unable to open this notice PDF.')),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: AppColors.muted,
          fontSize: 11,
          fontWeight: FontWeight.w500,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _PlannedTile extends StatelessWidget {
  const _PlannedTile({required this.module});

  final ModuleDescriptor module;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 96,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(module.icon, color: AppColors.muted, size: 22),
          const Spacer(),
          Text(
            module.displayName,
            style: Theme.of(context).textTheme.titleMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            'Coming soon',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.session});

  final UserSession session;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 14),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: 'Good ${_dayPart()}, '),
            TextSpan(
              text: session.displayName.split(' ').first,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        style: Theme.of(context).textTheme.titleLarge,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  String _dayPart() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    return 'Evening';
  }
}

class _NoAccessState extends StatelessWidget {
  const _NoAccessState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 40, color: AppColors.muted),
            const SizedBox(height: 14),
            Text(
              'No modules assigned',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Your administrator has not granted access to any '
              'campus service yet.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
