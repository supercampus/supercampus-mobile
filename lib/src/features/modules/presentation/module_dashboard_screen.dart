import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/access/effective_permissions.dart';
import '../../../core/access/module_catalog.dart';
import '../../../core/access/portal_module_presentation.dart';
import '../../../core/notifications/notification_deep_link.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/campus_nav_bar.dart';
import '../../../core/widgets/announcement_image_cropper.dart';
import '../../authentication/data/auth_repository.dart';
import '../../advisor/data/advisor_students_repository.dart';
import '../../advisor/presentation/advisor_students_section.dart';
import '../../faculty/data/faculty_models.dart';
import '../../faculty/data/mock_faculty_repository.dart';
import '../../insights/data/insight.dart';
import '../../library/data/librarian_repository.dart';
import '../../notifications/data/notification_repository.dart';
import '../../notifications/presentation/notification_inbox_sheet.dart';
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
    this.moduleOrder = const [],
    this.onModuleOrderChanged,
    this.onQuickAction,
    this.onOpenAttendanceClass,
    this.onScan,
    this.dashboard,
    this.glanceSource,
    this.glanceRevision = 0,
    this.advisorStudentsSource,
    this.notificationRepository,
    this.notificationRevision = 0,
    this.announcementRepository,
  });

  final UserSession session;
  final EffectivePermissions permissions;
  final ValueChanged<String> onOpenModule;
  final VoidCallback onSignOut;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final List<String> moduleOrder;
  final ValueChanged<List<String>>? onModuleOrderChanged;
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
  final int glanceRevision;
  final AdvisorStudentsSource? advisorStudentsSource;
  final NotificationRepository? notificationRepository;
  final int notificationRevision;
  final LibrarianRepository? announcementRepository;

  @override
  State<ModuleDashboardScreen> createState() => _ModuleDashboardScreenState();
}

class _ModuleDashboardScreenState extends State<ModuleDashboardScreen> {
  List<Insight> _insights = const [];
  GlanceFacts _glance = GlanceFacts.empty;
  String _selectedNavId = 'home';
  int _unreadNotifications = 0;

  @override
  void initState() {
    super.initState();
    _loadGlance();
    _loadNotifications();
  }

  @override
  void didUpdateWidget(ModuleDashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Grants decide the shape, and the shape decides what is fetched, so a
    // permission change has to re-ask rather than keep the previous day.
    if (oldWidget.permissions != widget.permissions) {
      _loadGlance(showLoading: true);
    } else if (oldWidget.glanceRevision != widget.glanceRevision) {
      _loadGlance(showLoading: false);
    }
    if (oldWidget.notificationRepository != widget.notificationRepository ||
        oldWidget.notificationRevision != widget.notificationRevision) {
      _loadNotifications();
    }
  }

  Future<void> _loadNotifications() async {
    final repository = widget.notificationRepository;
    if (repository == null) return;
    try {
      final inbox = await repository.inbox();
      if (mounted) setState(() => _unreadNotifications = inbox.unreadCount);
    } catch (_) {
      // Notification availability must never block the dashboard.
    }
  }

