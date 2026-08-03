import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/authentication/data/auth_repository.dart';
import 'features/authentication/data/mock_auth_repository.dart';
import 'features/authentication/presentation/login_screen.dart';
import 'features/canteen/presentation/canteen_shell.dart';
import 'features/gatepass/presentation/gatepass_shell.dart';
import 'features/modules/presentation/module_home_screen.dart';

enum _ActiveModule { modules, canteen, gatepass }

class SupercampusApp extends StatefulWidget {
  const SupercampusApp({super.key, this.authRepository});

  final AuthRepository? authRepository;

  @override
  State<SupercampusApp> createState() => _SupercampusAppState();
}

class _SupercampusAppState extends State<SupercampusApp> {
  late final AuthRepository _authRepository;
  StudentSession? _session;
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
        onOpenGatepass: () =>
            setState(() => _activeModule = _ActiveModule.gatepass),
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
    };
  }
}
