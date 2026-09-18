import 'package:flutter/material.dart';

import '../../../core/access/effective_permissions.dart';
import '../../../core/access/module_catalog.dart';
import '../../../core/widgets/campus_nav_bar.dart';
import '../../authentication/data/auth_repository.dart';
import '../../examination/presentation/screens/student_reports_analytics_screen.dart';
import 'widgets/campus_wall_screen.dart';
import 'widgets/dashboard_nav_bar.dart';
import 'widgets/home_sheets.dart';

/// Keeps the landing-page navigation visible while a module is open.
class ModuleNavigationHost extends StatelessWidget {
  const ModuleNavigationHost({
    super.key,
    required this.child,
    required this.session,
    required this.permissions,
    required this.onExitModule,
    required this.onOpenModule,
    required this.onSignOut,
    required this.onThemeModeChanged,
    this.moduleOrder = const [],
    this.onModuleOrderChanged,
    this.onScan,
    this.selectedId,
  });

  final Widget child;
  final UserSession session;
  final EffectivePermissions permissions;
  final VoidCallback onExitModule;
  final ValueChanged<String> onOpenModule;
  final VoidCallback onSignOut;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final List<String> moduleOrder;
  final ValueChanged<List<String>>? onModuleOrderChanged;
  final void Function(BuildContext context)? onScan;
  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    if (session.isStudent) {
      final safeBottom = MediaQuery.paddingOf(context).bottom;
      const navHeight = 76.0;
      final reservedBottom = safeBottom + navHeight;

      return Stack(
        children: [
          Positioned.fill(bottom: reservedBottom, child: child),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: DashboardNavBar(
              selectedId: selectedId ?? '',
              onSelect: (id) => _onNavSelect(context, id),
            ),
          ),
        ],
      );
    }

    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final navHeight = CampusNavBar.heightFor(context);
    final reservedBottom = safeBottom + navHeight + 20;

    return Stack(
      children: [
        Positioned.fill(bottom: reservedBottom, child: child),
        Positioned(
          left: 0,
          right: 0,
          bottom: safeBottom + 10,
          child: CampusNavBar(
            selectedId: selectedId,
            initials: initialsOf(session.displayName),
            avatarUrl: session.photoUrl,
            onHome: onExitModule,
            onModules: () => _openModules(context),
            onProfile: () => _openProfile(context),
            onScan: onScan == null ? null : () => onScan!(context),
          ),
        ),
      ],
    );
  }

  void _onNavSelect(BuildContext context, String id) {
    switch (id) {
      case 'acads':
        if (selectedId == 'acads') {
          onExitModule();
        } else {
          onOpenModule(ModuleCatalog.academics);
        }
        break;
      case 'gatepass':
        if (selectedId == 'gatepass') {
          onExitModule();
        } else {
          onOpenModule(ModuleCatalog.gatepass);
        }
        break;
      case 'wall':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const CampusWallScreen(),
          ),
        );
        break;
      case 'analysis':
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        final backgroundColor =
            isDark ? const Color(0xFF141416) : const Color(0xFFF7F7F9);
        final textColor = isDark ? Colors.white : const Color(0xFF1C1C1E);

        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => Scaffold(
              backgroundColor: backgroundColor,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                scrolledUnderElevation: 0,
                centerTitle: true,
                leading: Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Center(
                    child: Material(
                      color: isDark ? const Color(0xFF2A2A2E) : Colors.white,
                      shape: const CircleBorder(),
                      elevation: isDark ? 0 : 1,
                      shadowColor: Colors.black.withValues(alpha: 0.04),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 38,
                          height: 38,
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.chevron_left_rounded,
                            color: textColor,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                title: Text(
                  'Reports & Analysis',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              body: StudentReportsAnalyticsScreen(
                session: session,
              ),
            ),
          ),
        );
        break;
    }
  }

  void _openModules(BuildContext context) => showHomeSheet(
    context: context,
    title: 'Modules',
    expand: true,
    child: ModuleListSheet(
      session: session,
      permissions: permissions,
      onOpenModule: onOpenModule,
      moduleOrder: moduleOrder,
    ),
  );

  void _openProfile(BuildContext context) => showHomeSheet(
    context: context,
    title: 'Profile',
    expand: true,
    child: ProfileSheet(
      session: session,
      permissions: permissions,
      onOpenModule: onOpenModule,
      onSignOut: onSignOut,
      onThemeModeChanged: onThemeModeChanged,
      moduleOrder: moduleOrder,
      onModuleOrderChanged: onModuleOrderChanged,
    ),
  );
}
