import 'package:flutter/material.dart';

import '../../../core/access/effective_permissions.dart';
import '../../../core/access/module_catalog.dart';
import '../../../core/widgets/slice_nav_bar.dart';
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
  final void Function(BuildContext context)? onScan;
  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: child),
        Positioned(
          left: 0,
          right: 0,
          bottom: MediaQuery.paddingOf(context).bottom + 10,
          child: SliceNavBar(
            destinations: const [
              SliceNavDestination(
                id: 'home',
                label: 'Home',
                icon: Icons.home_rounded,
              ),
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
            ],
            selectedId: selectedId,
            onSelect: (id) {
              switch (id) {
                case 'home':
                  onExitModule();
                case ModuleCatalog.academics:
                  if (permissions.canSeeModule(ModuleCatalog.academics)) {
                    onOpenModule(ModuleCatalog.academics);
                  }
                case 'modules':
                  _openModules(context);
                case 'profile':
                  _openProfile(context);
              }
            },
            onCenterTap: onScan == null ? null : () => onScan!(context),
            centerTooltip: 'Scanner',
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
      permissions: permissions,
      onOpenModule: onOpenModule,
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
    ),
  );
}
