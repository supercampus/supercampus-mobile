import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/access/effective_permissions.dart';
import '../../../core/access/module_catalog.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/campus_nav_bar.dart';
import '../../advisor/data/advisor_students_repository.dart';
import '../../advisor/presentation/advisor_students_section.dart';
import '../../admin_system/data/admin_system_repository.dart';
import '../../admin_system/presentation/admin_system_entries.dart';
import '../../authentication/data/auth_repository.dart';
import '../../modules/presentation/today_glance.dart';
import '../../modules/presentation/widgets/home_sheets.dart';
import '../../payment_requests/presentation/admin_payment_requests_page.dart';
import '../../payment_requests/presentation/online_payments_page.dart';
import '../../push_broadcasts/data/push_broadcast_repository.dart';
import '../../reports/data/finance_report.dart';
import '../data/admin_student_repository.dart';

/// Clean, high-productivity Bento Grid dashboard for campus administrators and staff.
///
/// Designed for daily, multi-hour use:
/// - Fast Bento Grid app launcher (zero walls of text)
/// - Interactive category workspace tabs
/// - Real operational metrics & quick shortcuts
/// - Role-tailored views for Admin, Captain, Accountant, Stationery Owner, Faculty, Security, etc.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({
    super.key,
    required this.session,
    required this.permissions,
    required this.onOpenModule,
    this.onQuickAction,
    required this.onSignOut,
    required this.onProfileTap,
    required this.onAlertsTap,
    this.hasAlerts = false,
    this.onScan,
    this.onOpenModulesSheet,
    this.advisorStudentsSource,
    this.glance,
    this.onOpenAttendanceClass,
    this.loadAdminUsers,
    this.onOpenReports,
    this.onOpenPushNotifications,
    this.onOpenPaymentRequests,
    this.onOpenOnlinePayments,
    this.adminSystemRepository,
  });

  /// Backs the System group (Audit logs, Security logs, App versions). Null
  /// hides the group; each row is also gated by its own grant.
  final AdminSystemRepository? adminSystemRepository;

  /// Opens Push Notifications (broadcasts). Null hides the entry, as do
  /// grants without `notifications.broadcast.*`.
  final VoidCallback? onOpenPushNotifications;

  /// Opens Payment requests (fines, bills). Null hides the entry, as do
  /// grants without `fees.payment_requests.*`.
  final VoidCallback? onOpenPaymentRequests;

  /// Opens Online payments (Razorpay tracking). Null hides the entry, as do
  /// grants without `fees.online_payments.*`.
  final VoidCallback? onOpenOnlinePayments;

  /// Opens the finance Reports page (PDF / CSV). Null hides the entry, as
  /// do grants that could not load the reports.
  final VoidCallback? onOpenReports;

  /// Reads the tenant's accounts for the administrator's overview counts.
  /// Null (or a failed read) shows no counts rather than invented ones.
  final Future<List<ManagedTenantUser>> Function()? loadAdminUsers;

  final UserSession session;
  final EffectivePermissions permissions;
  final void Function(String moduleId, [String? action]) onOpenModule;
  final VoidCallback? onOpenModulesSheet;
  final void Function(
    String moduleId,
    String actionId,
    String featureId,
    String requiredAction,
  )? onQuickAction;
  final VoidCallback onSignOut;
  final VoidCallback onProfileTap;
  final VoidCallback onAlertsTap;
  final bool hasAlerts;
  final ValueChanged<BuildContext>? onScan;
  final AdvisorStudentsSource? advisorStudentsSource;
  final GlanceFacts? glance;
  final ValueChanged<TodayClass>? onOpenAttendanceClass;

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedCategoryIndex = 0;

  UserSession get session => widget.session;
  EffectivePermissions get permissions => widget.permissions;

  /// Whether this viewer runs the institution's Admin Desk (users, roles,
  /// announcements). Decided by grants, never by portal family or role name:
  /// the backend also places finance and operations staff in the admin
  /// family, and they must not be shown controls they cannot open.
  bool get _administers =>
      permissions.canSeeModule(ModuleCatalog.administration);

  /// The finance Reports entry: shown to whoever holds the report grants.
  VoidCallback? get _openReports =>
      widget.onOpenReports != null && canGenerateFinanceReports(permissions)
      ? widget.onOpenReports
      : null;

  /// Payment requests: shown to whoever may view or raise them.
  VoidCallback? get _openPaymentRequests =>
      widget.onOpenPaymentRequests != null &&
          canViewPaymentRequests(permissions)
      ? widget.onOpenPaymentRequests
      : null;

  /// Online payments: shown to whoever may track Razorpay payments.
  VoidCallback? get _openOnlinePayments =>
      widget.onOpenOnlinePayments != null && canViewOnlinePayments(permissions)
      ? widget.onOpenOnlinePayments
      : null;

  /// Push broadcasts: shown to whoever may view or send them.
  VoidCallback? get _openPushNotifications =>
      widget.onOpenPushNotifications != null &&
          canViewPushBroadcasts(permissions)
      ? widget.onOpenPushNotifications
      : null;

  List<ManagedTenantUser>? _adminUsers;
  bool _adminUsersFailed = false;

  @override
  void initState() {
    super.initState();
    _loadAdminUsers();
  }

  Future<void> _loadAdminUsers() async {
    final loader = widget.loadAdminUsers;
    if (loader == null || !_administers) return;
    try {
      final users = await loader();
      if (!mounted) return;
      setState(() {
        _adminUsers = users;
        _adminUsersFailed = false;
      });
    } catch (_) {
      if (mounted) setState(() => _adminUsersFailed = true);
    }
  }

  Color _roleColor() {
    if (_administers) return const Color(0xFF7B42F6);
    if (session.isCanteenOwner) return const Color(0xFFC24700);
    if (session.isCaptain) return const Color(0xFFC24700);
    if (session.isAccountant) return const Color(0xFFD6006B);
    if (session.isStationeryOwner) return const Color(0xFF007A70);
    if (session.isFaculty) return const Color(0xFF9B1FE8);
    if (session.isSecurityStaff) return const Color(0xFF007A70);
    if (session.isLibrarian) return const Color(0xFF9D4EDD);
    if (session.isHostelWarden) return const Color(0xFFC24700);
    return const Color(0xFF475569);
  }

  /// Accent hue used as text or icon: exact in light, lifted in dark so it
  /// stays legible on the dark card fill.
  Color _accentInk(Color color) =>
      Theme.of(context).brightness == Brightness.dark
          ? Color.lerp(color, Colors.white, 0.35)!
          : color;

  IconData _roleIcon() {
    if (_administers) return Icons.admin_panel_settings_rounded;
    if (session.isCanteenOwner) return Icons.storefront_rounded;
    if (session.isCaptain) return Icons.restaurant_rounded;
    if (session.isAccountant) return Icons.account_balance_wallet_rounded;
    if (session.isStationeryOwner) return Icons.edit_note_rounded;
    if (session.isFaculty) return Icons.school_rounded;
    if (session.isSecurityStaff) return Icons.security_rounded;
    if (session.isLibrarian) return Icons.local_library_rounded;
    if (session.isHostelWarden) return Icons.apartment_rounded;
    return Icons.shield_outlined;
  }

  String _primaryModuleId() {
    if (_administers) return ModuleCatalog.administration;
    if (session.isCanteenOwner) return ModuleCatalog.canteen;
    if (session.isCaptain) return ModuleCatalog.canteen;
    if (session.isAccountant) return ModuleCatalog.canteen;
    if (session.isStationeryOwner) return ModuleCatalog.canteen;
    if (session.isSecurityStaff) return ModuleCatalog.gatepass;
    if (session.isLibrarian) return ModuleCatalog.library;
    if (session.isHostelWarden) return ModuleCatalog.hostel;
    if (session.isFaculty) return ModuleCatalog.attendance;
    return ModuleCatalog.administration;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final listPadding = EdgeInsets.fromLTRB(
      16,
      14,
      16,
      CampusNavBar.heightFor(context) + MediaQuery.paddingOf(context).bottom + 30,
    );

    return Scaffold(
      backgroundColor: _administers
          ? context.palette.surfaceSunken
          : isDark
          ? const Color(0xFF0E0F13)
          : const Color(0xFFF8FAFC),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: Stack(
                children: [
                  if (_administers)
                    RefreshIndicator(
                      onRefresh: _loadAdminUsers,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: listPadding,
                        children: _buildAdminHome(context),
                      ),
                    )
                  else if (session.isAccountant)
                    ListView(
                      key: const ValueKey('accountant-home'),
                      padding: listPadding,
                      children: _buildAccountantHome(context),
                    )
                  else
                  ListView(
                    padding: listPadding,
                    children: [
                      _buildQuickActionShortcuts(context),
                      const SizedBox(height: 14),
                      _buildKpiBentoGrid(context),
                      const SizedBox(height: 18),
                      if (_administers) ...[
                        _buildCategoryFilterBar(context),
                        const SizedBox(height: 14),
                      ],
                      _buildWorkspaceBentoGrid(context),
                      if (widget.advisorStudentsSource != null) ...[
                        const SizedBox(height: 24),
                        _buildSectionTitle(
                          'Advisee Students',
                          'Student mentorship & academic tracking',
                          Icons.people_outline_rounded,
                          const Color(0xFF7B42F6),
                        ),
                        const SizedBox(height: 10),
                        AdvisorStudentsSection(source: widget.advisorStudentsSource!),
                      ],
                      if (widget.glance != null && permissions.canSeeModule(ModuleCatalog.attendance)) ...[
                        const SizedBox(height: 24),
                        _buildSectionTitle(
                          "Today's Schedule & Roll",
                          'Assigned lecture periods & attendance status',
                          Icons.calendar_today_rounded,
                          const Color(0xFF007A70),
                        ),
                        const SizedBox(height: 10),
                        TodayGlance(
                          permissions: permissions,
                          facts: widget.glance!,
                          onOpenModule: (id) => widget.onOpenModule(id),
                          onOpenClass: widget.onOpenAttendanceClass,
                        ),
                      ],
                    ],
                  ),
                  () {
                    final canScan = session.canScanQr;
                    final List<CampusNavItem>? roleItems;
                    if (!canScan) {
                      if (_administers) {
                        roleItems = [
                          CampusNavItem(
                            id: 'home',
                            label: 'Home',
                            icon: const Icon(Icons.dashboard_outlined),
                            selectedIcon: const Icon(Icons.dashboard_rounded),
                            onTap: () {},
                          ),
                          // The administrator home already lists every area
                          // it may open, so a Modules sheet only repeated it.
                          // The student directory is what an administrator
                          // opens all day: look someone up, fix a record,
                          // change residency, set a photo.
                          CampusNavItem(
                            id: 'students',
                            label: 'Students',
                            icon: const Icon(Icons.school_outlined),
                            selectedIcon: const Icon(Icons.school_rounded),
                            onTap: () => widget.onOpenModule(
                              ModuleCatalog.administration,
                              'students',
                            ),
                          ),
                          CampusNavItem(
                            id: 'desk',
                            label: 'Admin Desk',
                            icon: const Icon(Icons.admin_panel_settings_outlined),
                            selectedIcon:
                                const Icon(Icons.admin_panel_settings_rounded),
                            onTap: () => widget
                                .onOpenModule(ModuleCatalog.administration),
                          ),
                          CampusNavItem(
                            id: 'alerts',
                            label: 'Alerts',
                            icon: const Icon(Icons.notifications_none_rounded),
                            selectedIcon:
                                const Icon(Icons.notifications_rounded),
                            onTap: widget.onAlertsTap,
                          ),
                        ];
                      } else if (session.isFaculty) {
                        roleItems = [
                          CampusNavItem(
                            id: 'home',
                            label: 'Home',
                            icon: const Icon(Icons.home_outlined),
                            selectedIcon: const Icon(Icons.home_rounded),
                            onTap: () {},
                          ),
                          CampusNavItem(
                            id: 'modules',
                            label: 'Modules',
                            icon: const CampusNavCubeGlyph(filled: false),
                            selectedIcon: const CampusNavCubeGlyph(filled: true),
                            onTap: widget.onOpenModulesSheet ??
                                () => widget.onOpenModule(_primaryModuleId()),
                          ),
                          CampusNavItem(
                            id: 'timetable',
                            label: 'Schedule',
                            icon: const Icon(Icons.calendar_today_outlined),
                            selectedIcon:
                                const Icon(Icons.calendar_today_rounded),
                            onTap: () =>
                                widget.onOpenModule(ModuleCatalog.timetable),
                          ),
                          CampusNavItem(
                            id: 'attendance',
                            label: 'Roll',
                            icon: const Icon(Icons.how_to_reg_outlined),
                            selectedIcon:
                                const Icon(Icons.how_to_reg_rounded),
                            onTap: () =>
                                widget.onOpenModule(ModuleCatalog.attendance),
                          ),
                        ];
                      } else if (session.isAccountant) {
                        roleItems = [
                          CampusNavItem(
                            id: 'home',
                            label: 'Home',
                            icon: const Icon(Icons.home_outlined),
                            selectedIcon: const Icon(Icons.home_rounded),
                            onTap: () {},
                          ),
                          CampusNavItem(
                            id: 'modules',
                            label: 'Modules',
                            icon: const CampusNavCubeGlyph(filled: false),
                            selectedIcon: const CampusNavCubeGlyph(filled: true),
                            onTap: widget.onOpenModulesSheet ??
                                () => widget.onOpenModule(_primaryModuleId()),
                          ),
                          CampusNavItem(
                            id: 'fees',
                            label: 'Fee Desk',
                            icon: const Icon(Icons.receipt_long_outlined),
                            selectedIcon:
                                const Icon(Icons.receipt_long_rounded),
                            onTap: () =>
                                widget.onOpenModule(ModuleCatalog.tuitionFee),
                          ),
                          CampusNavItem(
                            id: 'alerts',
                            label: 'Alerts',
                            icon: const Icon(Icons.notifications_none_rounded),
                            selectedIcon:
                                const Icon(Icons.notifications_rounded),
                            onTap: widget.onAlertsTap,
                          ),
                        ];
                      } else {
                        roleItems = null;
                      }
                    } else {
                      roleItems = null;
                    }

                    return Positioned(
                      left: 0,
                      right: 0,
                      bottom: MediaQuery.paddingOf(context).bottom + 10,
                      child: CampusNavBar(
                        selectedId: 'home',
                        showScan: canScan,
                        items: roleItems,
                        initials: initialsOf(session.displayName),
                        avatarUrl: session.photoUrl,
                        onHome: () {},
                        onModules: widget.onOpenModulesSheet ??
                            () => widget.onOpenModule(_primaryModuleId()),
                        onProfile: widget.onProfileTap,
                        onScan: canScan && widget.onScan != null
                            ? () => widget.onScan!(context)
                            : null,
                      ),
                    );
                  }(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // ADMINISTRATOR HOME
  // One entry per destination: a greeting, real account counts, then the
  // workspaces grouped the way an administrator uses them. Teaching tools
  // (attendance, timetable, examinations, library) stay in Modules.
  // ===========================================================================
  List<Widget> _buildAdminHome(BuildContext context) {
    final palette = context.palette;
    final now = DateTime.now();
    final greeting = now.hour < 12
        ? 'Good morning'
        : now.hour < 17
        ? 'Good afternoon'
        : 'Good evening';
    final firstName = session.displayName.trim().split(RegExp(r'\s+')).first;

    void open(String module, [String? action]) =>
        widget.onOpenModule(module, action);

    final people = <_AdminRow>[
      _AdminRow(
        icon: Icons.manage_accounts_rounded,
        color: AppColors.brandPurple,
        title: 'Users & roles',
        subtitle: 'Accounts, roles, passwords, year of study',
        onTap: () => open(ModuleCatalog.administration, 'access_control'),
      ),
      if (permissions.can('authorization', 'roles', 'read'))
        _AdminRow(
          icon: Icons.admin_panel_settings_rounded,
          color: AppColors.brandViolet,
          title: 'Roles & permissions',
          subtitle: 'Create roles and choose what each can do',
          onTap: () => open(ModuleCatalog.administration, 'roles'),
        ),
      _AdminRow(
        icon: Icons.school_rounded,
        color: AppColors.brandViolet,
        title: 'Student directory',
        subtitle: 'Student records, residency and guardians',
        onTap: () => open(ModuleCatalog.administration, 'students'),
      ),
      _AdminRow(
        icon: Icons.campaign_rounded,
        color: AppColors.orangeInk,
        title: 'Announcements',
        subtitle: 'Campus circulars',
        onTap: () => open(ModuleCatalog.administration, 'announcements'),
      ),
      if (_openPushNotifications != null)
        _AdminRow(
          icon: Icons.notifications_active_rounded,
          color: AppColors.hotPinkInk,
          title: 'Push notifications',
          subtitle: 'Broadcast to roles, people or students',
          onTap: _openPushNotifications!,
        ),
    ];

    final money = <_AdminRow>[
      if (permissions.canSeeModule(ModuleCatalog.canteen)) ...[
        _AdminRow(
          icon: Icons.storefront_rounded,
          color: AppColors.success,
          title: 'Shops & sales',
          subtitle: 'Live sales across counters',
          onTap: () => open(ModuleCatalog.canteen, 'dashboard'),
        ),
        _AdminRow(
          icon: Icons.account_balance_wallet_rounded,
          color: AppColors.brandPurple,
          title: 'Student wallets',
          subtitle: 'Balances and recharges',
          onTap: () => open(ModuleCatalog.canteen, 'wallet'),
        ),
      ],
      if (permissions.canSeeModule(ModuleCatalog.tuitionFee))
        _AdminRow(
          icon: Icons.receipt_long_rounded,
          color: AppColors.infoInk,
          title: 'Tuition & fees',
          subtitle: 'Invoices and dues',
          onTap: () => open(ModuleCatalog.tuitionFee),
        ),
      if (permissions.canSeeModule(ModuleCatalog.vendorManagement))
        _AdminRow(
          icon: Icons.handshake_outlined,
          color: AppColors.infoInk,
          title: 'Vendors & orders',
          subtitle: 'Procurement',
          onTap: () => open(ModuleCatalog.vendorManagement),
        ),
      if (_openReports != null)
        _AdminRow(
          icon: Icons.summarize_rounded,
          color: AppColors.brandViolet,
          title: 'Reports',
          subtitle: 'Sales, wallet and vendor reports as PDF or CSV',
          onTap: _openReports!,
        ),
      if (_openPaymentRequests != null)
        _AdminRow(
          icon: Icons.request_quote_rounded,
          color: AppColors.orangeInk,
          title: 'Payment requests',
          subtitle: 'Fines, bills and other dues for students',
          onTap: _openPaymentRequests!,
        ),
      if (_openOnlinePayments != null)
        _AdminRow(
          icon: Icons.credit_score_rounded,
          color: AppColors.success,
          title: 'Online payments',
          subtitle: 'Razorpay capture, settlement and recovery',
          onTap: _openOnlinePayments!,
        ),
    ];

    final campus = <_AdminRow>[
      if (permissions.canSeeModule(ModuleCatalog.academics))
        _AdminRow(
          icon: Icons.auto_stories_outlined,
          color: AppColors.brandPurple,
          title: 'Departments & programmes',
          subtitle: 'Curriculum structure',
          onTap: () => open(ModuleCatalog.academics),
        ),
      if (permissions.canSeeModule(ModuleCatalog.hostel))
        _AdminRow(
          icon: Icons.apartment_rounded,
          color: AppColors.muted,
          title: 'Hostel',
          subtitle: 'Rooms and residents',
          onTap: () => open(ModuleCatalog.hostel),
        ),
      if (permissions.canSeeModule(ModuleCatalog.gatepass))
        _AdminRow(
          icon: Icons.qr_code_scanner_rounded,
          color: AppColors.infoInk,
          title: 'Gate security',
          subtitle: 'Passes and checkpoint',
          onTap: () => open(ModuleCatalog.gatepass),
        ),
      // The bottom bar gives its Modules slot to Students, so everything
      // else this administrator may open stays one row away here.
      if (widget.onOpenModulesSheet != null)
        _AdminRow(
          icon: Icons.apps_rounded,
          color: AppColors.muted,
          title: 'All modules',
          subtitle: 'Library, timetable, attendance and more',
          onTap: widget.onOpenModulesSheet!,
        ),
    ];

    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('EEEE, d MMMM').format(now).toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
                color: palette.inkSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              firstName.isEmpty ? greeting : '$greeting, $firstName',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.6,
                color: palette.ink,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      _buildAdminOverview(context),
      const SizedBox(height: 24),
      _AdminGroup(title: 'People', rows: people),
      if (money.isNotEmpty) ...[
        const SizedBox(height: 24),
        _AdminGroup(title: 'Finance & commerce', rows: money),
      ],
      if (campus.isNotEmpty) ...[
        const SizedBox(height: 24),
        _AdminGroup(title: 'Campus', rows: campus),
      ],
      if (_systemRows().isNotEmpty) ...[
        const SizedBox(height: 24),
        _AdminGroup(title: 'System', rows: _systemRows()),
      ],
      if (widget.advisorStudentsSource != null) ...[
        const SizedBox(height: 24),
        AdvisorStudentsSection(source: widget.advisorStudentsSource!),
      ],
    ];
  }

  // ===========================================================================
  // ACCOUNTANT HOME
  // The accounts desk in the same grouped style as the administrator home:
  // the two things done all day (changing a wallet, checking the ledger) as
  // large actions up top, then one row per destination, grouped by job.
  // Teaching tools (examinations etc.) are not part of the accounts desk.
  // ===========================================================================
  List<Widget> _buildAccountantHome(BuildContext context) {
    final palette = context.palette;
    final now = DateTime.now();
    final greeting = now.hour < 12
        ? 'Good morning'
        : now.hour < 17
        ? 'Good afternoon'
        : 'Good evening';
    final firstName = session.displayName.trim().split(RegExp(r'\s+')).first;
    final wallets = permissions.canSeeModule(ModuleCatalog.canteen);

    void open(String module, [String? action]) =>
        widget.onOpenModule(module, action);

    final fees = <_AdminRow>[
      if (permissions.canSeeModule(ModuleCatalog.tuitionFee)) ...[
        _AdminRow(
          icon: Icons.receipt_long_rounded,
          color: AppColors.infoInk,
          title: 'Tuition & fees',
          subtitle: 'Invoices, dues and collections',
          onTap: () => open(ModuleCatalog.tuitionFee),
        ),
      ],
      if (_openPaymentRequests != null)
        _AdminRow(
          icon: Icons.request_quote_rounded,
          color: AppColors.orangeInk,
          title: 'Payment requests',
          subtitle: 'Fines, bills and other dues for students',
          onTap: _openPaymentRequests!,
        ),
      if (_openOnlinePayments != null)
        _AdminRow(
          icon: Icons.credit_score_rounded,
          color: AppColors.success,
          title: 'Online payments',
          subtitle: 'Razorpay payments and settlements',
          onTap: _openOnlinePayments!,
        ),
    ];

    final walletRows = <_AdminRow>[
      if (wallets) ...[
        _AdminRow(
          icon: Icons.account_balance_wallet_rounded,
          color: AppColors.brandPurple,
          title: 'Wallet directory',
          subtitle: 'Find anyone and add or deduct credits',
          onTap: () => open(ModuleCatalog.canteen, 'wallet'),
        ),
        _AdminRow(
          icon: Icons.history_rounded,
          color: AppColors.infoInk,
          title: 'Wallet activity',
          subtitle: 'Every top-up, deduction, purchase and refund',
          onTap: () => open(ModuleCatalog.canteen, 'transactions'),
        ),
      ],
    ];

    final more = <_AdminRow>[
      if (_openReports != null)
        _AdminRow(
          icon: Icons.summarize_rounded,
          color: AppColors.brandViolet,
          title: 'Reports',
          subtitle: 'Credits, debits, payables and more as PDF or CSV',
          onTap: _openReports!,
        ),
      if (permissions.canSeeModule(ModuleCatalog.vendorManagement))
        _AdminRow(
          icon: Icons.handshake_outlined,
          color: AppColors.infoInk,
          title: 'Vendors & orders',
          subtitle: 'Shop sales and vendor settlements',
          onTap: () => open(ModuleCatalog.vendorManagement),
        ),
    ];

    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('EEEE, d MMMM').format(now).toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
                color: palette.inkSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              firstName.isEmpty ? greeting : '$greeting, $firstName',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.6,
                color: palette.ink,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Accounts desk',
              style: TextStyle(fontSize: 14, color: palette.inkSecondary),
            ),
          ],
        ),
      ),
      if (wallets) ...[
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _AccountantAction(
                key: const ValueKey('accountant-action-wallets'),
                icon: Icons.add_card_rounded,
                title: 'Add or deduct',
                subtitle: 'Change a wallet balance',
                color: AppColors.brandPurple,
                onTap: () => open(ModuleCatalog.canteen, 'wallet'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _AccountantAction(
                key: const ValueKey('accountant-action-activity'),
                icon: Icons.receipt_long_rounded,
                title: 'Activity',
                subtitle: 'Recent wallet entries',
                color: AppColors.infoInk,
                onTap: () => open(ModuleCatalog.canteen, 'transactions'),
              ),
            ),
          ],
        ),
      ],
      if (walletRows.isNotEmpty) ...[
        const SizedBox(height: 24),
        _AdminGroup(title: 'Wallets', rows: walletRows),
      ],
      if (fees.isNotEmpty) ...[
        const SizedBox(height: 24),
        _AdminGroup(title: 'Fees & payments', rows: fees),
      ],
      if (more.isNotEmpty) ...[
        const SizedBox(height: 24),
        _AdminGroup(title: 'Reports & vendors', rows: more),
      ],
    ];
  }

  /// Audit logs, security logs and app versions, each behind its own grant.
  List<_AdminRow> _systemRows() {
    final repository = widget.adminSystemRepository;
    if (repository == null) return const [];
    return [
      for (final entry in adminSystemEntries(permissions))
        _AdminRow(
          icon: entry.icon,
          color: entry.color,
          title: entry.title,
          subtitle: entry.subtitle,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => entry.build(repository, permissions),
            ),
          ),
        ),
    ];
  }

  /// Account counts read from the users endpoint. Nothing is shown until
  /// they arrive; a failed read says so instead of showing zeros.
  Widget _buildAdminOverview(BuildContext context) {
    final palette = context.palette;
    final users = _adminUsers;
    void openUsers() =>
        widget.onOpenModule(ModuleCatalog.administration, 'access_control');

    if (widget.loadAdminUsers == null) return const SizedBox.shrink();
    if (users == null && _adminUsersFailed) {
      return _AdminCard(
        onTap: _loadAdminUsers,
        child: Row(
          children: [
            Icon(Icons.cloud_off_rounded, color: palette.inkSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Account counts could not be loaded. Tap to try again.',
                style: TextStyle(fontSize: 14, color: palette.inkSecondary),
              ),
            ),
          ],
        ),
      );
    }

    bool isStudent(ManagedTenantUser user) =>
        user.roles.any((role) => role.key == 'student');
    final active = users?.where((user) => user.active).length;
    final inactive = users == null ? null : users.length - active!;
    final students = users?.where(isStudent).toList();
    final noYear = students
        ?.where((user) => user.yearOfStudy == null)
        .length;
    final noRole = users?.where((user) => user.roles.isEmpty).length;
    final attention = noYear == null ? null : noYear + noRole!;

    String count(int? value) => value == null ? '–' : '$value';

    return _AdminCard(
      onTap: openUsers,
      child: Row(
        children: [
          Expanded(
            child: _AdminMetric(
              label: 'Active users',
              value: count(active),
              caption: inactive == null || inactive == 0
                  ? null
                  : '$inactive inactive',
            ),
          ),
          _metricDivider(palette),
          Expanded(
            child: _AdminMetric(
              label: 'Students',
              value: count(students?.length),
            ),
          ),
          _metricDivider(palette),
          Expanded(
            child: _AdminMetric(
              label: 'Need attention',
              value: count(attention),
              valueColor: (attention ?? 0) > 0 ? palette.danger : null,
              caption: attention == null || attention == 0
                  ? null
                  : [
                      if (noYear! > 0) '$noYear no year',
                      if (noRole! > 0) '$noRole no role',
                    ].join(' · '),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricDivider(AppPalette palette) => Container(
    width: 0.5,
    height: 44,
    margin: const EdgeInsets.symmetric(horizontal: 10),
    color: palette.divider,
  );

  // ===========================================================================
  // 1. TOP BAR
  // ===========================================================================
  Widget _buildTopBar(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final roleColor = _roleColor();
    final roleIcon = _roleIcon();
    final roleBadge = session.roleBadgeTextFor(administers: _administers);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131419) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF202128) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [roleColor, roleColor.withValues(alpha: 0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: roleColor.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(roleIcon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    // Shrinks before the role badge does on a narrow phone.
                    Flexible(
                      child: Text(
                        'SuperCampus',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: roleColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        roleBadge,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  session.email.isNotEmpty
                      ? session.email
                      : session.roleDisplayTitleFor(administers: _administers),
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? const Color(0xFFA3A5B0) : const Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Campus notifications',
            onPressed: widget.onAlertsTap,
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  Icons.notifications_none_rounded,
                  color: isDark ? Colors.white : const Color(0xFF334155),
                ),
                if (widget.hasAlerts)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: context.palette.danger,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: widget.onProfileTap,
              child: CircleAvatar(
                radius: 17,
                backgroundColor: isDark
                    ? const Color(0xFF17181D)
                    : const Color(0xFFE2E8F0),
                backgroundImage: session.photoUrl != null &&
                        session.photoUrl!.isNotEmpty
                    ? NetworkImage(session.photoUrl!)
                    : null,
                child: session.photoUrl == null || session.photoUrl!.isEmpty
                    ? Text(
                        initialsOf(session.displayName),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF334155),
                        ),
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 2. FAST ACTION SHORTCUTS BAR
  // ===========================================================================
  Widget _buildQuickActionShortcuts(BuildContext context) {
    final List<Widget> shortcuts = [];

    if (_administers) {
      shortcuts.addAll([
        _buildActionPill(
          icon: Icons.admin_panel_settings_rounded,
          label: 'Admin Desk',
          color: const Color(0xFF7B42F6),
          onTap: () => widget.onOpenModule(ModuleCatalog.administration),
        ),
        _buildActionPill(
          icon: Icons.school_rounded,
          label: 'Student Directory',
          color: const Color(0xFF7B42F6),
          onTap: () => widget.onOpenModule(ModuleCatalog.administration, 'students'),
        ),
        _buildActionPill(
          icon: Icons.manage_accounts_rounded,
          label: 'Users & Roles',
          color: const Color(0xFF9B1FE8),
          onTap: () => widget.onOpenModule(ModuleCatalog.administration, 'access_control'),
        ),
        _buildActionPill(
          icon: Icons.campaign_rounded,
          label: 'Announcements',
          color: const Color(0xFFEA580C),
          onTap: () => widget.onOpenModule(ModuleCatalog.administration, 'announcements'),
        ),
        _buildActionPill(
          icon: Icons.storefront_rounded,
          label: 'Live Sales Dashboard',
          color: const Color(0xFF059669),
          onTap: () => widget.onOpenModule(ModuleCatalog.canteen, 'dashboard'),
        ),
        if (widget.onScan != null)
          _buildActionPill(
            icon: Icons.qr_code_scanner_rounded,
            label: 'Scan QR',
            color: const Color(0xFF007A70),
            onTap: () => widget.onScan!(context),
          ),
      ]);
    } else if (session.isCaptain) {
      shortcuts.addAll([
        _buildActionPill(
          icon: Icons.receipt_long_rounded,
          label: 'Orders Queue',
          color: const Color(0xFF059669),
          onTap: () => widget.onOpenModule(ModuleCatalog.canteen, 'orders'),
        ),
        if (widget.onScan != null)
          _buildActionPill(
            icon: Icons.qr_code_scanner_rounded,
            label: 'Scan Token',
            color: const Color(0xFF007A70),
            onTap: () => widget.onScan!(context),
          ),
        _buildActionPill(
          icon: Icons.history_rounded,
          label: 'History',
          color: const Color(0xFF7B42F6),
          onTap: () => widget.onOpenModule(ModuleCatalog.canteen, 'order_history'),
        ),
      ]);
    } else if (session.isAccountant) {
      shortcuts.addAll([
        _buildActionPill(
          icon: Icons.account_balance_wallet_rounded,
          label: 'Recharge Wallets',
          color: const Color(0xFF7B42F6),
          onTap: () => widget.onOpenModule(ModuleCatalog.canteen, 'wallet'),
        ),
        _buildActionPill(
          icon: Icons.receipt_long_rounded,
          label: 'Transactions',
          color: const Color(0xFF007A70),
          onTap: () => widget.onOpenModule(ModuleCatalog.canteen, 'transactions'),
        ),
        _buildActionPill(
          icon: Icons.request_quote_rounded,
          label: 'Tuition Invoices',
          color: const Color(0xFF059669),
          onTap: () => widget.onOpenModule(ModuleCatalog.tuitionFee, 'dues'),
        ),
      ]);
    } else if (session.isStationeryOwner) {
      shortcuts.addAll([
        _buildActionPill(
          icon: Icons.menu_book_rounded,
          label: 'Item Catalog',
          color: const Color(0xFF007A70),
          onTap: () => widget.onOpenModule(ModuleCatalog.canteen, 'menu'),
        ),
        _buildActionPill(
          icon: Icons.shopping_bag_outlined,
          label: 'Print & Orders',
          color: const Color(0xFF059669),
          onTap: () => widget.onOpenModule(ModuleCatalog.canteen, 'orders'),
        ),
      ]);
    } else if (session.isFaculty) {
      shortcuts.addAll([
        _buildActionPill(
          icon: Icons.fact_check_outlined,
          label: 'Take Roll Call',
          color: const Color(0xFF7B42F6),
          onTap: () => widget.onOpenModule(ModuleCatalog.attendance, 'mark'),
        ),
        _buildActionPill(
          icon: Icons.schedule_rounded,
          label: 'My Schedule',
          color: const Color(0xFF9D4EDD),
          onTap: () => widget.onOpenModule(ModuleCatalog.timetable, 'schedule'),
        ),
      ]);
    } else if (session.isSecurityStaff) {
      shortcuts.addAll([
        if (widget.onScan != null)
          _buildActionPill(
            icon: Icons.qr_code_scanner_rounded,
            label: 'Scan Pass QR',
            color: const Color(0xFF007A70),
            onTap: () => widget.onScan!(context),
          ),
        _buildActionPill(
          icon: Icons.history_rounded,
          label: 'Gate Movement',
          color: const Color(0xFF0D9488),
          onTap: () => widget.onOpenModule(ModuleCatalog.gatepass, 'movement_logs'),
        ),
      ]);
    }

    if (_openReports != null && !_administers) {
      shortcuts.add(
        _buildActionPill(
          icon: Icons.summarize_rounded,
          label: 'Reports',
          color: AppColors.brandViolet,
          onTap: _openReports!,
        ),
      );
    }

    if (shortcuts.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          for (var i = 0; i < shortcuts.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            shortcuts[i],
          ],
        ],
      ),
    );
  }

  Widget _buildActionPill({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? const Color(0xFF17181D) : Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark ? const Color(0xFF2B2C34) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: _accentInk(color)),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 3. OPERATIONAL KPI CARD (Real metrics, zero fluff)
  // ===========================================================================
  Widget _buildKpiBentoGrid(BuildContext context) {
    if (_administers) {
      return Row(
        children: [
          Expanded(
            child: _buildStatTile(
              title: 'Institution Control',
              value: 'Admin Desk',
              badge: 'Users & Roles',
              icon: Icons.admin_panel_settings_rounded,
              color: const Color(0xFF7B42F6),
              onTap: () => widget.onOpenModule(ModuleCatalog.administration),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildStatTile(
              title: 'Student Directory',
              value: 'Students',
              badge: 'Residency & Info',
              icon: Icons.school_rounded,
              color: const Color(0xFF7B42F6),
              onTap: () => widget.onOpenModule(ModuleCatalog.administration, 'students'),
            ),
          ),
        ],
      );
    }

    if (session.isCanteenOwner) {
      return _buildSalesHeroCard(context);
    }

    if (session.isCaptain) {
      return Row(
        children: [
          Expanded(
            child: _buildStatTile(
              title: 'Orders Queue',
              value: 'Live Orders',
              badge: 'Kitchen Prep',
              icon: Icons.receipt_long_rounded,
              color: const Color(0xFF059669),
              onTap: () => widget.onOpenModule(ModuleCatalog.canteen, 'orders'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildStatTile(
              title: 'Verification',
              value: 'Scan Token',
              badge: 'Fast QR',
              icon: Icons.qr_code_scanner_rounded,
              color: const Color(0xFF007A70),
              onTap: widget.onScan != null ? () => widget.onScan!(context) : () => widget.onOpenModule(ModuleCatalog.canteen, 'orders'),
            ),
          ),
        ],
      );
    }

    if (session.isAccountant) {
      return Row(
        children: [
          Expanded(
            child: _buildStatTile(
              title: 'Student Wallets',
              value: 'Recharge Directory',
              badge: 'Balances',
              icon: Icons.account_balance_wallet_rounded,
              color: const Color(0xFF7B42F6),
              onTap: () => widget.onOpenModule(ModuleCatalog.canteen, 'wallet'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildStatTile(
              title: 'Activity Ledger',
              value: 'Transactions',
              badge: 'Recent Audit',
              icon: Icons.receipt_long_rounded,
              color: const Color(0xFF007A70),
              onTap: () => widget.onOpenModule(ModuleCatalog.canteen, 'transactions'),
            ),
          ),
        ],
      );
    }

    if (session.isStationeryOwner) {
      return Row(
        children: [
          Expanded(
            child: _buildStatTile(
              title: 'Store Catalog',
              value: 'Items & Prices',
              badge: 'Stock Active',
              icon: Icons.menu_book_rounded,
              color: const Color(0xFF007A70),
              onTap: () => widget.onOpenModule(ModuleCatalog.canteen, 'menu'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildStatTile(
              title: 'Student Orders',
              value: 'Pending Queue',
              badge: 'Fulfillment',
              icon: Icons.shopping_bag_outlined,
              color: const Color(0xFF059669),
              onTap: () => widget.onOpenModule(ModuleCatalog.canteen, 'orders'),
            ),
          ),
        ],
      );
    }

    if (session.isFaculty) {
      return Row(
        children: [
          Expanded(
            child: _buildStatTile(
              title: 'Attendance Desk',
              value: 'Roll Call',
              badge: "Today's Mark",
              icon: Icons.fact_check_outlined,
              color: const Color(0xFF7B42F6),
              onTap: () => widget.onOpenModule(ModuleCatalog.attendance, 'mark'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildStatTile(
              title: 'Timetable',
              value: 'Lectures',
              badge: 'Schedule',
              icon: Icons.schedule_rounded,
              color: const Color(0xFF9D4EDD),
              onTap: () => widget.onOpenModule(ModuleCatalog.timetable),
            ),
          ),
        ],
      );
    }

    if (session.isSecurityStaff) {
      return Row(
        children: [
          Expanded(
            child: _buildStatTile(
              title: 'Gate Scanner',
              value: 'Scan Outpass',
              badge: 'Verification',
              icon: Icons.qr_code_scanner_rounded,
              color: const Color(0xFF007A70),
              onTap: widget.onScan != null ? () => widget.onScan!(context) : () => widget.onOpenModule(ModuleCatalog.gatepass, 'scan'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildStatTile(
              title: 'Movement Logs',
              value: 'Gate History',
              badge: 'Live Log',
              icon: Icons.history_rounded,
              color: const Color(0xFF0D9488),
              onTap: () => widget.onOpenModule(ModuleCatalog.gatepass, 'movement_logs'),
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildSalesHeroCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? const Color(0xFF17181D) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => widget.onOpenModule(ModuleCatalog.canteen, 'dashboard'),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF2B2C34) : const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF059669).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.storefront_rounded,
                  color: _accentInk(const Color(0xFF059669)),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Live Metrics',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF059669).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Counters Active',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: _accentInk(const Color(0xFF059669)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Shops & Sales Dashboard',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark ? const Color(0xFFA3A5B0) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: context.palette.inkTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatTile({
    required String title,
    required String value,
    required String badge,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isDark ? const Color(0xFF17181D) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? const Color(0xFF2B2C34) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: _accentInk(color), size: 18),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: _accentInk(color),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  letterSpacing: -0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 1),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isDark ? const Color(0xFFA3A5B0) : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 4. CATEGORY FILTER TABS
  // ===========================================================================
  Widget _buildCategoryFilterBar(BuildContext context) {
    final categories = [
      'All Services',
      'Administration',
      'Academics',
      'Commerce & Ops',
      'Facilities & Security',
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          for (var i = 0; i < categories.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            _buildFilterChip(
              label: categories[i],
              isSelected: _selectedCategoryIndex == i,
              onTap: () => setState(() => _selectedCategoryIndex = i),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isSelected
          ? const Color(0xFF7B42F6)
          : isDark
              ? const Color(0xFF17181D)
              : Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF7B42F6)
                  : isDark
                      ? const Color(0xFF2B2C34)
                      : const Color(0xFFE2E8F0),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected
                  ? Colors.white
                  : isDark
                      ? const Color(0xFFE2E8F0)
                      : const Color(0xFF475569),
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 5. WORKSPACE BENTO GRID OF APPS (Zero text walls, sleek & clickable)
  // ===========================================================================
  Widget _buildWorkspaceBentoGrid(BuildContext context) {
    final List<Widget> tiles = [];

    // Category 0 = All, 1 = Administration, 2 = Academics, 3 = Commerce & Ops, 4 = Facilities & Security
    final showAll = _selectedCategoryIndex == 0;
    final showAdmin = showAll || _selectedCategoryIndex == 1;
    final showAcademics = showAll || _selectedCategoryIndex == 2;
    final showCommerce = showAll || _selectedCategoryIndex == 3;
    final showFacilities = showAll || _selectedCategoryIndex == 4;

    // --- Administration & Student Management ---
    if (permissions.canSeeModule(ModuleCatalog.administration) && showAdmin) {
      tiles.add(_buildAppTile(
        title: 'Admin Desk',
        tag: 'Control & Access',
        icon: Icons.admin_panel_settings_rounded,
        color: const Color(0xFF7B42F6),
        onTap: () => widget.onOpenModule(ModuleCatalog.administration),
      ));
      tiles.add(_buildAppTile(
        title: 'Student Directory',
        tag: 'Registry & Residency',
        icon: Icons.school_rounded,
        color: const Color(0xFF7B42F6),
        onTap: () => widget.onOpenModule(ModuleCatalog.administration, 'students'),
      ));
      tiles.add(_buildAppTile(
        title: 'User Accounts',
        tag: 'Roles & Credentials',
        icon: Icons.manage_accounts_rounded,
        color: const Color(0xFF9B1FE8),
        onTap: () => widget.onOpenModule(ModuleCatalog.administration, 'access_control'),
      ));
      tiles.add(_buildAppTile(
        title: 'Announcements',
        tag: 'Campus Circulars',
        icon: Icons.campaign_rounded,
        color: const Color(0xFFEA580C),
        onTap: () => widget.onOpenModule(ModuleCatalog.administration, 'announcements'),
      ));
    }
    if (_openPushNotifications != null && showAdmin) {
      tiles.add(_buildAppTile(
        title: 'Push Notifications',
        tag: 'Broadcasts',
        icon: Icons.notifications_active_rounded,
        color: AppColors.hotPinkInk,
        onTap: _openPushNotifications!,
      ));
    }

    // --- Commerce & Ops ---
    if (permissions.canSeeModule(ModuleCatalog.canteen) && showCommerce) {
      if (session.isCaptain) {
        tiles.add(_buildAppTile(
          title: 'Canteen Orders',
          tag: 'Live Counter',
          icon: Icons.restaurant_rounded,
          color: const Color(0xFF059669),
          onTap: () => widget.onOpenModule(ModuleCatalog.canteen, 'orders'),
        ));
      } else if (session.isAccountant) {
        tiles.add(_buildAppTile(
          title: 'Student Wallets',
          tag: 'Recharges',
          icon: Icons.account_balance_wallet_rounded,
          color: const Color(0xFF7B42F6),
          onTap: () => widget.onOpenModule(ModuleCatalog.canteen, 'wallet'),
        ));
      } else if (session.isStationeryOwner) {
        tiles.add(_buildAppTile(
          title: 'Stationery Catalog',
          tag: 'Store & Stock',
          icon: Icons.edit_note_rounded,
          color: const Color(0xFF007A70),
          onTap: () => widget.onOpenModule(ModuleCatalog.canteen, 'menu'),
        ));
      } else {
        tiles.add(_buildAppTile(
          title: 'Shops & Sales',
          tag: 'Live Analytics',
          icon: Icons.storefront_rounded,
          color: const Color(0xFF059669),
          onTap: () => widget.onOpenModule(ModuleCatalog.canteen, 'dashboard'),
        ));
      }
    }

    if (permissions.canSeeModule(ModuleCatalog.tuitionFee) && showCommerce) {
      tiles.add(_buildAppTile(
        title: 'Tuition & Fees',
        tag: 'Invoices & Dues',
        icon: Icons.receipt_long_rounded,
        color: const Color(0xFF007A70),
        onTap: () => widget.onOpenModule(ModuleCatalog.tuitionFee),
      ));
    }

    if (permissions.canSeeModule(ModuleCatalog.canteen) && !session.isAccountant && showCommerce) {
      tiles.add(_buildAppTile(
        title: 'Student Wallets',
        tag: 'Recharges',
        icon: Icons.account_balance_wallet_rounded,
        color: const Color(0xFF7B42F6),
        onTap: () => widget.onOpenModule(ModuleCatalog.canteen, 'wallet'),
      ));
    }

    if (permissions.canSeeModule(ModuleCatalog.vendorManagement) && showCommerce) {
      tiles.add(_buildAppTile(
        title: 'Vendors & Orders',
        tag: 'Procurement',
        icon: Icons.handshake_outlined,
        color: const Color(0xFF0D9488),
        onTap: () => widget.onOpenModule(ModuleCatalog.vendorManagement),
      ));
    }

    if (_openReports != null && showCommerce) {
      tiles.add(_buildAppTile(
        title: 'Reports',
        tag: 'PDF & CSV',
        icon: Icons.summarize_rounded,
        color: AppColors.brandViolet,
        onTap: _openReports!,
      ));
    }

    if (_openPaymentRequests != null && showCommerce) {
      tiles.add(_buildAppTile(
        title: 'Payment Requests',
        tag: 'Fines & Bills',
        icon: Icons.request_quote_rounded,
        color: AppColors.orangeInk,
        onTap: _openPaymentRequests!,
      ));
    }

    if (_openOnlinePayments != null && showCommerce) {
      tiles.add(_buildAppTile(
        title: 'Online Payments',
        tag: 'Razorpay',
        icon: Icons.credit_score_rounded,
        color: AppColors.success,
        onTap: _openOnlinePayments!,
      ));
    }

    // --- Academics ---
    if (permissions.canSeeModule(ModuleCatalog.attendance) && showAcademics) {
      tiles.add(_buildAppTile(
        title: 'Attendance Desk',
        tag: 'Roll & Rosters',
        icon: Icons.fact_check_outlined,
        color: const Color(0xFF7B42F6),
        onTap: () => widget.onOpenModule(ModuleCatalog.attendance),
      ));
    }

    if (permissions.canSeeModule(ModuleCatalog.timetable) && showAcademics) {
      tiles.add(_buildAppTile(
        title: 'Timetable',
        tag: 'Master Schedule',
        icon: Icons.schedule_rounded,
        color: const Color(0xFF9D4EDD),
        onTap: () => widget.onOpenModule(ModuleCatalog.timetable),
      ));
    }

    if (permissions.canSeeModule(ModuleCatalog.academics) && showAcademics) {
      tiles.add(_buildAppTile(
        title: 'Curriculum & Depts',
        tag: 'Programmes',
        icon: Icons.auto_stories_outlined,
        color: const Color(0xFF7B42F6),
        onTap: () => widget.onOpenModule(ModuleCatalog.academics),
      ));
    }

    if (permissions.canSeeModule(ModuleCatalog.examination) && (showAcademics || showAdmin)) {
      tiles.add(_buildAppTile(
        title: 'Examinations',
        tag: 'Marks & Results',
        icon: Icons.assignment_outlined,
        color: const Color(0xFF9B1FE8),
        onTap: () => widget.onOpenModule(ModuleCatalog.examination),
      ));
    }

    // --- Facilities & Security ---
    if (permissions.canSeeModule(ModuleCatalog.gatepass) && (showFacilities || showAll)) {
      tiles.add(_buildAppTile(
        title: 'Gate Security',
        tag: 'Passes & Checkpoint',
        icon: Icons.qr_code_scanner_rounded,
        color: const Color(0xFF007A70),
        onTap: () => widget.onOpenModule(ModuleCatalog.gatepass),
      ));
    }

    if (permissions.canSeeModule(ModuleCatalog.library) && showFacilities) {
      tiles.add(_buildAppTile(
        title: 'Central Library',
        tag: 'Catalog & Lending',
        icon: Icons.local_library_outlined,
        color: const Color(0xFF9B1FE8),
        onTap: () => widget.onOpenModule(ModuleCatalog.library),
      ));
    }

    if (permissions.canSeeModule(ModuleCatalog.hostel) && showFacilities) {
      tiles.add(_buildAppTile(
        title: 'Hostel Residency',
        tag: 'Room Allotment',
        icon: Icons.apartment_rounded,
        color: const Color(0xFF64748B),
        onTap: () => widget.onOpenModule(ModuleCatalog.hostel),
      ));
    }

    if (tiles.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 30),
          child: Text(
            'No workspaces in this category',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 500;
        return GridView.count(
          crossAxisCount: isWide ? 3 : 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: isWide ? 1.5 : 1.35,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: tiles,
        );
      },
    );
  }

  Widget _buildAppTile({
    required String title,
    required String tag,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isDark ? const Color(0xFF17181D) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF2B2C34) : const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: _accentInk(color), size: 20),
                  ),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 14,
                    color: context.palette.inkTertiary,
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    tag,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _accentInk(color),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(
    String title,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: _accentInk(color)),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                letterSpacing: -0.1,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? const Color(0xFFA3A5B0) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AdminRow {
  const _AdminRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
}

/// A white rounded surface on the sunken page, like an iOS inset group.
class _AdminCard extends StatelessWidget {
  const _AdminCard({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: context.palette.surface,
    borderRadius: BorderRadius.circular(16),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: child,
      ),
    ),
  );
}

class _AdminMetric extends StatelessWidget {
  const _AdminMetric({
    required this.label,
    required this.value,
    this.caption,
    this.valueColor,
  });

  final String label;
  final String value;
  final String? caption;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: palette.inkSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            color: valueColor ?? palette.ink,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        Text(
          caption ?? ' ',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 11, color: palette.inkSecondary),
        ),
      ],
    );
  }
}

/// One of the accountant's two primary actions: a tall tappable card with a
/// tinted icon, so the everyday jobs are one tap from home.
class _AccountantAction extends StatelessWidget {
  const _AccountantAction({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tone = isDark ? Color.lerp(color, Colors.white, 0.35)! : color;
    return _AdminCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 22, color: tone),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
              color: palette.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12.5, color: palette.inkSecondary),
          ),
        ],
      ),
    );
  }
}

class _AdminGroup extends StatelessWidget {
  const _AdminGroup({required this.title, required this.rows});

  final String title;
  final List<_AdminRow> rows;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
              color: palette.inkSecondary,
            ),
          ),
        ),
        Material(
          color: palette.surface,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    thickness: 0.5,
                    indent: 64,
                    color: palette.divider,
                  ),
                InkWell(
                  onTap: rows[i].onTap,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 11, 12, 11),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: rows[i].color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Icon(
                            rows[i].icon,
                            size: 19,
                            color: isDark
                                ? Color.lerp(rows[i].color, Colors.white, 0.35)
                                : rows[i].color,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                rows[i].title,
                                style: TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w600,
                                  color: palette.ink,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                rows[i].subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: palette.inkSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: palette.inkTertiary,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
