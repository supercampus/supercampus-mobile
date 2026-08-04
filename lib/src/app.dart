import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/authentication/data/auth_repository.dart';
import 'features/authentication/data/mock_auth_repository.dart';
import 'features/authentication/presentation/login_screen.dart';
import 'features/canteen/presentation/canteen_shell.dart';
import 'features/faculty/presentation/faculty_portal_screen.dart';
import 'features/gatepass/presentation/gatepass_shell.dart';
import 'features/modules/presentation/module_home_screen.dart';
import 'features/parent/presentation/parent_portal_screen.dart';
import 'features/security/presentation/security_portal_screen.dart';

enum _ActiveStudentModule { modules, canteen, gatepass }

class SupercampusApp extends StatefulWidget {
  const SupercampusApp({super.key, this.authRepository});

  final AuthRepository? authRepository;

  @override
  State<SupercampusApp> createState() => _SupercampusAppState();
}

class _SupercampusAppState extends State<SupercampusApp> {
  late final AuthRepository _authRepository;
  UserSession? _session;
  var _activeStudentModule = _ActiveStudentModule.modules;

  @override
  void initState() {
    super.initState();
    _authRepository = widget.authRepository ?? MockAuthRepository();
  }

  Future<void> _switchRole(UserRole role) async {
    final newSession = await _authRepository.signIn(
      email: role.defaultEmail,
      password: 'password123',
      role: role,
    );
    if (mounted) {
      setState(() {
        _session = newSession;
        _activeStudentModule = _ActiveStudentModule.modules;
      });
    }
  }

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
        onSignedIn: (signedIn) => setState(() {
          _session = signedIn;
          _activeStudentModule = _ActiveStudentModule.modules;
        }),
      );
    }

    return switch (session.role) {
      UserRole.student => _buildStudentFlow(session),
      UserRole.security => SecurityPortalScreen(
          session: session,
          onSignOut: () => setState(() => _session = null),
          onSwitchRole: _switchRole,
        ),
      UserRole.parent => ParentPortalScreen(
          session: session,
          onSignOut: () => setState(() => _session = null),
          onSwitchRole: _switchRole,
        ),
      UserRole.staff => FacultyPortalScreen(
          session: session,
          onSignOut: () => setState(() => _session = null),
          onSwitchRole: _switchRole,
        ),
    };
  }

  Widget _buildStudentFlow(UserSession session) {
    return switch (_activeStudentModule) {
      _ActiveStudentModule.modules => ModuleHomeScreen(
          session: session,
          onOpenCanteen: () =>
              setState(() => _activeStudentModule = _ActiveStudentModule.canteen),
          onOpenGatepass: () =>
              setState(() => _activeStudentModule = _ActiveStudentModule.gatepass),
          onSignOut: () => setState(() => _session = null),
          onSwitchRole: _switchRole,
        ),
      _ActiveStudentModule.canteen => CanteenShell(
          session: session,
          onExitModule: () =>
              setState(() => _activeStudentModule = _ActiveStudentModule.modules),
          onSignOut: () => setState(() => _session = null),
        ),
      _ActiveStudentModule.gatepass => GatepassShell(
          session: session,
          onExitModule: () =>
              setState(() => _activeStudentModule = _ActiveStudentModule.modules),
        ),
    };
  }
}
