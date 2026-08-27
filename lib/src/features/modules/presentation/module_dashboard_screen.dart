import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/access/academic_presentation.dart';
import '../../../core/access/effective_permissions.dart';
import '../../../core/access/module_catalog.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/campus_nav_bar.dart';
import '../../authentication/data/auth_repository.dart';
import '../../advisor/data/advisor_students_repository.dart';
import '../../advisor/presentation/advisor_students_section.dart';
import '../../faculty/data/faculty_models.dart';
import '../../faculty/data/mock_faculty_repository.dart';
import '../../insights/data/insight.dart';
import '../data/glance_source.dart';
import 'module_stack.dart';
import 'today_glance.dart';
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
    this.onOpenAttendanceClass,
    this.onScan,
    this.dashboard,
    this.glanceSource,
    this.advisorStudentsSource,
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
  final ValueChanged<TodayClass>? onOpenAttendanceClass;

  /// The scan button in the middle of the nav bar. Hidden when null. Takes
  /// the caller's context so the owner of navigation can push the scanner
  /// without this screen knowing what a scanner is.
  final void Function(BuildContext context)? onScan;

  /// Replaces the insight surface below the greeting.
  final Widget? dashboard;

  /// Supplies "your day". Null leaves the section empty rather than inventing
  /// numbers for it.
  final GlanceSource? glanceSource;
  final AdvisorStudentsSource? advisorStudentsSource;

  @override
  State<ModuleDashboardScreen> createState() => _ModuleDashboardScreenState();
}

class _ModuleDashboardScreenState extends State<ModuleDashboardScreen> {
  List<Insight> _insights = const [];
  GlanceFacts _glance = GlanceFacts.empty;
  String _selectedNavId = 'home';

  @override
  void initState() {
    super.initState();
    _loadGlance();
  }

  @override
  void didUpdateWidget(ModuleDashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Grants decide the shape, and the shape decides what is fetched, so a
    // permission change has to re-ask rather than keep the previous day.
    if (oldWidget.permissions != widget.permissions ||
        oldWidget.glanceSource != widget.glanceSource) {
      _loadGlance();
    }
  }

  Future<void> _loadGlance() async {
    final source = widget.glanceSource;
    if (source == null || !glanceNeedsLoading(widget.permissions)) {
      if (mounted) setState(() => _glance = GlanceFacts.empty);
      return;
    }
    setState(() => _glance = GlanceFacts.pending);
    final facts = await source.load(dayShapeFor(widget.permissions));
    if (mounted) setState(() => _glance = facts);
  }

  /// The insights that are asking for something, rather than just
  /// reporting. Only these put the dot on the bell.
  List<Insight> get _alerts => [
    for (final insight in _insights)
      if (insight.tone == InsightTone.urgent ||
          insight.tone == InsightTone.caution)
        insight,
  ];

