import 'package:flutter/material.dart';

import 'core/access/effective_permissions.dart';
import 'core/access/mock_permissions_repository.dart';
import 'core/access/module_catalog.dart';
import 'core/access/permissions_repository.dart';
import 'core/theme/app_theme.dart';
import 'features/authentication/data/auth_repository.dart';
import 'features/authentication/data/mock_auth_repository.dart';
import 'features/authentication/presentation/login_screen.dart';
import 'features/canteen/presentation/canteen_scanner_screen.dart';
import 'features/canteen/presentation/canteen_shell.dart';
import 'features/faculty/presentation/faculty_portal_screen.dart';
import 'features/gatepass/presentation/gatepass_shell.dart';
import 'features/modules/presentation/module_dashboard_screen.dart';
import 'features/parent/presentation/parent_portal_screen.dart';
import 'features/timetable/presentation/timetable_shell.dart';

class SupercampusApp extends StatefulWidget {
  const SupercampusApp({
    super.key,
    this.authRepository,
    this.permissionsRepository,
  });

  final AuthRepository? authRepository;
  final PermissionsRepository? permissionsRepository;

  @override
  State<SupercampusApp> createState() => _SupercampusAppState();
}

class _SupercampusAppState extends State<SupercampusApp> {
  late final AuthRepository _authRepository;
  late final PermissionsRepository _permissionsRepository;

  UserSession? _session;
  EffectivePermissions? _permissions;
  String? _openModuleId;

  @override
  void initState() {
    super.initState();
    _authRepository = widget.authRepository ?? MockAuthRepository();
    _permissionsRepository =
        widget.permissionsRepository ?? const MockPermissionsRepository();
  }

  Future<void> _onSignedIn(UserSession session) async {
    setState(() {
      _session = session;
      _permissions = null;
      _openModuleId = null;
    });

    final permissions = await _permissionsRepository.loadFor(session);
    if (!mounted) return;
    setState(() => _permissions = permissions);
  }

  void _signOut() => setState(() {
    _session = null;
    _permissions = null;
    _openModuleId = null;
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SuperCampus',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: _buildHome(),
    );
  }

  Widget _buildHome() {
    final session = _session;
    if (session == null) {
      return LoginScreen(
        authRepository: _authRepository,
        onSignedIn: _onSignedIn,
      );
    }

    final permissions = _permissions;
    if (permissions == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final openModuleId = _openModuleId;
    if (openModuleId == null) {
      return ModuleDashboardScreen(
        session: session,
        permissions: permissions,
        onOpenModule: (id) => setState(() => _openModuleId = id),
        onSignOut: _signOut,
        // The scan button only earns its place in the nav bar if there is
        // something on campus to scan.
        onScan:
            permissions.canSeeModule(ModuleCatalog.canteen) ||
                permissions.canSeeModule(ModuleCatalog.gatepass)
            ? _openScanner
            : null,
      );
    }

    return _buildModule(openModuleId, session);
  }

  void _openScanner(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          backgroundColor: const Color(0xFF070907),
          body: Stack(
            children: [
              const CanteenScannerScreen(),
              Positioned(
                top: MediaQuery.paddingOf(context).top + 6,
                left: 4,
                child: const BackButton(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModule(String moduleId, UserSession session) {
    void exit() => setState(() => _openModuleId = null);

    return switch (moduleId) {
      ModuleCatalog.canteen => CanteenShell(
        session: session,
        onExitModule: exit,
        onSignOut: _signOut,
      ),
      ModuleCatalog.gatepass => session.role == UserRole.parent
          ? ParentPortalScreen(
              session: session,
              onExitModule: exit,
              onSignOut: _signOut,
            )
          : GatepassShell(session: session, onExitModule: exit),
      ModuleCatalog.timetable => TimetableShell(
        session: session,
        onExitModule: exit,
        onSignOut: _signOut,
      ),
      ModuleCatalog.attendance => FacultyPortalScreen(
        session: session,
        onExitModule: exit,
        onSignOut: _signOut,
      ),
      // A grant on a catalogued-but-unbuilt module can't reach here — the
      // dashboard disables its button — but stay defensive rather than crash.
      _ => Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: exit),
          title: Text(ModuleCatalog.byId(moduleId)?.title ?? 'Module'),
        ),
        body: const Center(child: Text('This module is not available yet.')),
      ),
    };
  }
}