  Future<void> _loadGlance({bool showLoading = true}) async {
    final source = widget.glanceSource;
    if (source == null || !glanceNeedsLoading(widget.permissions)) {
      if (mounted) setState(() => _glance = GlanceFacts.empty);
      return;
    }
    // Keep the last truthful result visible for socket-driven invalidations.
    // Loading skeletons are useful only for the first load or a changed shape.
    if (showLoading) setState(() => _glance = GlanceFacts.pending);
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
    final modules = orderModules(
      portalModules(widget.session, widget.permissions),
      widget.moduleOrder,
    );

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
                  displayName: widget.session.displayName,
                  onAlertsTap: _openAlerts,
                  onSettingsTap: _openSettings,
                  hasAlerts: _alerts.isNotEmpty || _unreadNotifications > 0,
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
                        announcementRepository: widget.announcementRepository,
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

  void _openAlerts() {
    final repository = widget.notificationRepository;
    if (repository == null) {
      showHomeSheet(
        context: context,
        title: 'Alerts',
        child: InsightListSheet(
          insights: _alerts,
          emptyText: 'You are all clear. Nothing needs attention.',
        ),
      );
      return;
    }
    showHomeSheet(
      context: context,
      title: 'Notifications',
      expand: true,
      child: NotificationInboxSheet(
        repository: repository,
        onChanged: (inbox) {
          if (mounted) {
            setState(() => _unreadNotifications = inbox.unreadCount);
          }
        },
        onOpen: _openNotification,
      ),
    );
  }

  void _openNotification(AppNotification notification) {
    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
    final moduleId = notificationModuleId(
      deepLink: notification.deepLink,
      category: notification.category,
      preferAttendanceModule: widget.permissions.canSeeModule(
        ModuleCatalog.attendance,
      ),
    );
    if (moduleId != null && widget.permissions.canSeeModule(moduleId)) {
      widget.onOpenModule(moduleId);
    }
    _loadNotifications();
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.w600)),
            leading: const BackButton(),
          ),
          body: SettingsSheet(
            onOpenModule: widget.onOpenModule,
            onSignOut: widget.onSignOut,
            onThemeModeChanged: widget.onThemeModeChanged,
            modules: portalModules(widget.session, widget.permissions),
            moduleOrder: widget.moduleOrder,
            onModuleOrderChanged: widget.onModuleOrderChanged,
          ),
        ),
      ),
    );
  }

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
      moduleOrder: widget.moduleOrder,
      onModuleOrderChanged: widget.onModuleOrderChanged,
    ),
  );

  Future<void> _openModules() async {
    setState(() => _selectedNavId = 'modules');
    await showHomeSheet(
      context: context,
      title: 'Modules',
      expand: true,
      child: ModuleListSheet(
        session: widget.session,
        permissions: widget.permissions,
        onOpenModule: widget.onOpenModule,
        moduleOrder: widget.moduleOrder,
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
    required this.announcementRepository,
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
  final LibrarianRepository? announcementRepository;

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
        SizedBox(
          height: 252,
          child:
              dashboard ??
              _PriorityDashboardCard(
                session: session,
                permissions: permissions,
                onOpenModule: onOpenModule,
                onQuickAction: onQuickAction,
                announcementRepository: announcementRepository,
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
                gatepassQr: glance.gatepassQr,
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

class _PriorityDashboardCard extends StatefulWidget {
  const _PriorityDashboardCard({
    required this.session,
    required this.permissions,
    required this.onOpenModule,
    required this.onQuickAction,
    required this.announcementRepository,
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
  final LibrarianRepository? announcementRepository;

  @override
  State<_PriorityDashboardCard> createState() => _PriorityDashboardCardState();
}

class _PriorityDashboardCardState extends State<_PriorityDashboardCard> {
  final _pageController = PageController();
  int _selectedIndex = 0;
  List<LibraryAnnouncement>? _announcements;

  @override
  void initState() {
    super.initState();
    _loadAnnouncements();
  }

  @override
  void didUpdateWidget(_PriorityDashboardCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.announcementRepository != widget.announcementRepository) {
      _loadAnnouncements();
    }
  }

  Future<void> _loadAnnouncements() async {
    final repository = widget.announcementRepository;
    if (repository == null) return;
    try {
      final values = await repository.announcements();
      if (!mounted) return;
      setState(() {
        _announcements = values
            .where((item) => item.status.toLowerCase() == 'approved')
            .toList(growable: false);
        _selectedIndex = 0;
      });
      if (_pageController.hasClients) _pageController.jumpToPage(0);
    } catch (_) {
      if (mounted) setState(() => _announcements = const []);
    }
  }

  void _openAnnouncement(BuildContext context, LibraryAnnouncement item) {
    showHomeSheet(
      context: context,
      title: item.type,
      expand: true,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        children: [
          if (_isImageAttachment(item.attachmentName, item.attachmentUrl)) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  item.attachmentUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const ColoredBox(
                    color: Color(0xFFF0EDF8),
                    child: Center(child: Icon(Icons.broken_image_outlined)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
          Text(item.title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 10),
          Text(item.message, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 16),
          Text(
            '${item.announcementDate.day.toString().padLeft(2, '0')} '
            '${_noticeMonthName(item.announcementDate.month)} '
            '${item.announcementDate.year} · ${item.createdByName}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (item.attachmentUrl != null &&
              !_isImageAttachment(item.attachmentName, item.attachmentUrl)) ...[
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () =>
                  _openExternalAttachment(context, item.attachmentUrl!),
              icon: const Icon(Icons.open_in_new_rounded),
              label: Text(item.attachmentName ?? 'Open attachment'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openExternalAttachment(
    BuildContext context,
    String value,
  ) async {
    final uri = Uri.tryParse(value);
    if (uri != null &&
        await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      return;
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The attachment could not be opened.')),
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark
        ? const Color(0xFF1D1A24)
        : const Color(0xFFF0F1F3);
    final datePanelColor = isDark
        ? const Color(0xFF292431)
        : const Color(0xFFE3E5E8);
    final selectedDotColor = isDark
        ? const Color(0xFFB8AEFF)
        : const Color(0xFF666A70);
    final idleDotColor = isDark
        ? const Color(0xFF514A5D)
        : const Color(0xFFD2D4D7);
    final mockNotices = MockFacultyRepository().getNotices();
    final cards = widget.announcementRepository == null
        ? <_DashboardNotice>[
            for (final notice in mockNotices)
              _DashboardNotice(
                eyebrow: notice.type.toUpperCase(),
                title: notice.title,
                message: notice.content,
                icon: Icons.campaign_outlined,
                day: notice.announcementDate.day.toString().padLeft(2, '0'),
                month: _noticeMonthName(notice.announcementDate.month),
                onTap: () => _openNoticePdf(context, notice),
              ),
          ]
        : <_DashboardNotice>[
            for (final item in _announcements ?? const <LibraryAnnouncement>[])
              _DashboardNotice(
                eyebrow: item.type.toUpperCase(),
                title: item.title,
                message: item.message,
                icon: Icons.campaign_outlined,
                day: item.announcementDate.day.toString().padLeft(2, '0'),
                month: _noticeMonthName(item.announcementDate.month),
                imageUrl:
                    _isImageAttachment(item.attachmentName, item.attachmentUrl)
                    ? item.attachmentUrl
                    : null,
                onTap: () => _openAnnouncement(context, item),
              ),
          ];

    if (cards.isEmpty) {
      cards.add(
        _DashboardNotice(
          eyebrow: 'CAMPUS UPDATES',
          title: 'You are all caught up',
          message: 'New announcements from your campus will appear here.',
          icon: Icons.notifications_none_rounded,
          day: DateTime.now().day.toString().padLeft(2, '0'),
          month: _noticeMonthName(DateTime.now().month),
        ),
      );
    }

    if (_selectedIndex >= cards.length) _selectedIndex = 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
      child: Column(
        children: [
          Expanded(
            child: Material(
              key: const ValueKey('announcement-card'),
              color: cardColor,
              borderRadius: BorderRadius.circular(26),
              clipBehavior: Clip.antiAlias,
              child: PageView.builder(
                key: const ValueKey('announcement-carousel'),
                controller: _pageController,
                physics: const BouncingScrollPhysics(),
                itemCount: cards.length,
                onPageChanged: (index) =>
                    setState(() => _selectedIndex = index),
                itemBuilder: (context, index) => _DashboardNoticeContent(
                  notice: cards[index],
                  datePanelColor: datePanelColor,
                  isSelected: index == _selectedIndex,
                  index: index,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            key: const ValueKey('announcement-carousel-indicator'),
            mainAxisSize: MainAxisSize.min,
            children: List.generate(cards.length, (index) {
              final isSelected = index == _selectedIndex;
              return AnimatedContainer(
                key: ValueKey('announcement-dot-$index'),
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                width: 7,
                height: 7,
                margin: EdgeInsets.only(left: index == 0 ? 0 : 5),
                decoration: BoxDecoration(
                  color: isSelected ? selectedDotColor : idleDotColor,
                  shape: BoxShape.circle,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _DashboardNotice {
  const _DashboardNotice({
    required this.eyebrow,
    required this.title,
    required this.message,
    required this.icon,
    required this.day,
    required this.month,
    this.imageUrl,
    this.onTap,
  });

  final String eyebrow;
  final String title;
  final String message;
  final IconData icon;
  final String day;
  final String month;
  final String? imageUrl;
  final VoidCallback? onTap;
}

class _DashboardNoticeContent extends StatelessWidget {
  const _DashboardNoticeContent({
    required this.notice,
    required this.datePanelColor,
    required this.isSelected,
    required this.index,
  });

  final _DashboardNotice notice;
  final Color datePanelColor;
  final bool isSelected;
  final int index;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = isDark ? const Color(0xFFB8AEFF) : AppColors.brandLavender;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: notice.onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 82,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AnimatedContainer(
                      key: isSelected
                          ? const ValueKey('announcement-date-panel')
                          : ValueKey('announcement-date-panel-$index'),
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      width: 72,
                      decoration: BoxDecoration(
                        color: datePanelColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            notice.icon,
                            color: theme.colorScheme.onSurface,
                            size: 19,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            notice.day,
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontSize: 23,
                              height: 1,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            notice.month,
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              notice.eyebrow,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: accent,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    notice.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: theme.colorScheme.onSurface,
                                      fontSize: 16,
                                      height: 1.15,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  color: theme.colorScheme.onSurface,
                                  size: 23,
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Expanded(
                              child: Text(
                                notice.message,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: 11,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (notice.imageUrl != null) ...[
                const SizedBox(height: 10),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: SizedBox(
                      width: double.infinity,
                      child: Image.network(
                        notice.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => ColoredBox(
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: const Center(
                            child: Icon(Icons.broken_image_outlined),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ] else
                const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

bool _isImageAttachment(String? name, String? url) {
  return isAnnouncementImageAttachment(name, url);
}

String _noticeMonthName(int month) => const [
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
