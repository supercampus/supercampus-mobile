import 'package:flutter/material.dart';

import '../../../core/access/effective_permissions.dart';
import '../../../core/access/module_catalog.dart';
import '../../../core/widgets/campus_nav_bar.dart';
import '../../advisor/data/advisor_students_repository.dart';
import '../../advisor/presentation/advisor_students_section.dart';
import '../../authentication/data/auth_repository.dart';
import '../../modules/presentation/today_glance.dart';
import '../../modules/presentation/widgets/home_sheets.dart';

/// Clean, optimized, and executive-grade dashboard for institutional staff and administrators.
///
/// Removes the old scrollable cards and stacked cards across tenant MEC, providing
/// a neat, accessible, high-contrast workspace tailored to each role
/// (Admin, Captain, Accountant, Stationery Owner, Faculty, Security, Librarian, Warden, Staff).
class AdminDashboardScreen extends StatelessWidget {
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
    this.advisorStudentsSource,
    this.glance,
    this.onOpenAttendanceClass,
  });

  final UserSession session;
  final EffectivePermissions permissions;
  final void Function(String moduleId, [String? action]) onOpenModule;
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

  Color _roleColor() {
    if (session.isAdmin) return const Color(0xFF4F46E5);
    if (session.isCaptain) return const Color(0xFF059669);
    if (session.isAccountant) return const Color(0xFF4F46E5);
    if (session.isStationeryOwner) return const Color(0xFF0891B2);
    if (session.isFaculty) return const Color(0xFF2563EB);
    if (session.isSecurityStaff) return const Color(0xFF0284C7);
    if (session.isLibrarian) return const Color(0xFF9333EA);
    if (session.isHostelWarden) return const Color(0xFFD97706);
    return const Color(0xFF475569);
  }

  IconData _roleIcon() {
    if (session.isAdmin) return Icons.admin_panel_settings_rounded;
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
    if (session.isAdmin) return ModuleCatalog.administration;
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

    final hasAdminConsole = session.isAdmin || permissions.canSeeModule(ModuleCatalog.administration);
    final hasCommerceServices = permissions.canSeeModule(ModuleCatalog.canteen) ||
        permissions.canSeeModule(ModuleCatalog.tuitionFee) ||
        permissions.canSeeModule(ModuleCatalog.vendorManagement);
    final hasSecurityServices = permissions.canSeeModule(ModuleCatalog.gatepass);
    final hasAcademicServices = permissions.canSeeModule(ModuleCatalog.attendance) ||
        permissions.canSeeModule(ModuleCatalog.examination) ||
        permissions.canSeeModule(ModuleCatalog.timetable) ||
        permissions.canSeeModule(ModuleCatalog.academics);
    final hasFacilityServices = permissions.canSeeModule(ModuleCatalog.library) ||
        permissions.canSeeModule(ModuleCatalog.hostel);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: Stack(
                children: [
                  ListView(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      12,
                      16,
                      CampusNavBar.heightFor(context) +
                          MediaQuery.paddingOf(context).bottom +
                          30,
                    ),
                    children: [
                      _buildWelcomeBanner(context),
                      const SizedBox(height: 16),
                      _buildKpiSummary(context),
                      if (hasAdminConsole) ...[
                        const SizedBox(height: 22),
                        _buildSectionHeader(
                          context,
                          title: 'Administrative Console',
                          subtitle: 'Core institution control, directories & notices',
                          icon: Icons.admin_panel_settings_outlined,
                          iconColor: const Color(0xFF4F46E5),
                        ),
                        const SizedBox(height: 12),
                        _buildCoreAdminGrid(context),
                      ],
                      if (hasCommerceServices) ...[
                        const SizedBox(height: 24),
                        _buildCommerceSectionHeader(context),
                        const SizedBox(height: 12),
                        _buildCommerceServices(context),
                      ],
                      if (hasSecurityServices) ...[
                        const SizedBox(height: 24),
                        _buildSecuritySectionHeader(context),
                        const SizedBox(height: 12),
                        _buildSecurityServices(context),
                      ],
                      if (hasAcademicServices) ...[
                        const SizedBox(height: 24),
                        _buildSectionHeader(
                          context,
                          title: 'Academic Management',
                          subtitle: 'Rosters, schedules, grading & campus facilities',
                          icon: Icons.school_outlined,
                          iconColor: const Color(0xFF2563EB),
                        ),
                        const SizedBox(height: 12),
                        _buildAcademicServices(context),
                      ],
                      if (hasFacilityServices) ...[
                        const SizedBox(height: 24),
                        _buildSectionHeader(
                          context,
                          title: 'Campus Facilities',
                          subtitle: 'Central library, reading halls & hostel blocks',
                          icon: Icons.apartment_rounded,
                          iconColor: const Color(0xFF9333EA),
                        ),
                        const SizedBox(height: 12),
                        _buildFacilityServices(context),
                      ],
                      if (advisorStudentsSource != null) ...[
                        const SizedBox(height: 24),
                        _buildSectionHeader(
                          context,
                          title: 'Advisee Students',
                          subtitle: 'Student mentorship, profiles & performance tracking',
                          icon: Icons.people_outline_rounded,
                          iconColor: const Color(0xFF4F46E5),
                        ),
                        const SizedBox(height: 12),
                        AdvisorStudentsSection(source: advisorStudentsSource!),
                      ],
                      if (glance != null && permissions.canSeeModule(ModuleCatalog.attendance)) ...[
                        const SizedBox(height: 24),
                        _buildSectionHeader(
                          context,
                          title: "Today's Schedule & Roll",
                          subtitle: 'Assigned lecture periods and class roll call',
                          icon: Icons.calendar_today_rounded,
                          iconColor: const Color(0xFF0284C7),
                        ),
                        const SizedBox(height: 12),
                        TodayGlance(
                          permissions: permissions,
                          facts: glance!,
                          onOpenModule: (id) => onOpenModule(id),
                          onOpenClass: onOpenAttendanceClass,
                        ),
                      ],
                    ],
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: MediaQuery.paddingOf(context).bottom + 10,
                    child: CampusNavBar(
                      selectedId: 'home',
                      initials: initialsOf(session.displayName),
                      avatarUrl: session.photoUrl,
                      onHome: () {},
                      onModules: () => onOpenModule(_primaryModuleId()),
                      onProfile: onProfileTap,
                      onScan: onScan == null ? null : () => onScan!(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    final theme = Theme.of(context);
    final roleColor = _roleColor();
    final roleIcon = _roleIcon();
    final roleBadge = session.roleBadgeText;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: roleColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              roleIcon,
              color: roleColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'SuperCampus',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
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
                  session.email.isNotEmpty ? session.email : session.roleDisplayTitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                    fontSize: 11.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Campus notifications',
            onPressed: onAlertsTap,
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_none_rounded),
                if (hasAlerts)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Profile & Settings',
            onPressed: onProfileTap,
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeBanner(BuildContext context) {
    final displayName = session.displayName.isNotEmpty
        ? session.displayName
        : session.roleBadgeText;
    final roleTitle = session.roleDisplayTitle;
    final department = session.department;
    final subtitle = (department != null && department.isNotEmpty)
        ? '$roleTitle · Dept of $department'
        : roleTitle;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, $displayName',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E293B),
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Mahindra Engineering College · Active Session',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiSummary(BuildContext context) {
    if (session.isCaptain) {
      return Row(
        children: [
          Expanded(
            child: _buildMetricTile(
              title: 'Live Orders',
              value: 'Orders Queue',
              subtitle: 'Active counter queue',
              icon: Icons.receipt_long_rounded,
              iconColor: const Color(0xFF059669),
              onTap: () => onOpenModule(ModuleCatalog.canteen, 'orders'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildMetricTile(
              title: 'Quick Scan',
              value: 'Scan Token',
              subtitle: 'Verify student order QR',
              icon: Icons.qr_code_scanner_rounded,
              iconColor: const Color(0xFF0891B2),
              onTap: onScan != null ? () => onScan!(context) : () => onOpenModule(ModuleCatalog.canteen, 'orders'),
            ),
          ),
        ],
      );
    }

    if (session.isAccountant) {
      return Row(
        children: [
          Expanded(
            child: _buildMetricTile(
              title: 'Student Wallets',
              value: 'Recharges',
              subtitle: 'Browse student balances',
              icon: Icons.account_balance_wallet_rounded,
              iconColor: const Color(0xFF4F46E5),
              onTap: () => onOpenModule(ModuleCatalog.canteen, 'wallet'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildMetricTile(
              title: 'Ledger Activity',
              value: 'Transactions',
              subtitle: 'Recent credit history',
              icon: Icons.receipt_long_rounded,
              iconColor: const Color(0xFF0284C7),
              onTap: () => onOpenModule(ModuleCatalog.canteen, 'transactions'),
            ),
          ),
        ],
      );
    }

    if (session.isStationeryOwner) {
      return Row(
        children: [
          Expanded(
            child: _buildMetricTile(
              title: 'Store Catalog',
              value: 'Inventory',
              subtitle: 'Stationery items & prices',
              icon: Icons.menu_book_rounded,
              iconColor: const Color(0xFF0891B2),
              onTap: () => onOpenModule(ModuleCatalog.canteen, 'menu'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildMetricTile(
              title: 'Item Orders',
              value: 'Pending Queue',
              subtitle: 'Student print & items',
              icon: Icons.shopping_bag_outlined,
              iconColor: const Color(0xFF059669),
              onTap: () => onOpenModule(ModuleCatalog.canteen, 'orders'),
            ),
          ),
        ],
      );
    }

    if (session.isFaculty) {
      return Row(
        children: [
          Expanded(
            child: _buildMetricTile(
              title: 'Class Attendance',
              value: 'Roll Call',
              subtitle: "Mark today's attendance",
              icon: Icons.fact_check_outlined,
              iconColor: const Color(0xFF2563EB),
              onTap: () => onOpenModule(ModuleCatalog.attendance, 'mark'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildMetricTile(
              title: 'Examinations',
              value: 'Internal Marks',
              subtitle: 'Batch score entry',
              icon: Icons.assignment_outlined,
              iconColor: const Color(0xFF6366F1),
              onTap: () => onOpenModule(ModuleCatalog.examination, 'marks'),
            ),
          ),
        ],
      );
    }

    if (session.isSecurityStaff) {
      return Row(
        children: [
          Expanded(
            child: _buildMetricTile(
              title: 'Gate Scanner',
              value: 'Scan Pass',
              subtitle: 'Verify student outpass',
              icon: Icons.qr_code_scanner_rounded,
              iconColor: const Color(0xFF0284C7),
              onTap: onScan != null ? () => onScan!(context) : () => onOpenModule(ModuleCatalog.gatepass, 'scan'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildMetricTile(
              title: 'Movement Logs',
              value: 'Gate History',
              subtitle: 'Campus entry & exits',
              icon: Icons.history_rounded,
              iconColor: const Color(0xFF0D9488),
              onTap: () => onOpenModule(ModuleCatalog.gatepass, 'movement_logs'),
            ),
          ),
        ],
      );
    }

    if (session.isLibrarian) {
      return Row(
        children: [
          Expanded(
            child: _buildMetricTile(
              title: 'Book Catalog',
              value: 'Library Search',
              subtitle: 'Find titles & authors',
              icon: Icons.local_library_outlined,
              iconColor: const Color(0xFF9333EA),
              onTap: () => onOpenModule(ModuleCatalog.library, 'catalog'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildMetricTile(
              title: 'Lending Desk',
              value: 'Circulation',
              subtitle: 'Issue & return books',
              icon: Icons.assignment_returned_outlined,
              iconColor: const Color(0xFF7C3AED),
              onTap: () => onOpenModule(ModuleCatalog.library, 'issues'),
            ),
          ),
        ],
      );
    }

    if (session.isHostelWarden) {
      return Row(
        children: [
          Expanded(
            child: _buildMetricTile(
              title: 'Hostel Blocks',
              value: 'Room Allotment',
              subtitle: 'Student residency directory',
              icon: Icons.apartment_rounded,
              iconColor: const Color(0xFFD97706),
              onTap: () => onOpenModule(ModuleCatalog.hostel),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildMetricTile(
              title: 'Outpass Approvals',
              value: 'Night Leaves',
              subtitle: 'Review student requests',
              icon: Icons.approval_rounded,
              iconColor: const Color(0xFF059669),
              onTap: () => onOpenModule(ModuleCatalog.gatepass, 'outpass_pending'),
            ),
          ),
        ],
      );
    }

    // Default / Admin:
    return Row(
      children: [
        Expanded(
          child: _buildMetricTile(
            title: 'Users & Staff',
            value: 'Admin Desk',
            subtitle: 'Role & accounts control',
            icon: Icons.manage_accounts_outlined,
            iconColor: const Color(0xFF4F46E5),
            onTap: () => onOpenModule(ModuleCatalog.administration, 'users'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMetricTile(
            title: 'Students',
            value: 'Directory',
            subtitle: 'Enrolled students',
            icon: Icons.school_outlined,
            iconColor: const Color(0xFF0284C7),
            onTap: () => onOpenModule(ModuleCatalog.administration, 'students'),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  Icon(icon, color: iconColor, size: 18),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF94A3B8),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E293B),
                letterSpacing: -0.1,
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCoreAdminGrid(BuildContext context) {
    return Column(
      children: [
        _buildActionCard(
          title: 'User Management',
          description: 'Faculty, staff & administrator accounts, role permissions and credential resets',
          icon: Icons.manage_accounts_rounded,
          accentColor: const Color(0xFF4F46E5),
          badgeText: 'Full Access',
          actions: [
            _QuickActionChip(
              label: 'Manage Users',
              onTap: () => onOpenModule(ModuleCatalog.administration, 'users'),
            ),
          ],
          onTap: () => onOpenModule(ModuleCatalog.administration, 'users'),
        ),
        const SizedBox(height: 10),
        _buildActionCard(
          title: 'Student Registry',
          description: 'Student profiles, institutional roll numbers, departments, sections and academic years',
          icon: Icons.people_alt_outlined,
          accentColor: const Color(0xFF0284C7),
          badgeText: 'Student Records',
          actions: [
            _QuickActionChip(
              label: 'View Students',
              onTap: () => onOpenModule(ModuleCatalog.administration, 'students'),
            ),
          ],
          onTap: () => onOpenModule(ModuleCatalog.administration, 'students'),
        ),
        const SizedBox(height: 10),
        _buildActionCard(
          title: 'Campus Announcements',
          description: 'Institutional broadcasts, circulars, department notifications and event notices',
          icon: Icons.campaign_outlined,
          accentColor: const Color(0xFF0D9488),
          badgeText: 'Broadcasts',
          actions: [
            _QuickActionChip(
              label: 'Post Announcement',
              onTap: () => onOpenModule(ModuleCatalog.administration, 'announcements'),
            ),
          ],
          onTap: () => onOpenModule(ModuleCatalog.administration, 'announcements'),
        ),
        const SizedBox(height: 10),
        _buildActionCard(
          title: 'Maintenance & Operations',
          description: 'Campus facility status, routine maintenance scheduling and service log updates',
          icon: Icons.build_outlined,
          accentColor: const Color(0xFFD97706),
          badgeText: 'Operations',
          actions: [
            _QuickActionChip(
              label: 'Maintenance Log',
              onTap: () => onOpenModule(ModuleCatalog.administration, 'maintenance'),
            ),
          ],
          onTap: () => onOpenModule(ModuleCatalog.administration, 'maintenance'),
        ),
      ],
    );
  }

  Widget _buildCommerceSectionHeader(BuildContext context) {
    if (session.isCaptain) {
      return _buildSectionHeader(
        context,
        title: 'Canteen Operations',
        subtitle: 'Live counter queue & token fulfillment',
        icon: Icons.restaurant_rounded,
        iconColor: const Color(0xFF059669),
      );
    }
    if (session.isAccountant) {
      return _buildSectionHeader(
        context,
        title: 'Campus Finance & Wallets',
        subtitle: 'Student accounts, balances & fee administration',
        icon: Icons.account_balance_wallet_rounded,
        iconColor: const Color(0xFF4F46E5),
      );
    }
    if (session.isStationeryOwner) {
      return _buildSectionHeader(
        context,
        title: 'Stationery Store',
        subtitle: 'Inventory stock, catalog & student requests',
        icon: Icons.edit_note_rounded,
        iconColor: const Color(0xFF0891B2),
      );
    }
    return _buildSectionHeader(
      context,
      title: 'Campus Commerce & Services',
      subtitle: 'Live vendor operations, security & financials',
      icon: Icons.storefront_outlined,
      iconColor: const Color(0xFF059669),
    );
  }

  Widget _buildCommerceServices(BuildContext context) {
    final List<Widget> cards = [];

    if (permissions.canSeeModule(ModuleCatalog.canteen)) {
      if (session.isCaptain) {
        cards.add(
          _buildActionCard(
            title: 'Canteen Counter & Orders',
            description: 'Live student food orders, kitchen preparation, ready tokens and counter fulfillment',
            icon: Icons.restaurant_rounded,
            accentColor: const Color(0xFF059669),
            badgeText: 'Counter Desk',
            actions: [
              _QuickActionChip(
                label: 'Order Queue',
                onTap: () => onOpenModule(ModuleCatalog.canteen, 'orders'),
              ),
              _QuickActionChip(
                label: 'Order History',
                onTap: () => onOpenModule(ModuleCatalog.canteen, 'order_history'),
              ),
              if (onScan != null)
                _QuickActionChip(
                  label: 'Scan Token',
                  onTap: () => onScan!(context),
                ),
            ],
            onTap: () => onOpenModule(ModuleCatalog.canteen),
          ),
        );
      } else if (session.isAccountant) {
        cards.add(
          _buildActionCard(
            title: 'Student Wallets & Recharges',
            description: 'Search student accounts, credit wallet balances, review ledger entries and manage online top-up limits',
            icon: Icons.account_balance_wallet_rounded,
            accentColor: const Color(0xFF4F46E5),
            badgeText: 'Finance Desk',
            actions: [
              _QuickActionChip(
                label: 'Wallet Directory',
                onTap: () => onOpenModule(ModuleCatalog.canteen, 'wallet'),
              ),
              _QuickActionChip(
                label: 'Credit Balance',
                onTap: () => onOpenModule(ModuleCatalog.canteen, 'top_up'),
              ),
              _QuickActionChip(
                label: 'Activity Ledger',
                onTap: () => onOpenModule(ModuleCatalog.canteen, 'transactions'),
              ),
            ],
            onTap: () => onOpenModule(ModuleCatalog.canteen),
          ),
        );
      } else if (session.isStationeryOwner) {
        cards.add(
          _buildActionCard(
            title: 'Stationery Store Operations',
            description: 'Manage stationery item prices, stock availability, student printing requests and counter orders',
            icon: Icons.edit_note_rounded,
            accentColor: const Color(0xFF0891B2),
            badgeText: 'Store Desk',
            actions: [
              _QuickActionChip(
                label: 'Inventory Catalog',
                onTap: () => onOpenModule(ModuleCatalog.canteen, 'menu'),
              ),
              _QuickActionChip(
                label: 'Item Orders',
                onTap: () => onOpenModule(ModuleCatalog.canteen, 'orders'),
              ),
            ],
            onTap: () => onOpenModule(ModuleCatalog.canteen),
          ),
        );
      } else if (session.isAdmin) {
        cards.add(
          _buildActionCard(
            title: 'Shops & Sales Dashboard',
            description: 'Real-time sales tracking, counter order volume, revenue analytics and vendor operations',
            icon: Icons.storefront_rounded,
            accentColor: const Color(0xFF059669),
            badgeText: 'Live Metrics',
            actions: [
              _QuickActionChip(
                label: 'Sales Dashboard',
                onTap: () => onOpenModule(ModuleCatalog.canteen, 'dashboard'),
              ),
              _QuickActionChip(
                label: 'Vendors & Counters',
                onTap: () => onOpenModule(ModuleCatalog.canteen, 'vendors'),
              ),
              _QuickActionChip(
                label: 'Live Orders',
                onTap: () => onOpenModule(ModuleCatalog.canteen, 'orders'),
              ),
            ],
            onTap: () => onOpenModule(ModuleCatalog.canteen),
          ),
        );
      } else {
        cards.add(
          _buildActionCard(
            title: 'Campus Dining & Stores',
            description: 'Campus cafeteria, stationery store, food orders and dining transactions',
            icon: Icons.storefront_rounded,
            accentColor: const Color(0xFF059669),
            badgeText: 'Dining',
            actions: [
              _QuickActionChip(
                label: 'Browse Store',
                onTap: () => onOpenModule(ModuleCatalog.canteen, 'menu'),
              ),
              _QuickActionChip(
                label: 'My Orders',
                onTap: () => onOpenModule(ModuleCatalog.canteen, 'orders'),
              ),
            ],
            onTap: () => onOpenModule(ModuleCatalog.canteen),
          ),
        );
      }
    }

    if (permissions.canSeeModule(ModuleCatalog.tuitionFee)) {
      cards.add(
        _buildActionCard(
          title: 'Tuition & Fee Collection',
          description: 'Semester tuition fees, invoice generation, payment receipts and outstanding dues ledger',
          icon: Icons.receipt_long_rounded,
          accentColor: const Color(0xFF0284C7),
          badgeText: 'Fees',
          actions: [
            _QuickActionChip(
              label: 'Fee Invoices',
              onTap: () => onOpenModule(ModuleCatalog.tuitionFee, 'dues'),
            ),
            _QuickActionChip(
              label: 'Payment Receipts',
              onTap: () => onOpenModule(ModuleCatalog.tuitionFee, 'receipts'),
            ),
          ],
          onTap: () => onOpenModule(ModuleCatalog.tuitionFee),
        ),
      );
    }

    if (permissions.canSeeModule(ModuleCatalog.vendorManagement)) {
      cards.add(
        _buildActionCard(
          title: 'Vendor Management',
          description: 'Campus supplier contracts, procurement purchase orders, vendor invoices and work fulfillment',
          icon: Icons.handshake_outlined,
          accentColor: const Color(0xFF0D9488),
          badgeText: 'Procurement',
          actions: [
            _QuickActionChip(
              label: 'Vendors List',
              onTap: () => onOpenModule(ModuleCatalog.vendorManagement, 'vendors'),
            ),
            _QuickActionChip(
              label: 'Purchase Orders',
              onTap: () => onOpenModule(ModuleCatalog.vendorManagement, 'purchase_orders'),
            ),
          ],
          onTap: () => onOpenModule(ModuleCatalog.vendorManagement),
        ),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          cards[i],
        ],
      ],
    );
  }

  Widget _buildSecuritySectionHeader(BuildContext context) {
    if (session.isSecurityStaff) {
      return _buildSectionHeader(
        context,
        title: 'Gate Security & Checkpoint',
        subtitle: 'Live scanning, departure verification & visitor log',
        icon: Icons.security_rounded,
        iconColor: const Color(0xFF0284C7),
      );
    }
    return _buildSectionHeader(
      context,
      title: 'Gatepass & Campus Access',
      subtitle: 'Student movement approvals, visitor logs & gate security',
      icon: Icons.qr_code_scanner_rounded,
      iconColor: const Color(0xFF0891B2),
    );
  }

  Widget _buildSecurityServices(BuildContext context) {
    if (session.isSecurityStaff) {
      return _buildActionCard(
        title: 'Gate Security Checkpoint',
        description: 'Scan student outpasses, verify departure permissions, visitor check-in and daily movement logs',
        icon: Icons.qr_code_scanner_rounded,
        accentColor: const Color(0xFF0284C7),
        badgeText: 'Checkpoint Desk',
        actions: [
          if (onScan != null)
            _QuickActionChip(
              label: 'Scan Pass QR',
              onTap: () => onScan!(context),
            ),
          _QuickActionChip(
            label: 'Movement Logs',
            onTap: () => onOpenModule(ModuleCatalog.gatepass, 'movement_logs'),
          ),
          _QuickActionChip(
            label: 'Visitor Registry',
            onTap: () => onOpenModule(ModuleCatalog.gatepass, 'visitors'),
          ),
        ],
        onTap: () => onOpenModule(ModuleCatalog.gatepass),
      );
    }

    final isApprover = session.roleIds.any((r) =>
        const {'parent', 'warden', 'principal', 'class_advisor', 'hod', 'head_of_department'}.contains(r.toLowerCase()));

    if (isApprover) {
      return _buildActionCard(
        title: 'Gatepass Approvals',
        description: 'Review student outpass and leave requests, parent consent notes and issue gate clearance',
        icon: Icons.approval_rounded,
        accentColor: const Color(0xFF0891B2),
        badgeText: 'Approvals',
        actions: [
          _QuickActionChip(
            label: 'Pending Passes',
            onTap: () => onOpenModule(ModuleCatalog.gatepass, 'outpass_pending'),
          ),
          _QuickActionChip(
            label: 'Leave Requests',
            onTap: () => onOpenModule(ModuleCatalog.gatepass, 'leave_pending'),
          ),
          _QuickActionChip(
            label: 'History',
            onTap: () => onOpenModule(ModuleCatalog.gatepass, 'outpass_history'),
          ),
        ],
        onTap: () => onOpenModule(ModuleCatalog.gatepass),
      );
    }

    return _buildActionCard(
      title: 'Gatepass Security',
      description: 'Daily campus movement, security checkpoint scanning, visitor logs and outpass approvals',
      icon: Icons.qr_code_scanner_rounded,
      accentColor: const Color(0xFF0891B2),
      badgeText: 'Gate Security',
      actions: [
        _QuickActionChip(
          label: 'Access Logs',
          onTap: () => onOpenModule(ModuleCatalog.gatepass, 'logs'),
        ),
        _QuickActionChip(
          label: 'Visitors',
          onTap: () => onOpenModule(ModuleCatalog.gatepass, 'visitors'),
        ),
      ],
      onTap: () => onOpenModule(ModuleCatalog.gatepass),
    );
  }

  Widget _buildAcademicServices(BuildContext context) {
    final List<Widget> cards = [];

    if (permissions.canSeeModule(ModuleCatalog.attendance)) {
      cards.add(
        _buildActionCard(
          title: 'Attendance Desk',
          description: 'Campus-wide attendance rosters, faculty marking, daily student attendance reports',
          icon: Icons.fact_check_outlined,
          accentColor: const Color(0xFF2563EB),
          badgeText: 'Academic',
          actions: [
            _QuickActionChip(
              label: 'Take Roll Call',
              onTap: () => onOpenModule(ModuleCatalog.attendance, 'mark'),
            ),
            _QuickActionChip(
              label: 'Class Roster',
              onTap: () => onOpenModule(ModuleCatalog.attendance, 'roster'),
            ),
            _QuickActionChip(
              label: 'Reports',
              onTap: () => onOpenModule(ModuleCatalog.attendance, 'reports'),
            ),
          ],
          onTap: () => onOpenModule(ModuleCatalog.attendance),
        ),
      );
    }

    if (permissions.canSeeModule(ModuleCatalog.examination)) {
      cards.add(
        _buildActionCard(
          title: 'Examinations & Marks',
          description: 'Master examination schedules, batch marks entry, grade sheets and student report cards',
          icon: Icons.assignment_outlined,
          accentColor: const Color(0xFF6366F1),
          badgeText: 'Exams',
          actions: [
            _QuickActionChip(
              label: 'Exam Schedule',
              onTap: () => onOpenModule(ModuleCatalog.examination, 'schedule'),
            ),
            _QuickActionChip(
              label: 'Marks Entry',
              onTap: () => onOpenModule(ModuleCatalog.examination, 'marks'),
            ),
            _QuickActionChip(
              label: 'Grade Sheets',
              onTap: () => onOpenModule(ModuleCatalog.examination, 'results'),
            ),
          ],
          onTap: () => onOpenModule(ModuleCatalog.examination),
        ),
      );
    }

    if (permissions.canSeeModule(ModuleCatalog.timetable)) {
      cards.add(
        _buildActionCard(
          title: 'Timetable & Scheduling',
          description: 'Master weekly schedules, lecture room allocations and faculty substitutions',
          icon: Icons.schedule_rounded,
          accentColor: const Color(0xFF8B5CF6),
          badgeText: 'Timetable',
          actions: [
            _QuickActionChip(
              label: 'Weekly Schedule',
              onTap: () => onOpenModule(ModuleCatalog.timetable, 'schedule'),
            ),
            _QuickActionChip(
              label: 'Substitutions',
              onTap: () => onOpenModule(ModuleCatalog.timetable, 'substitution'),
            ),
          ],
          onTap: () => onOpenModule(ModuleCatalog.timetable),
        ),
      );
    }

    if (permissions.canSeeModule(ModuleCatalog.academics)) {
      cards.add(
        _buildActionCard(
          title: 'Academics & Curriculum',
          description: 'Department degree programmes, subject syllabi, class registrations and academic structures',
          icon: Icons.auto_stories_outlined,
          accentColor: const Color(0xFF3B82F6),
          badgeText: 'Curriculum',
          actions: [
            _QuickActionChip(
              label: 'Programmes',
              onTap: () => onOpenModule(ModuleCatalog.academics, 'programmes'),
            ),
            _QuickActionChip(
              label: 'Subjects',
              onTap: () => onOpenModule(ModuleCatalog.academics, 'subjects'),
            ),
          ],
          onTap: () => onOpenModule(ModuleCatalog.academics),
        ),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          cards[i],
        ],
      ],
    );
  }

  Widget _buildFacilityServices(BuildContext context) {
    final List<Widget> cards = [];

    if (permissions.canSeeModule(ModuleCatalog.library)) {
      cards.add(
        _buildActionCard(
          title: 'Library System & Books',
          description: 'Institutional library book catalog, lending desk, student borrowing and return tracking',
          icon: Icons.local_library_outlined,
          accentColor: const Color(0xFF9333EA),
          badgeText: 'Library',
          actions: [
            _QuickActionChip(
              label: 'Book Catalog',
              onTap: () => onOpenModule(ModuleCatalog.library, 'catalog'),
            ),
            _QuickActionChip(
              label: 'Lending Desk',
              onTap: () => onOpenModule(ModuleCatalog.library, 'issues'),
            ),
            _QuickActionChip(
              label: 'Announcements',
              onTap: () => onOpenModule(ModuleCatalog.library, 'announcement'),
            ),
          ],
          onTap: () => onOpenModule(ModuleCatalog.library),
        ),
      );
    }

    if (permissions.canSeeModule(ModuleCatalog.hostel)) {
      cards.add(
        _buildActionCard(
          title: 'Hostel Operations',
          description: 'Student residential blocks, room allotment, mess management and outpass records',
          icon: Icons.apartment_rounded,
          accentColor: const Color(0xFF64748B),
          badgeText: 'Hostel',
          actions: [
            _QuickActionChip(
              label: 'Room Allocations',
              onTap: () => onOpenModule(ModuleCatalog.hostel, 'residency'),
            ),
            _QuickActionChip(
              label: 'Mess Schedule',
              onTap: () => onOpenModule(ModuleCatalog.hostel, 'mess'),
            ),
          ],
          onTap: () => onOpenModule(ModuleCatalog.hostel),
        ),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          cards[i],
        ],
      ],
    );
  }

  Widget _buildActionCard({
    required String title,
    required String description,
    required IconData icon,
    required Color accentColor,
    required String badgeText,
    required List<_QuickActionChip> actions,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
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
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: accentColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1E293B),
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                badgeText,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: accentColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          description,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFFCBD5E1),
                    size: 20,
                  ),
                ],
              ),
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: actions,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionChip extends StatelessWidget {
  const _QuickActionChip({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF1F5F9),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF334155),
                ),
              ),
              const SizedBox(width: 3),
              const Icon(
                Icons.arrow_forward_rounded,
                size: 11,
                color: Color(0xFF64748B),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
