import 'dart:async';

import 'package:flutter/material.dart';

import 'core/access/backend_permissions_repository.dart';
import 'core/access/effective_permissions.dart';
import 'core/access/mock_permissions_repository.dart';
import 'core/access/module_catalog.dart';
import 'core/access/permissions_repository.dart';
import 'core/theme/app_theme.dart';
import 'features/authentication/data/auth_repository.dart';
import 'features/authentication/data/backend_auth_repository.dart';
import 'features/authentication/data/mock_auth_repository.dart';
import 'features/authentication/presentation/login_screen.dart';
import 'features/canteen/presentation/canteen_scanner_screen.dart';
import 'features/canteen/presentation/canteen_shell.dart';
import 'features/examination/presentation/examination_shell.dart';
import 'features/faculty/presentation/faculty_portal_screen.dart';
import 'features/feedback/presentation/feedback_shell.dart';
import 'features/gatepass/presentation/gatepass_shell.dart';
import 'features/library/presentation/library_shell.dart';
import 'features/academics/presentation/academic_management_shell.dart';
import 'features/academics/presentation/student_academics_shell.dart';
import 'features/vendor_management/presentation/vendor_management_shell.dart';
import 'features/admin_portal/presentation/admin_portal_shell.dart';
import 'features/modules/presentation/module_dashboard_screen.dart';
import 'features/modules/presentation/module_navigation_host.dart';
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

