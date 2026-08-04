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

enum _ActiveStudentModule { modules, canteen, gatepass, timetable }
enum _ActiveFacultyModule { modules, attendance, timetable }

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
  var _activeFacultyModule = _ActiveFacultyModule.modules;

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
        _activeFacultyModule = _ActiveFacultyModule.modules;
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
          _activeFacultyModule = _ActiveFacultyModule.modules;
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
      UserRole.staff => _buildFacultyFlow(session),
      UserRole.timetableAllocator => TimetableShell(
          session: session,
          onSignOut: () => setState(() => _session = null),
          onSwitchRole: _switchRole,
        ),
    };
  }

  Widget _buildFacultyFlow(UserSession session) {
    return switch (_activeFacultyModule) {
      _ActiveFacultyModule.modules => ModuleHomeScreen(
          session: session,
          onOpenAttendance: () =>
              setState(() => _activeFacultyModule = _ActiveFacultyModule.attendance),
          onOpenTimetable: () =>
              setState(() => _activeFacultyModule = _ActiveFacultyModule.timetable),
          onOpenCanteen: () {},
          onOpenGatepass: () {},
          onSignOut: () => setState(() => _session = null),
          onSwitchRole: _switchRole,
        ),
      _ActiveFacultyModule.attendance => FacultyPortalScreen(
          session: session,
          onSignOut: () => setState(() => _session = null),
          onSwitchRole: _switchRole,
        ),
      _ActiveFacultyModule.timetable => TimetableShell(
          session: session,
          onExitModule: () =>
              setState(() => _activeFacultyModule = _ActiveFacultyModule.modules),
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
          onOpenTimetable: () =>
              setState(() => _activeStudentModule = _ActiveStudentModule.timetable),
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
      _ActiveStudentModule.timetable => TimetableShell(
          session: session,
          onExitModule: () =>
              setState(() => _activeStudentModule = _ActiveStudentModule.modules),
          onSignOut: () => setState(() => _session = null),
          onSwitchRole: _switchRole,
        ),
    };
  }
}