  @override
  Widget build(BuildContext context) {
    final modules = presentedModules(widget.permissions);

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
                  onAlertsTap: _openAlerts,
                  hasAlerts: _alerts.isNotEmpty,
                ),
                Expanded(
                  child: Stack(
                    children: [
                      _Feed(
                        session: widget.session,
                        permissions: widget.permissions,
                        modules: modules,
                        dashboard: widget.dashboard,
                        onOpenModule: widget.onOpenModule,
                        onQuickAction: widget.onQuickAction,
                        onInsightsChanged: (insights) {
                          if (mounted) setState(() => _insights = insights);
                        },
                        glance: _glance,
                        advisorStudentsSource: widget.advisorStudentsSource,
                        onOpenAttendanceClass: widget.onOpenAttendanceClass,
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: MediaQuery.paddingOf(context).bottom + 10,
                        child: CampusNavBar(
                          selectedId: _selectedNavId,
                          initials: initialsOf(widget.session.displayName),
                          avatarUrl: widget.session.photoUrl,
                          onHome: () {},
                          onModules: _openModules,
                          onProfile: _openProfile,
                          onScan: widget.onScan == null
                              ? null
                              : () => widget.onScan!(context),
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

  Future<void> _openModules() async {
    setState(() => _selectedNavId = 'modules');
    await showHomeSheet(
      context: context,
      title: 'Modules',
      expand: true,
      child: ModuleListSheet(
        permissions: widget.permissions,
        onOpenModule: widget.onOpenModule,
      ),
    );
    if (mounted) setState(() => _selectedNavId = 'home');
  }
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
    required this.glance,
    required this.advisorStudentsSource,
    required this.onOpenAttendanceClass,
  });

  final UserSession session;
  final EffectivePermissions permissions;
  final List<ModuleDescriptor> modules;
  final GlanceFacts glance;
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
  final AdvisorStudentsSource? advisorStudentsSource;
  final ValueChanged<TodayClass>? onOpenAttendanceClass;

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
        CampusNavBar.heightFor(context) +
            MediaQuery.paddingOf(context).bottom +
            20,
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
              // The learner's standing is already loaded for the glance below,
              // so their streak costs no second request. Null until it lands,
              // which leaves the strip in its "not taken yet" state rather
              // than flashing a filled one it is about to correct.
              content: ModuleCardContent(
                attendanceMarks: glance.standing?.streak,
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (advisorStudentsSource != null) ...[
            AdvisorStudentsSection(source: advisorStudentsSource!),
            const SizedBox(height: 24),
          ],
          TodayGlance(
            permissions: permissions,
            facts: glance,
            onOpenModule: onOpenModule,
            onOpenClass: onOpenAttendanceClass,
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
    final cards = <_DashboardNotice>[
      if (notice != null)
        _DashboardNotice(
          eyebrow: 'ANNOUNCEMENT',
          title: notice.title,
          message: notice.content,
          icon: Icons.campaign_outlined,
          colors: const [AppColors.brandBlue, AppColors.brandMagenta],
          action: notice.pdfUrl == null ? 'View update' : 'View details',
          onTap: () => _openNoticePdf(context, notice),
        ),
      _DashboardNotice(
        eyebrow: 'FEE REMINDER',
        title: 'Semester fee window is open',
        message: 'Review your dues and complete payment before the due date.',
        icon: Icons.account_balance_wallet_outlined,
        colors: [AppColors.brandMagenta, AppColors.brandLavender],
        action: 'Check fees',
        onTap: () => onOpenModule(ModuleCatalog.tuitionFee),
      ),
      _DashboardNotice(
        eyebrow: 'CAMPUS EVENT',
        title: 'Innovation Day registrations',
        message: 'Teams can register projects and reserve a presentation slot.',
        icon: Icons.celebration_outlined,
        colors: [AppColors.brandLavender, AppColors.brandBlue],
        action: 'View event',
        onTap: () => showHomeSheet(
          context: context,
          title: 'Campus event',
          child: const Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 28),
            child: Text(
              'Innovation Day registrations are open. Teams can submit a project and reserve a presentation slot from the event desk.',
            ),
          ),
        ),
      ),
      _DashboardNotice(
        eyebrow: 'EXAM RESULTS',
        title: 'Internal assessment published',
        message: 'Your latest subject-wise marks are ready in Academics.',
        icon: Icons.workspace_premium_outlined,
        colors: [AppColors.brandBlue, AppColors.brandMagenta],
        action: 'View results',
        onTap: () => onOpenModule(ModuleCatalog.academics),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 52).clamp(280.0, 480.0);
        return ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
          physics: const BouncingScrollPhysics(),
          itemCount: cards.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, index) => SizedBox(
            width: cardWidth,
            child: _DashboardNoticeCard(notice: cards[index]),
          ),
        );
      },
    );
  }
}

class _DashboardNotice {
  const _DashboardNotice({
    required this.eyebrow,
    required this.title,
    required this.message,
    required this.icon,
    required this.colors,
    required this.action,
    this.onTap,
  });

  final String eyebrow;
  final String title;
  final String message;
  final IconData icon;
  final List<Color> colors;
  final String action;
  final VoidCallback? onTap;
}

class _DashboardNoticeCard extends StatelessWidget {
  const _DashboardNoticeCard({required this.notice});

  final _DashboardNotice notice;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: notice.colors,
          ),
          borderRadius: BorderRadius.circular(22),
        ),
        child: InkWell(
          onTap: notice.onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 13),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(17),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Icon(notice.icon, color: Colors.white, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        notice.eyebrow,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.72),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notice.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        notice.message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 11,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            notice.action,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 3),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 13,
                          ),
                        ],
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
