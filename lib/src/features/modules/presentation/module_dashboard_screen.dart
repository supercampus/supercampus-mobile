import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../core/access/effective_permissions.dart';
import '../../../core/access/module_catalog.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/slice_nav_bar.dart';
import '../../authentication/data/auth_repository.dart';
import '../../insights/data/insight.dart';
import '../../insights/presentation/insight_dashboard.dart';
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
    this.onQuickAction,
    this.onScan,
    this.dashboard,
  });

  final UserSession session;
  final EffectivePermissions permissions;
  final ValueChanged<String> onOpenModule;
  final VoidCallback onSignOut;
  final void Function(String moduleId, String actionId)? onQuickAction;

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
      backgroundColor: AppColors.canvas,
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
  final void Function(String moduleId, String actionId)? onQuickAction;
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
          height: 108,
          child:
              dashboard ??
              InsightDashboard(
                permissions: permissions,
                onInsightsChanged: onInsightsChanged,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
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
              style: const TextStyle(
                color: AppColors.moduleAccent,
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