class _SupercampusAppState extends State<SupercampusApp>
    with WidgetsBindingObserver {
  static const _backendBaseUrl = String.fromEnvironment(
    'SUPERCAMPUS_API_BASE_URL',
    defaultValue: 'http://localhost:4000',
  );
  static const _useMockData = bool.fromEnvironment('SUPERCAMPUS_USE_MOCK_DATA');
  static const _permissionRefreshInterval = Duration(seconds: 3);

  late final AuthRepository _authRepository;
  late final PermissionsRepository _permissionsRepository;

  UserSession? _session;
  EffectivePermissions? _permissions;
  String? _openModuleId;
  String? _openModuleAction;
  ThemeMode _themeMode = ThemeMode.system;
  Timer? _permissionRefreshTimer;
  bool _permissionRefreshInProgress = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authRepository =
        widget.authRepository ??
        (_useMockData
            ? MockAuthRepository()
            : BackendAuthRepository(baseUrl: _backendBaseUrl));
    _permissionsRepository =
        widget.permissionsRepository ??
        (_useMockData
            ? const MockPermissionsRepository()
            : BackendPermissionsRepository(baseUrl: _backendBaseUrl));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _permissionRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshPermissions());
    }
  }

  Future<void> _onSignedIn(UserSession session) async {
    setState(() {
      _session = session;
      _permissions = null;
      _openModuleId = null;
      _openModuleAction = null;
    });

    final permissions = await _permissionsRepository.loadFor(session);
    if (!mounted) return;
    setState(() => _permissions = permissions);
    _startPermissionRefresh();
  }

  void _signOut() => setState(() {
    _permissionRefreshTimer?.cancel();
    _session = null;
    _permissions = null;
    _openModuleId = null;
    _openModuleAction = null;
  });

  void _startPermissionRefresh() {
    _permissionRefreshTimer?.cancel();
    if (_useMockData) return;
    unawaited(_refreshPermissions());
    _permissionRefreshTimer = Timer.periodic(
      _permissionRefreshInterval,
      (_) => unawaited(_refreshPermissions()),
    );
  }

  Future<void> _refreshPermissions() async {
    var session = _session;
    if (session == null || _useMockData || _permissionRefreshInProgress) return;
    _permissionRefreshInProgress = true;
    try {
      if (_shouldRefreshSession(session)) {
        session = await _renewSession(session);
      }

      EffectivePermissions permissions;
      try {
        permissions = await _permissionsRepository.loadFor(session);
      } on PermissionsException catch (error) {
        if (!error.sessionExpired) rethrow;
        session = await _renewSession(session);
        permissions = await _permissionsRepository.loadFor(session);
      }

      if (!mounted || !identical(_session, session)) return;
      _applyPermissions(permissions);
    } on AuthenticationException {
      if (!mounted) return;
      _expireSession();
    } on PermissionsException catch (error) {
      if (!mounted) return;
      if (error.sessionExpired) {
        _expireSession();
        return;
      }

      // Access is fail-closed: a stale grant must not survive a failed refresh.
      setState(() {
        _permissions = const EffectivePermissions.empty();
        _openModuleId = null;
        _openModuleAction = null;
      });
    } catch (_) {
      // Access is fail-closed: a stale grant must not survive a failed refresh.
      if (!mounted) return;
      setState(() {
        _permissions = const EffectivePermissions.empty();
        _openModuleId = null;
        _openModuleAction = null;
      });
    } finally {
      _permissionRefreshInProgress = false;
    }
  }

  bool _shouldRefreshSession(UserSession session) {
    final expiresAt = session.accessTokenExpiresAt;
    if (expiresAt == null) return false;
    return expiresAt.isBefore(DateTime.now().add(const Duration(seconds: 30)));
  }

  Future<UserSession> _renewSession(UserSession session) async {
    final refreshed = await _authRepository.refresh(session);
    if (!mounted || !identical(_session, session)) {
      throw const AuthenticationException('The session is no longer active.');
    }
    setState(() => _session = refreshed);
    return refreshed;
  }

  void _expireSession() {
    _permissionRefreshTimer?.cancel();
    setState(() {
      _session = null;
      _permissions = null;
      _openModuleId = null;
      _openModuleAction = null;
    });
  }

  void _applyPermissions(EffectivePermissions permissions) {
    setState(() {
      _permissions = permissions;
      final openModuleId = _openModuleId;
      if (openModuleId != null && !permissions.canSeeModule(openModuleId)) {
        _openModuleId = null;
        _openModuleAction = null;
      } else if (openModuleId != null &&
          _openModuleAction != null &&
          !_canOpenModuleAction(
            permissions,
            openModuleId,
            _openModuleAction!,
          )) {
        _openModuleAction = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final brand = _permissions?.tenantBrand;
    return MaterialApp(
      title: 'SuperCampus',
      debugShowCheckedModeBanner: false,
      theme: _applyTenantBrand(AppTheme.light, brand, Brightness.light),
      darkTheme: _applyTenantBrand(AppTheme.dark, brand, Brightness.dark),
      themeMode: _themeMode,
      home: _buildHome(),
    );
  }

  ThemeData _applyTenantBrand(
    ThemeData theme,
    Map<String, dynamic>? brand,
    Brightness brightness,
  ) {
    final primary = _parseBrandColor(brand?['primary']) ?? AppColors.primary;
    final secondary = _parseBrandColor(brand?['secondary']) ?? AppColors.accent;
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brightness,
      primary: primary,
      secondary: secondary,
    );
    return theme.copyWith(
      colorScheme: scheme,
      primaryColor: primary,
      cardColor: brightness == Brightness.dark
          ? theme.cardColor
          : (_parseBrandColor(brand?['surface']) ?? theme.cardColor),
      dividerColor: primary.withValues(
        alpha: brightness == Brightness.dark ? 0.28 : 0.22,
      ),
      scaffoldBackgroundColor: brightness == Brightness.dark
          ? Color.alphaBlend(
              primary.withValues(alpha: 0.04),
              theme.scaffoldBackgroundColor,
            )
          : (_parseBrandColor(brand?['surface']) ??
                theme.scaffoldBackgroundColor),
      appBarTheme: theme.appBarTheme.copyWith(
        backgroundColor: primary,
        foregroundColor: scheme.onPrimary,
      ),
    );
  }

  Color? _parseBrandColor(Object? value) {
    if (value is! String) return null;
    final hex = value.replaceFirst('#', '');
    if (hex.length != 6) return null;
    final parsed = int.tryParse('FF$hex', radix: 16);
    return parsed == null ? null : Color(parsed);
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

    if (session.role == UserRole.admin) {
      return AdminPortalShell(session: session, onSignOut: _signOut);
    }

    final openModuleId = _openModuleId;
    if (openModuleId == null) {
      return ModuleDashboardScreen(
        session: session,
        permissions: permissions,
        onOpenModule: (id) {
          if (!permissions.canSeeModule(id)) return;
          setState(() => _openModuleId = id);
        },
        onQuickAction: (moduleId, actionId, featureId, requiredAction) {
          if (!permissions.can(moduleId, featureId, requiredAction)) return;
          setState(() {
            _openModuleId = moduleId;
            _openModuleAction = actionId;
          });
        },
        onSignOut: _signOut,
        onThemeModeChanged: (mode) => setState(() => _themeMode = mode),
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

  bool _canOpenModuleAction(
    EffectivePermissions permissions,
    String moduleId,
    String actionId,
  ) {
    final grant = switch ((moduleId, actionId)) {
      (ModuleCatalog.examination, 'schedule') => (
        'publishing',
        ModuleActions.read,
      ),
      (ModuleCatalog.examination, 'marks') => ('marks', ModuleActions.read),
      (ModuleCatalog.examination, 'results') => ('grades', ModuleActions.read),
      (ModuleCatalog.timetable, 'schedule') => ('schedule', ModuleActions.read),
      (ModuleCatalog.timetable, 'substitution') => (
        'substitution',
        ModuleActions.read,
      ),
      (ModuleCatalog.academics, 'attendance') => (
        'attendance',
        ModuleActions.read,
      ),
      (ModuleCatalog.academics, 'marks') => ('marks', ModuleActions.read),
      (ModuleCatalog.academics, 'analysis') => ('analysis', ModuleActions.read),
      (ModuleCatalog.attendance, 'roster') => ('roster', ModuleActions.read),
      (ModuleCatalog.attendance, 'leave') => ('leave', ModuleActions.read),
      (ModuleCatalog.canteen, 'menu') => ('menu', ModuleActions.read),
      (ModuleCatalog.canteen, 'orders') => ('order', ModuleActions.read),
      (ModuleCatalog.canteen, 'wallet') => ('wallet', ModuleActions.read),
      (ModuleCatalog.gatepass, 'outpass') => ('outpass', ModuleActions.read),
      (ModuleCatalog.gatepass, 'visitors') => ('visitor', ModuleActions.read),
      (ModuleCatalog.gatepass, 'access') => ('access', ModuleActions.read),
      _ => null,
    };

    return grant == null || permissions.can(moduleId, grant.$1, grant.$2);
  }

  Widget _buildModule(String moduleId, UserSession session) {
    void exit() => setState(() {
      _openModuleId = null;
      _openModuleAction = null;
    });

    final module = switch (moduleId) {
      ModuleCatalog.examination => ExaminationShell(
        session: session,
        onExitModule: exit,
        onSignOut: _signOut,
        initialAction: _openModuleAction,
      ),
      ModuleCatalog.canteen => CanteenShell(
        session: session,
        onExitModule: exit,
        onSignOut: _signOut,
        initialAction: _openModuleAction,
      ),
      ModuleCatalog.gatepass =>
        session.role == UserRole.parent
            ? ParentPortalScreen(
                session: session,
                onExitModule: exit,
                onSignOut: _signOut,
              )
            : GatepassShell(
                session: session,
                onExitModule: exit,
                initialAction: _openModuleAction,
              ),
      ModuleCatalog.library => LibraryShell(
        session: session,
        onExitModule: exit,
      ),
      ModuleCatalog.academics =>
        session.role == UserRole.student || session.role == UserRole.parent
            ? StudentAcademicsShell(
                session: session,
                onExitModule: exit,
                initialAction: _openModuleAction,
              )
            : AcademicManagementShell(session: session, onExitModule: exit),
      ModuleCatalog.vendorManagement => VendorManagementShell(
        session: session,
        onExitModule: exit,
      ),
      ModuleCatalog.timetable => TimetableShell(
        session: session,
        onExitModule: exit,
        onSignOut: _signOut,
      ),
      'feedback' => FeedbackShell(session: session, onExitModule: exit),
      ModuleCatalog.attendance =>
        session.role == UserRole.student || session.role == UserRole.parent
            ? StudentAcademicsShell(
                session: session,
                onExitModule: exit,
                initialAction: 'attendance',
              )
            : FacultyPortalScreen(
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

    return ModuleNavigationHost(
      session: session,
      permissions: _permissions!,
      onExitModule: exit,
      onOpenModule: (id) {
        if (!_permissions!.canSeeModule(id)) return;
        setState(() {
          _openModuleId = id;
          _openModuleAction = null;
        });
      },
      onSignOut: _signOut,
      onThemeModeChanged: (mode) => setState(() => _themeMode = mode),
      onScan:
          _permissions!.canSeeModule(ModuleCatalog.canteen) ||
              _permissions!.canSeeModule(ModuleCatalog.gatepass)
          ? _openScanner
          : null,
      selectedId: moduleId == ModuleCatalog.academics
          ? ModuleCatalog.academics
          : null,
      child: module,
    );
  }
}
