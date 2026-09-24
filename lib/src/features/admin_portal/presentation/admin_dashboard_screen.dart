import 'package:flutter/material.dart';

import '../../../core/access/effective_permissions.dart';
import '../../../core/access/module_catalog.dart';
import '../../../core/widgets/campus_nav_bar.dart';
import '../../authentication/data/auth_repository.dart';
import '../../modules/presentation/widgets/home_sheets.dart';

/// Clean, optimized, and executive-grade dashboard for institutional administrators.
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildAdminTopBar(context),
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
                      const SizedBox(height: 24),
                      _buildSectionHeader(
                        context,
                        title: 'Campus Commerce & Services',
                        subtitle: 'Live vendor operations, security & financials',
                        icon: Icons.storefront_outlined,
                        iconColor: const Color(0xFF059669),
                      ),
                      const SizedBox(height: 12),
                      _buildCommerceServices(context),
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
                      onModules: () => onOpenModule(ModuleCatalog.administration),
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

  Widget _buildAdminTopBar(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.shield_outlined,
              color: Color(0xFF4F46E5),
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
                        color: const Color(0xFF4F46E5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'ADMIN',
                        style: TextStyle(
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
                  session.email.isNotEmpty ? session.email : 'Institution Administrator',
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
            tooltip: 'Administrator profile & settings',
            onPressed: onProfileTap,
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeBanner(BuildContext context) {
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
                  'Welcome, ${session.displayName.isNotEmpty ? session.displayName : 'Administrator'}',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E293B),
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Institution overview, access controls, and operational systems are live.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFA7F3D0)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 14),
                SizedBox(width: 4),
                Text(
                  'Systems Active',
                  style: TextStyle(
                    color: Color(0xFF065F46),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
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
        _buildAdminActionCard(
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
        _buildAdminActionCard(
          title: 'Student Registry',
          description: 'Official student admissions, roll numbers, department assignments and profiles',
          icon: Icons.badge_outlined,
          accentColor: const Color(0xFF0284C7),
          badgeText: 'Full Access',
          actions: [
            _QuickActionChip(
              label: 'Student Directory',
              onTap: () => onOpenModule(ModuleCatalog.administration, 'students'),
            ),
          ],
          onTap: () => onOpenModule(ModuleCatalog.administration, 'students'),
        ),
        const SizedBox(height: 10),
        _buildAdminActionCard(
          title: 'Official Announcements',
          description: 'Publish institutional circulars, department notices, urgent broadcast alerts and approvals',
          icon: Icons.campaign_rounded,
          accentColor: const Color(0xFF7C3AED),
          badgeText: 'Publisher',
          actions: [
            _QuickActionChip(
              label: 'Publish Circular',
              onTap: () => onOpenModule(ModuleCatalog.administration, 'announcements'),
            ),
          ],
          onTap: () => onOpenModule(ModuleCatalog.administration, 'announcements'),
        ),
        const SizedBox(height: 10),
        _buildAdminActionCard(
          title: 'Campus Maintenance',
          description: 'Facility work orders, campus service tickets, repair status and campus upkeep logs',
          icon: Icons.construction_rounded,
          accentColor: const Color(0xFFD97706),
          badgeText: 'Operations',
          actions: [
            _QuickActionChip(
              label: 'Work Orders',
              onTap: () => onOpenModule(ModuleCatalog.administration, 'maintenance'),
            ),
          ],
          onTap: () => onOpenModule(ModuleCatalog.administration, 'maintenance'),
        ),
      ],
    );
  }

  Widget _buildCommerceServices(BuildContext context) {
    return Column(
      children: [
        _buildAdminActionCard(
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
        const SizedBox(height: 10),
        _buildAdminActionCard(
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
              label: 'Approvals',
              onTap: () => onOpenModule(ModuleCatalog.gatepass, 'requests'),
            ),
          ],
          onTap: () => onOpenModule(ModuleCatalog.gatepass),
        ),
        const SizedBox(height: 10),
        _buildAdminActionCard(
          title: 'Tuition & Fee Accounts',
          description: 'Fee collection ledgers, pending payments, invoice receipts and transaction audits',
          icon: Icons.account_balance_wallet_outlined,
          accentColor: const Color(0xFF10B981),
          badgeText: 'Accounts',
          actions: [
            _QuickActionChip(
              label: 'Fee Records',
              onTap: () => onOpenModule(ModuleCatalog.tuitionFee),
            ),
          ],
          onTap: () => onOpenModule(ModuleCatalog.tuitionFee),
        ),
      ],
    );
  }

  Widget _buildAcademicServices(BuildContext context) {
    return Column(
      children: [
        _buildAdminActionCard(
          title: 'Attendance Desk',
          description: 'Campus-wide attendance rosters, faculty marking, daily student attendance reports',
          icon: Icons.fact_check_outlined,
          accentColor: const Color(0xFF2563EB),
          badgeText: 'Academic',
          actions: [
            _QuickActionChip(
              label: 'Roster & Records',
              onTap: () => onOpenModule(ModuleCatalog.attendance, 'roster'),
            ),
            _QuickActionChip(
              label: 'Reports',
              onTap: () => onOpenModule(ModuleCatalog.attendance, 'reports'),
            ),
          ],
          onTap: () => onOpenModule(ModuleCatalog.attendance),
        ),
        const SizedBox(height: 10),
        _buildAdminActionCard(
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
          ],
          onTap: () => onOpenModule(ModuleCatalog.examination),
        ),
        const SizedBox(height: 10),
        _buildAdminActionCard(
          title: 'Timetable & Scheduling',
          description: 'Master weekly schedules, lecture room allocations and faculty substitutions',
          icon: Icons.schedule_rounded,
          accentColor: const Color(0xFF8B5CF6),
          badgeText: 'Timetable',
          actions: [
            _QuickActionChip(
              label: 'Master Schedule',
              onTap: () => onOpenModule(ModuleCatalog.timetable, 'schedule'),
            ),
            _QuickActionChip(
              label: 'Substitutions',
              onTap: () => onOpenModule(ModuleCatalog.timetable, 'substitutions'),
            ),
          ],
          onTap: () => onOpenModule(ModuleCatalog.timetable),
        ),
        const SizedBox(height: 10),
        _buildAdminActionCard(
          title: 'Library System',
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
          ],
          onTap: () => onOpenModule(ModuleCatalog.library),
        ),
        const SizedBox(height: 10),
        _buildAdminActionCard(
          title: 'Hostel Operations',
          description: 'Student residential blocks, room allotment, mess management and outpass records',
          icon: Icons.apartment_rounded,
          accentColor: const Color(0xFF64748B),
          badgeText: 'Hostel',
          actions: [
            _QuickActionChip(
              label: 'Room Allocations',
              onTap: () => onOpenModule(ModuleCatalog.hostel),
            ),
          ],
          onTap: () => onOpenModule(ModuleCatalog.hostel),
        ),
      ],
    );
  }

  Widget _buildAdminActionCard({
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
  const _QuickActionChip({required this.label, required this.onTap});

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
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF334155),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_forward_rounded, size: 12, color: Color(0xFF64748B)),
            ],
          ),
        ),
      ),
    );
  }
}
