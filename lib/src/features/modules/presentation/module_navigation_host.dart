import 'package:flutter/material.dart';

import '../../../core/access/effective_permissions.dart';
import '../../../core/widgets/campus_nav_bar.dart';
import '../../authentication/data/auth_repository.dart';
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
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final navHeight = CampusNavBar.heightFor(context);
    // The official bar owns the complete bottom lane. Module Scaffolds are
    // deliberately laid out above it, so a page action or an accidentally
    // retained dock can never sit behind the official navigation controls.
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
