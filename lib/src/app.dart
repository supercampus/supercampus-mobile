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
import 'features/timetable/presentation/timetable_shell.dart';

enum _ActiveModule { modules, canteen, gatepass, timetable, attendance, security, parent }

class SupercampusApp extends StatefulWidget {
  const SupercampusApp({super.key, this.authRepository});

  final AuthRepository? authRepository;

  @override
  State<SupercampusApp> createState() => _SupercampusAppState();
}

class _SupercampusAppState extends State<SupercampusApp> {
  late final AuthRepository _authRepository;
  UserSession? _session;
  var _activeModule = _ActiveModule.modules;

  @override
  void initState() {
    super.initState();
    _authRepository = widget.authRepository ?? MockAuthRepository();
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
          _activeModule = _ActiveModule.modules;
        }),
      );
    }

    return switch (_activeModule) {
      _ActiveModule.modules => ModuleHomeScreen(
          session: session,
          onOpenCanteen: () =>
              setState(() => _activeModule = _ActiveModule.canteen),
          onOpenGatepass: () => setState(() => _activeModule = 
              session.role == UserRole.parent ? _ActiveModule.parent : _ActiveModule.gatepass),
          onOpenTimetable: () =>
              setState(() => _activeModule = _ActiveModule.timetable),
          onOpenAttendance: () =>
              setState(() => _activeModule = _ActiveModule.attendance),
          onSignOut: () => setState(() => _session = null),
        ),
      _ActiveModule.canteen => CanteenShell(
          session: session,
          onExitModule: () =>
              setState(() => _activeModule = _ActiveModule.modules),
          onSignOut: () => setState(() => _session = null),
        ),
      _ActiveModule.gatepass => GatepassShell(
          session: session,
          onExitModule: () =>
              setState(() => _activeModule = _ActiveModule.modules),
        ),
      _ActiveModule.timetable => TimetableShell(
          session: session,
          onExitModule: () =>
              setState(() => _activeModule = _ActiveModule.modules),
          onSignOut: () => setState(() => _session = null),
        ),
      _ActiveModule.attendance => FacultyPortalScreen(
          session: session,
          onExitModule: () =>
              setState(() => _activeModule = _ActiveModule.modules),
          onSignOut: () => setState(() => _session = null),
        ),
      _ActiveModule.security => SecurityPortalScreen(
          session: session,
          onExitModule: () =>
              setState(() => _activeModule = _ActiveModule.modules),
          onSignOut: () => setState(() => _session = null),
        ),
      _ActiveModule.parent => ParentPortalScreen(
          session: session,
          onExitModule: () =>
              setState(() => _activeModule = _ActiveModule.modules),
          onSignOut: () => setState(() => _session = null),
        ),
    };
  }
}
