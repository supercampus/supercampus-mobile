import 'package:flutter/material.dart';

import '../../../core/access/effective_permissions.dart';
import '../../../core/access/module_catalog.dart';
import '../../../core/widgets/campus_nav_bar.dart';
import '../../authentication/data/auth_repository.dart';
import '../../library/data/librarian_repository.dart';
import 'widgets/campus_wall_screen.dart';
import 'widgets/dashboard_nav_bar.dart';
import 'widgets/student_reports_page.dart';
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
    this.announcementRepository,
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
  final LibrarianRepository? announcementRepository;

  @override
  Widget build(BuildContext context) {
    if (session.isCaptain) {
      return child;
    }

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
            builder: (_) => CampusWallScreen(
              session: session,
              onOpenModule: onOpenModule,
              announcementRepository: announcementRepository,
            ),
          ),
        );
        break;
      case 'analysis':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => StudentReportsPage(
              session: session,
              onOpenModule: onOpenModule,
              announcementRepository: announcementRepository,
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
