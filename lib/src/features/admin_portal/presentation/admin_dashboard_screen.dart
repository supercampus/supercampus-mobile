import 'package:flutter/material.dart';

import '../../../core/access/effective_permissions.dart';
import '../../../core/access/module_catalog.dart';
import '../../../core/widgets/campus_nav_bar.dart';
import '../../advisor/data/advisor_students_repository.dart';
import '../../advisor/presentation/advisor_students_section.dart';
import '../../authentication/data/auth_repository.dart';
import '../../modules/presentation/today_glance.dart';
import '../../modules/presentation/widgets/home_sheets.dart';

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

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedCategoryIndex = 0;

  UserSession get session => widget.session;
  EffectivePermissions get permissions => widget.permissions;

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
    if (session.isAdmin) return ModuleCatalog.canteen;
    if (session.isCaptain) return ModuleCatalog.canteen;
    if (session.isAccountant) return ModuleCatalog.canteen;
    if (session.isStationeryOwner) return ModuleCatalog.canteen;
    if (session.isSecurityStaff) return ModuleCatalog.gatepass;
    if (session.isLibrarian) return ModuleCatalog.library;
    if (session.isHostelWarden) return ModuleCatalog.hostel;
    if (session.isFaculty) return ModuleCatalog.attendance;
    return ModuleCatalog.canteen;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
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
                      14,
                      16,
                      CampusNavBar.heightFor(context) +
                          MediaQuery.paddingOf(context).bottom +
                          30,
                    ),
                    children: [
                      _buildQuickActionShortcuts(context),
                      const SizedBox(height: 14),
                      _buildKpiBentoGrid(context),
                      const SizedBox(height: 18),
                      if (session.isAdmin) ...[
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
                          const Color(0xFF4F46E5),
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
                          const Color(0xFF0284C7),
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
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: MediaQuery.paddingOf(context).bottom + 10,
                    child: CampusNavBar(
                      selectedId: 'home',
                      initials: initialsOf(session.displayName),
                      avatarUrl: session.photoUrl,
                      onHome: () {},
                      onModules: () => widget.onOpenModule(_primaryModuleId()),
                      onProfile: widget.onProfileTap,
                      onScan: widget.onScan == null ? null : () => widget.onScan!(context),
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

  // ===========================================================================
  // 1. TOP BAR
  // ===========================================================================
  Widget _buildTopBar(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final roleColor = _roleColor();
    final roleIcon = _roleIcon();
    final roleBadge = session.roleBadgeText;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0),
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
                    Text(
                      'SuperCampus',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        letterSpacing: -0.3,
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
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
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
            onPressed: widget.onProfileTap,
            icon: Icon(
              Icons.settings_outlined,
              color: isDark ? Colors.white : const Color(0xFF334155),
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

    if (session.isAdmin) {
      shortcuts.addAll([
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
            color: const Color(0xFF0891B2),
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
            color: const Color(0xFF0891B2),
            onTap: () => widget.onScan!(context),
          ),
        _buildActionPill(
          icon: Icons.history_rounded,
          label: 'History',
          color: const Color(0xFF6366F1),
          onTap: () => widget.onOpenModule(ModuleCatalog.canteen, 'order_history'),
        ),
      ]);
    } else if (session.isAccountant) {
      shortcuts.addAll([
        _buildActionPill(
          icon: Icons.account_balance_wallet_rounded,
          label: 'Recharge Wallets',
          color: const Color(0xFF4F46E5),
          onTap: () => widget.onOpenModule(ModuleCatalog.canteen, 'wallet'),
        ),
        _buildActionPill(
          icon: Icons.receipt_long_rounded,
          label: 'Transactions',
          color: const Color(0xFF0284C7),
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
          color: const Color(0xFF0891B2),
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
          color: const Color(0xFF2563EB),
          onTap: () => widget.onOpenModule(ModuleCatalog.attendance, 'mark'),
        ),
        _buildActionPill(
          icon: Icons.schedule_rounded,
          label: 'My Schedule',
          color: const Color(0xFF8B5CF6),
          onTap: () => widget.onOpenModule(ModuleCatalog.timetable, 'schedule'),
        ),
      ]);
    } else if (session.isSecurityStaff) {
      shortcuts.addAll([
        if (widget.onScan != null)
          _buildActionPill(
            icon: Icons.qr_code_scanner_rounded,
            label: 'Scan Pass QR',
            color: const Color(0xFF0284C7),
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
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
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
    if (session.isAdmin) {
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
              color: const Color(0xFF0891B2),
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
              color: const Color(0xFF4F46E5),
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
              color: const Color(0xFF0284C7),
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
              color: const Color(0xFF0891B2),
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
              color: const Color(0xFF2563EB),
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
              color: const Color(0xFF8B5CF6),
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
              color: const Color(0xFF0284C7),
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
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => widget.onOpenModule(ModuleCatalog.canteen, 'dashboard'),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
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
                child: const Icon(
                  Icons.storefront_rounded,
                  color: Color(0xFF059669),
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
                          child: const Text(
                            'Counters Active',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF059669),
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
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: Color(0xFF94A3B8),
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
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
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
                    child: Icon(icon, color: color, size: 18),
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
                        color: color,
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
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
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
    final categories = ['All Services', 'Commerce & Ops', 'Academics', 'Facilities & Security'];

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
          ? const Color(0xFF4F46E5)
          : isDark
              ? const Color(0xFF1E293B)
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
                  ? const Color(0xFF4F46E5)
                  : isDark
                      ? const Color(0xFF334155)
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

    // Category 0 = All, 1 = Commerce & Ops, 2 = Academics, 3 = Facilities & Security
    final showAll = _selectedCategoryIndex == 0;
    final showCommerce = showAll || _selectedCategoryIndex == 1;
    final showAcademics = showAll || _selectedCategoryIndex == 2;
    final showFacilities = showAll || _selectedCategoryIndex == 3;

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
          color: const Color(0xFF4F46E5),
          onTap: () => widget.onOpenModule(ModuleCatalog.canteen, 'wallet'),
        ));
      } else if (session.isStationeryOwner) {
        tiles.add(_buildAppTile(
          title: 'Stationery Catalog',
          tag: 'Store & Stock',
          icon: Icons.edit_note_rounded,
          color: const Color(0xFF0891B2),
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
        color: const Color(0xFF0284C7),
        onTap: () => widget.onOpenModule(ModuleCatalog.tuitionFee),
      ));
    }

    if (permissions.canSeeModule(ModuleCatalog.canteen) && !session.isAccountant && showCommerce) {
      tiles.add(_buildAppTile(
        title: 'Student Wallets',
        tag: 'Recharges',
        icon: Icons.account_balance_wallet_rounded,
        color: const Color(0xFF4F46E5),
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

    // --- Academics ---
    if (permissions.canSeeModule(ModuleCatalog.attendance) && showAcademics) {
      tiles.add(_buildAppTile(
        title: 'Attendance Desk',
        tag: 'Roll & Rosters',
        icon: Icons.fact_check_outlined,
        color: const Color(0xFF2563EB),
        onTap: () => widget.onOpenModule(ModuleCatalog.attendance),
      ));
    }

    if (permissions.canSeeModule(ModuleCatalog.timetable) && showAcademics) {
      tiles.add(_buildAppTile(
        title: 'Timetable',
        tag: 'Master Schedule',
        icon: Icons.schedule_rounded,
        color: const Color(0xFF8B5CF6),
        onTap: () => widget.onOpenModule(ModuleCatalog.timetable),
      ));
    }

    if (permissions.canSeeModule(ModuleCatalog.academics) && showAcademics) {
      tiles.add(_buildAppTile(
        title: 'Curriculum & Depts',
        tag: 'Programmes',
        icon: Icons.auto_stories_outlined,
        color: const Color(0xFF3B82F6),
        onTap: () => widget.onOpenModule(ModuleCatalog.academics),
      ));
    }

    // --- Facilities & Security ---
    if (permissions.canSeeModule(ModuleCatalog.gatepass) && (showFacilities || showAll)) {
      tiles.add(_buildAppTile(
        title: 'Gate Security',
        tag: 'Passes & Checkpoint',
        icon: Icons.qr_code_scanner_rounded,
        color: const Color(0xFF0891B2),
        onTap: () => widget.onOpenModule(ModuleCatalog.gatepass),
      ));
    }

    if (permissions.canSeeModule(ModuleCatalog.library) && showFacilities) {
      tiles.add(_buildAppTile(
        title: 'Central Library',
        tag: 'Catalog & Lending',
        icon: Icons.local_library_outlined,
        color: const Color(0xFF9333EA),
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
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
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
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 14,
                    color: Color(0xFF94A3B8),
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
                      color: color,
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
          child: Icon(icon, size: 16, color: color),
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
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
