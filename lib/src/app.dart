import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/access/backend_permissions_repository.dart';
import 'core/access/academic_presentation.dart';
import 'core/access/effective_permissions.dart';
import 'core/access/mock_permissions_repository.dart';
import 'core/access/module_catalog.dart';
import 'core/access/permissions_repository.dart';
import 'core/motion/app_motion.dart';
import 'core/media/media_repository.dart';
import 'core/media/media_scope.dart';
import 'core/realtime/realtime_client.dart';
import 'core/realtime/realtime_event.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/module_navigation_buttons.dart';
import 'core/widgets/skeleton_loading.dart';
import 'features/authentication/data/auth_repository.dart';
import 'features/authentication/data/backend_auth_repository.dart';
import 'features/authentication/data/mock_auth_repository.dart';
import 'features/authentication/presentation/login_screen.dart';
import 'features/advisor/data/advisor_students_repository.dart';
import 'features/canteen/presentation/canteen_shell.dart';
import 'features/scanner/presentation/scan_qr_screen.dart';
import 'features/security/data/security_gate_repository.dart';
import 'features/security/presentation/security_portal_screen.dart';
import 'features/canteen/data/backend_canteen_repository.dart';
import 'features/canteen/data/canteen_repository.dart';
import 'features/canteen/data/accountant_wallet_repository.dart';
import 'features/canteen/presentation/accountant_wallet_screen.dart';
import 'features/attendance/data/attendance_repository.dart';
import 'features/attendance/presentation/attendance_shell.dart';
import 'features/examination/presentation/examination_shell.dart';
import 'features/feedback/presentation/feedback_shell.dart';
import 'features/gatepass/presentation/gatepass_shell.dart';
import 'features/gatepass/data/backend_gatepass_repository.dart';
import 'features/gatepass/data/gatepass_repository.dart';
import 'features/library/presentation/library_shell.dart';
import 'features/academics/presentation/academic_management_shell.dart';
import 'features/academics/presentation/student_academics_shell.dart';
import 'features/academics/data/student_assessments_repository.dart';
import 'features/vendor_management/presentation/vendor_management_shell.dart';
import 'features/admin_portal/presentation/admin_portal_shell.dart';
import 'features/modules/data/glance_source.dart';
import 'features/modules/presentation/module_dashboard_screen.dart';
import 'features/modules/presentation/module_navigation_host.dart';
import 'features/modules/presentation/today_glance.dart';
import 'features/parent/presentation/parent_portal_screen.dart';
import 'features/timetable/presentation/timetable_shell.dart';
import 'features/hostel/presentation/hostel_shell.dart';
import 'screens/tuition_fee/tuition_fee_repository.dart';
import 'screens/tuition_fee/tuition_fee_screen.dart';

class SupercampusApp extends StatefulWidget {
  const SupercampusApp({
    super.key,
    this.authRepository,
    this.permissionsRepository,
    this.canteenRepository,
    this.gatepassRepository,
    this.attendanceRepository,
  });

  final AuthRepository? authRepository;
  final PermissionsRepository? permissionsRepository;

  // Module repositories are injectable for the same reason the auth and
  // permissions ones are: a caller that supplies its own is not talking to the
  // backend, so the session it signs in with carries no bearer token. Without
  // these, opening a module would build a backend repository and trip the
  // token assertion in `_accessToken`.
  final CanteenRepository? canteenRepository;
  final GatepassRepository? gatepassRepository;
  final AttendanceRepository? attendanceRepository;

  @override
  State<SupercampusApp> createState() => _SupercampusAppState();
}

class _SupercampusAppState extends State<SupercampusApp>
    with WidgetsBindingObserver {
  static const _backendBaseUrl = String.fromEnvironment(
    'SUPERCAMPUS_API_BASE_URL',
    defaultValue: '',
  );
  static const _allowLocalApiOverride = bool.fromEnvironment(
    'SUPERCAMPUS_ALLOW_LOCAL_API',
  );
  static const _useMockData = bool.fromEnvironment('SUPERCAMPUS_USE_MOCK_DATA');
  static const _permissionRefreshInterval = Duration(seconds: 30);
  static const _themePreferencePrefix = 'supercampus.theme.';

  late final AuthRepository _authRepository;
  late final PermissionsRepository _permissionsRepository;

  UserSession? _session;
  EffectivePermissions? _permissions;
  String? _openModuleId;
  String? _openModuleAction;
  TodayClass? _attendanceClass;
  ThemeMode _themeMode = ThemeMode.light;
  Timer? _permissionRefreshTimer;
  bool _permissionRefreshInProgress = false;
  Future<UserSession>? _sessionRenewal;
  MediaRepository? _mediaRepository;
  RealtimeClient? _realtimeClient;
  StreamSubscription<RealtimeEvent>? _realtimeEventSubscription;
  Timer? _realtimeRefreshDebounce;
  int _surfaceRevision = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final backendBaseUrl = _resolvedBackendBaseUrl;
    if (!_useMockData &&
        (widget.authRepository == null ||
            widget.permissionsRepository == null)) {
      _validateBackendBaseUrl(backendBaseUrl);
    }
    _authRepository =
        widget.authRepository ??
        (_useMockData
            ? MockAuthRepository()
            : BackendAuthRepository(baseUrl: backendBaseUrl));
    _permissionsRepository =
        widget.permissionsRepository ??
        (_useMockData
            ? const MockPermissionsRepository()
            : BackendPermissionsRepository(baseUrl: backendBaseUrl));
    if (!_useMockData && widget.authRepository == null) {
      // Only against a real backend: with mocks there is nothing to upload to,
      // and the screens hide their upload control when no scope is installed.
      _mediaRepository = MediaRepository(
        baseUrl: backendBaseUrl,
        accessTokenProvider: _provideAccessToken,
      );
      _realtimeClient = RealtimeClient(
        baseUrl: backendBaseUrl,
        accessTokenProvider: _provideAccessToken,
      );
      _realtimeEventSubscription = _realtimeClient!.events.listen(
        _onRealtimeEvent,
      );
    }
  }

  static String get _resolvedBackendBaseUrl {
    final configured = _backendBaseUrl.trim();
    if (configured.isNotEmpty) {
      final uri = Uri.tryParse(configured);
      if (_allowLocalApiOverride ||
          uri == null ||
          uri.scheme == 'https' ||
          !_isDevelopmentMode) {
        return configured;
      }
    }
    if (_isDevelopmentMode) return 'https://api.supercampus.ai';
    return configured;
  }

  static bool get _isDevelopmentMode => kDebugMode || kProfileMode;

  static void _validateBackendBaseUrl(String value) {
    if (value.trim().isEmpty) {
      throw StateError(
        'SUPERCAMPUS_API_BASE_URL is required. Pass it with --dart-define.',
      );
    }
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw StateError('SUPERCAMPUS_API_BASE_URL must be an absolute URL.');
    }
    if (kReleaseMode && uri.scheme != 'https') {
      throw StateError('Release builds require an HTTPS API URL.');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _permissionRefreshTimer?.cancel();
    _realtimeRefreshDebounce?.cancel();
    unawaited(_realtimeEventSubscription?.cancel());
    unawaited(_realtimeClient?.dispose());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshPermissions());
      unawaited(_realtimeClient?.resume());
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      unawaited(_realtimeClient?.pause());
    }
  }

  Future<void> _onSignedIn(UserSession session) async {
    setState(() {
      _session = session;
      _permissions = null;
      _openModuleId = null;
      _openModuleAction = null;
      _attendanceClass = null;
      _themeMode = ThemeMode.light;
    });

    final results = await Future.wait<Object?>([
      _permissionsRepository.loadFor(session),
      _loadThemeMode(session),
    ]);
    if (!mounted) return;
    setState(() {
      _permissions = results[0] as EffectivePermissions;
      _themeMode = results[1] as ThemeMode;
    });
    _startPermissionRefresh();
    unawaited(_realtimeClient?.start());
  }

  void _signOut() {
    _permissionRefreshTimer?.cancel();
    _realtimeRefreshDebounce?.cancel();
    unawaited(_realtimeClient?.stop());
    setState(() {
      _sessionRenewal = null;
      _session = null;
      _permissions = null;
      _openModuleId = null;
      _openModuleAction = null;
      _attendanceClass = null;
      _themeMode = ThemeMode.light;
    });
  }

  void _onRealtimeEvent(RealtimeEvent event) {
    if (!mounted || _session == null) return;

    if (event.type == 'realtime.ready') {
      _scheduleRealtimeRefresh();
      return;
    }
    if (event.type == 'attendance.record.published') {
      // This event is delivered only to students in the published roster.
      // Remounting makes both the home strip and an open Academics page read
      // the finalized roll immediately.
      setState(() => _surfaceRevision++);
      return;
    }
    if (!_eventMayChangeAccess(event.type)) return;

    // Operational events (including daily_access.activated) must not remount
    // the open module. Gatepass activation itself emits that event, so doing so
    // creates a feedback loop: remount -> activate -> event -> remount.
    setState(() => _surfaceRevision++);
    _scheduleRealtimeRefresh();
  }

  void _scheduleRealtimeRefresh() {
    _realtimeRefreshDebounce?.cancel();
    _realtimeRefreshDebounce = Timer(const Duration(milliseconds: 250), () {
      unawaited(_refreshPermissions());
    });
  }

  bool _eventMayChangeAccess(String type) {
    return type == 'realtime.resync_required' ||
        type.startsWith('authorization.') ||
        type.startsWith('configuration.') ||
        type.startsWith('identity.');
  }

  Future<ThemeMode> _loadThemeMode(UserSession session) async {
    try {
      final preferences = SharedPreferencesAsync();
      final stored = await preferences.getString(_themePreferenceKey(session));
      return ThemeMode.values.firstWhere(
        (mode) => mode.name == stored,
        orElse: () => ThemeMode.light,
      );
    } catch (_) {
      return ThemeMode.light;
    }
  }

  void _changeThemeMode(ThemeMode mode) {
    setState(() => _themeMode = mode);
    final session = _session;
    if (session == null) return;
    unawaited(_saveThemeMode(session, mode));
  }

  Future<void> _saveThemeMode(UserSession session, ThemeMode mode) async {
    try {
      final preferences = SharedPreferencesAsync();
      await preferences.setString(_themePreferenceKey(session), mode.name);
    } catch (_) {
      // The active choice still applies even when local persistence is blocked.
    }
  }

  String _themePreferenceKey(UserSession session) =>
      '$_themePreferencePrefix${session.email.trim().toLowerCase()}';

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
      session = await _ensureFreshSession();

      EffectivePermissions permissions;
      try {
        permissions = await _permissionsRepository.loadFor(session);
      } on PermissionsException catch (error) {
        if (!error.sessionExpired) rethrow;
        session = await _ensureFreshSession(force: true);
        permissions = await _permissionsRepository.loadFor(session);
      }

      if (!mounted || !identical(_session, session)) return;
      _applyPermissions(permissions);
    } on AuthenticationException catch (error) {
      if (!mounted) return;
      if (error.sessionExpired) _expireSession();
    } on PermissionsException catch (error) {
      if (!mounted) return;
      if (error.sessionExpired) {
        _expireSession();
        return;
      }

      // Keep the last verified snapshot during transient API failures. A
      // successful response remains authoritative and immediately replaces it.
    } catch (_) {
      // A temporary connection failure must not make assigned modules vanish.
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
      throw const AuthenticationException(
        'The session is no longer active.',
        sessionExpired: true,
      );
    }
    setState(() => _session = refreshed);
    return refreshed;
  }

  Future<UserSession> _ensureFreshSession({bool force = false}) {
    final session = _session;
    if (session == null) {
      throw const AuthenticationException(
        'The session is no longer active.',
        sessionExpired: true,
      );
    }
    if (!force && !_shouldRefreshSession(session)) {
      return Future.value(session);
    }

    final activeRenewal = _sessionRenewal;
    if (activeRenewal != null) return activeRenewal;

    final renewal = _renewSession(session);
    _sessionRenewal = renewal;
    return renewal.whenComplete(() {
      if (identical(_sessionRenewal, renewal)) _sessionRenewal = null;
    });
  }

  Future<String> _provideAccessToken({bool forceRefresh = false}) async {
    try {
      return _accessToken(await _ensureFreshSession(force: forceRefresh));
    } on AuthenticationException catch (error) {
      if (error.sessionExpired && mounted) _expireSession();
      rethrow;
    }
  }

  void _expireSession() {
    _permissionRefreshTimer?.cancel();
    _realtimeRefreshDebounce?.cancel();
    unawaited(_realtimeClient?.stop());
    _sessionRenewal = null;
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

  /// Above [MaterialApp], not inside it: a modal route is a sibling of `home`
  /// rather than a descendant, so a scope installed below the navigator would
  /// be out of reach of every sheet that uploads a photo.
  Widget _withMedia(Widget child) {
    final repository = _mediaRepository;
    if (repository == null) return child;
    return MediaScope(repository: repository, child: child);
  }

  @override
  Widget build(BuildContext context) {
    final brand = _permissions?.tenantBrand;
    return _withMedia(
      MaterialApp(
        title: 'SuperCampus',
        debugShowCheckedModeBanner: false,
        theme: _applyTenantBrand(AppTheme.light, brand, Brightness.light),
        darkTheme: _applyTenantBrand(AppTheme.dark, brand, Brightness.dark),
        themeMode: _themeMode,
        home: Builder(
          builder: (context) {
            final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations;
            return AnimatedSwitcher(
              duration: reduceMotion == true
                  ? Duration.zero
                  : AppMotion.standard,
              switchInCurve: AppMotion.curve,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: AppMotion.switchTransition,
              child: KeyedSubtree(
                key: ValueKey<String>(
                  '${_session?.email}|${_openModuleId ?? 'home'}|'
                  '${_permissions == null}|$_surfaceRevision',
                ),
                child: _buildHome(),
              ),
            );
          },
        ),
      ),
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
      pageTransitionsTheme: AppMotion.pageTransitions,
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
      return const Scaffold(body: SkeletonList(rows: 7, rowHeight: 72));
    }

    final roleKeys = <String>{
      ...session.roleIds,
      session.roleKey,
    }.map((role) => role.trim().toLowerCase());
    if (roleKeys.contains('accountant')) {
      return AccountantWalletScreen(
        repository: BackendAccountantWalletRepository(
          baseUrl: _resolvedBackendBaseUrl,
          accessTokenProvider: _provideAccessToken,
        ),
        accountantName: session.displayName,
        onSignOut: _signOut,
      );
    }

    if (session.role == UserRole.security || roleKeys.contains('security')) {
      return SecurityPortalScreen(
        session: session,
        repository: _useMockData
            ? MockSecurityGateRepository()
            : BackendSecurityGateRepository(
                baseUrl: _resolvedBackendBaseUrl,
                accessTokenProvider: _provideAccessToken,
              ),
        onSignOut: _signOut,
      );
    }

    if (session.role == UserRole.admin) {
      return AdminPortalShell(session: session, onSignOut: _signOut);
    }

    if (_isShopOperator(permissions) &&
        permissions.canSeeModule(ModuleCatalog.canteen)) {
      return _buildModule(ModuleCatalog.canteen, session);
    }

    final openModuleId = _openModuleId;
    if (openModuleId == null) {
      return ModuleDashboardScreen(
        session: session,
        permissions: permissions,
        onOpenModule: (id) {
          if (!permissions.canSeeModule(id)) return;
          setState(() {
            _openModuleId = id;
            _attendanceClass = null;
          });
        },
        onOpenAttendanceClass: (selection) {
          if (!permissions.canSeeModule(ModuleCatalog.attendance)) return;
          setState(() {
            _attendanceClass = selection;
            _openModuleId = ModuleCatalog.attendance;
          });
        },
        onQuickAction: (moduleId, actionId, featureId, requiredAction) {
          if (!permissions.can(moduleId, featureId, requiredAction)) return;
          setState(() {
            _openModuleId = moduleId;
            _openModuleAction = actionId;
          });
        },
        onSignOut: _signOut,
        onThemeModeChanged: _changeThemeMode,
        // The scan button only earns its place in the nav bar if there is
        // something on campus to scan.
        onScan:
            permissions.canSeeModule(ModuleCatalog.canteen) ||
                permissions.canSeeModule(ModuleCatalog.gatepass)
            ? _openScanner
            : null,
        glanceSource: _glanceSource(session),
        advisorStudentsSource: _advisorStudentsSource(session),
      );
    }

    return _buildModule(openModuleId, session);
  }

  /// What fills "your day" on the dashboard. Without a backend there is nothing
  /// truthful to put there, so the section stays empty rather than showing
  /// invented figures.
  GlanceSource? _glanceSource(UserSession session) {
    final viewerUserId = session.parseJwtClaims()['sub']?.toString() ?? '';
    if (widget.attendanceRepository != null) {
      return BackendGlanceSource(
        attendance: widget.attendanceRepository!,
        viewerUserId: viewerUserId,
      );
    }
    // Mock mode has no session to authorize with, and an empty base URL has
    // nothing to call. Either way there is no honest day to show.
    if (_useMockData || _resolvedBackendBaseUrl.isEmpty) return null;
    return BackendGlanceSource(
      attendance: AttendanceRepository(
        baseUrl: _resolvedBackendBaseUrl,
        accessTokenProvider: _provideAccessToken,
      ),
      viewerUserId: viewerUserId,
    );
  }

  AdvisorStudentsSource? _advisorStudentsSource(UserSession session) {
    if (!session.roleIds.contains('class_advisor') ||
        _useMockData ||
        _resolvedBackendBaseUrl.isEmpty) {
      return null;
    }
    return BackendAdvisorStudentsRepository(
      baseUrl: _resolvedBackendBaseUrl,
      accessTokenProvider: _provideAccessToken,
    );
  }

  /// Someone who runs a counter rather than buying at one.
  ///
  /// Decided by what they may do, never by what their role is called. This used
  /// to string-match the role name for "shop owner", "vendor" and so on, which
  /// meant a tenant naming the role `owner` silently lost the whole owner
  /// workspace — the account kept its shop assignment and its permissions and
  /// was still shown the student menu.
  ///
  /// Editing a menu or working orders is the thing no customer can do, so it is
  /// the honest test.
  bool _isShopOperator(EffectivePermissions permissions) =>
      permissions.can(ModuleCatalog.canteen, 'menu', ModuleActions.create) ||
      permissions.can(ModuleCatalog.canteen, 'menu', ModuleActions.update) ||
      permissions.can(ModuleCatalog.canteen, 'menu', ModuleActions.delete) ||
      permissions.can(ModuleCatalog.canteen, 'orders', 'manage');

  Future<void> _openScanner(BuildContext context) async {
    // The screen owns its own way in and out — it rides up from the bottom and
    // leaves the same way — so it is pushed rather than wrapped in a page route
    // that would slide the whole thing in from the side.
    final messenger = ScaffoldMessenger.maybeOf(context);
    final code = await openScanQr(context);
    if (code == null || !mounted) return;

    // The code is read but not yet acted on: a canteen order QR and a gate pass
    // go to different endpoints, and neither repository can post one yet. Until
    // that exists, say plainly what was read rather than swallowing it.
    messenger?.showSnackBar(
      SnackBar(
        content: Text('Scanned: $code'),
        behavior: SnackBarBehavior.floating,
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
      (ModuleCatalog.attendance, 'mark') => ('records', ModuleActions.update),
      (ModuleCatalog.attendance, 'reports') => (
        'reports',
        ModuleActions.create,
      ),
      (ModuleCatalog.library, 'book') => ('visit_pass', ModuleActions.create),
      (ModuleCatalog.library, 'qr') => ('qr_pass', ModuleActions.read),
      (ModuleCatalog.library, 'history') => (
        'visit_history',
        ModuleActions.read,
      ),
      (ModuleCatalog.academics, 'programmes') => (
        'programme',
        ModuleActions.read,
      ),
      (ModuleCatalog.academics, 'subjects') => ('subject', ModuleActions.read),
      (ModuleCatalog.academics, 'classes') => (
        'registration',
        ModuleActions.read,
      ),
      (ModuleCatalog.canteen, 'menu') => ('menu', ModuleActions.read),
      (ModuleCatalog.canteen, 'orders') => ('order', ModuleActions.read),
      (ModuleCatalog.canteen, 'wallet') => ('wallet', ModuleActions.read),
      (ModuleCatalog.gatepass, 'outpass') => ('outpass', ModuleActions.read),
      (ModuleCatalog.gatepass, 'visitors') => ('visitor', ModuleActions.read),
      (ModuleCatalog.gatepass, 'access') => ('access', ModuleActions.read),
      (ModuleCatalog.hostel, 'residency') => ('residency', ModuleActions.read),
      (ModuleCatalog.hostel, 'outpass') => ('outpass', ModuleActions.read),
      (ModuleCatalog.hostel, 'mess') => ('mess', ModuleActions.read),
      (ModuleCatalog.hostel, 'complaints') => (
        'complaints',
        ModuleActions.read,
      ),
      (ModuleCatalog.hostel, 'room_change') => (
        'room_change',
        ModuleActions.read,
      ),
      (ModuleCatalog.hostel, 'visitors') => ('visitors', ModuleActions.read),
      (ModuleCatalog.hostel, 'clearance') => ('clearance', ModuleActions.read),
      _ => null,
    };

    return grant == null || permissions.can(moduleId, grant.$1, grant.$2);
  }

  Widget _buildModule(String moduleId, UserSession session) {
    void exit() => setState(() {
      _openModuleId = null;
      _openModuleAction = null;
      _attendanceClass = null;
    });

    final module = switch (moduleId) {
      ModuleCatalog.hostel => HostelShell(
        session: session,
        onExitModule: exit,
        initialAction: _openModuleAction,
      ),
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
        repository:
            widget.canteenRepository ??
            (_useMockData
                ? null
                : BackendCanteenRepository(
                    baseUrl: _resolvedBackendBaseUrl,
                    accessTokenProvider: _provideAccessToken,
                  )),
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
                repository:
                    widget.gatepassRepository ??
                    (_useMockData
                        ? null
                        : BackendGatepassRepository(
                            baseUrl: _resolvedBackendBaseUrl,
                            accessTokenProvider: _provideAccessToken,
                            studentName: session.displayName,
                            email: session.email,
                            rollNumber: session.idNumber ?? '',
                            department: session.departmentOrWard ?? '',
                          )),
              ),
      ModuleCatalog.library => LibraryShell(
        session: session,
        onExitModule: exit,
        initialAction: _openModuleAction,
      ),
      // Which academic workspace someone gets follows what they may do, not
      // what their role is called: `own` scope with no approvals is a learner,
      // anything wider is staff. A tenant can rename or split its roles freely
      // and this keeps working.
      ModuleCatalog.academics =>
        academicPresentationFor(_permissions!) == AcademicPresentation.staff
            ? AcademicManagementShell(
                session: session,
                onExitModule: exit,
                initialAction: _openModuleAction,
              )
            : StudentAcademicsShell(
                session: session,
                onExitModule: exit,
                initialAction: _openModuleAction,
                attendanceRepository: _useMockData
                    ? null
                    : AttendanceRepository(
                        baseUrl: _resolvedBackendBaseUrl,
                        accessTokenProvider: _provideAccessToken,
                      ),
                assessmentsSource: _useMockData
                    ? null
                    : BackendStudentAssessmentsRepository(
                        baseUrl: _resolvedBackendBaseUrl,
                        accessTokenProvider: _provideAccessToken,
                      ),
              ),
      ModuleCatalog.vendorManagement => VendorManagementShell(
        session: session,
        onExitModule: exit,
      ),
      ModuleCatalog.tuitionFee => TuitionFeeScreen(
        session: session,
        repository: TuitionFeeRepository(
          baseUrl: _resolvedBackendBaseUrl,
          accessTokenProvider: _provideAccessToken,
        ),
        onExitModule: exit,
      ),
      ModuleCatalog.timetable => TimetableShell(
        session: session,
        baseUrl: _useMockData ? null : _resolvedBackendBaseUrl,
        accessTokenProvider: _useMockData ? null : _provideAccessToken,
        scope: _permissions!.scopeFor(ModuleCatalog.timetable),
        canConfigure:
            _permissions!.can(
              ModuleCatalog.timetable,
              'config',
              ModuleActions.create,
            ) ||
            _permissions!.can(
              ModuleCatalog.timetable,
              'config',
              ModuleActions.update,
            ) ||
            _permissions!.can(
              ModuleCatalog.timetable,
              'schedule',
              ModuleActions.create,
            ) ||
            _permissions!.can(
              ModuleCatalog.timetable,
              'schedule',
              ModuleActions.update,
            ),
        onExitModule: exit,
        onSignOut: _signOut,
        initialAction: _openModuleAction,
      ),
      'feedback' => FeedbackShell(session: session, onExitModule: exit),
      ModuleCatalog.attendance => AttendanceShell(
        session: session,
        permissions: _permissions!,
        onExitModule: exit,
        repository:
            widget.attendanceRepository ??
            AttendanceRepository(
              baseUrl: _resolvedBackendBaseUrl,
              accessTokenProvider: _provideAccessToken,
            ),
        initialTimetableEntryId: _attendanceClass?.timetableEntryId,
        initialSubjectOfferingId: _attendanceClass?.subjectOfferingId,
        initialSectionId: _attendanceClass?.sectionId,
        initialSubjectName: _attendanceClass?.subject,
        initialPeriodLabel: _attendanceClass?.periodLabel,
        openSelectedClassImmediately: _attendanceClass != null,
        initialAction: _openModuleAction,
      ),
      // A grant on a catalogued-but-unbuilt module can't reach here — the
      // dashboard disables its button — but stay defensive rather than crash.
      _ => Scaffold(
        appBar: AppBar(
          leading: ModuleBackButton(onPressed: exit),
          title: Text(ModuleCatalog.byId(moduleId)?.title ?? 'Module'),
          actions: [ModuleHomeButton(onPressed: exit)],
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
      onThemeModeChanged: _changeThemeMode,
      onScan:
          _permissions!.canSeeModule(ModuleCatalog.canteen) ||
              _permissions!.canSeeModule(ModuleCatalog.gatepass)
          ? _openScanner
          : null,
      selectedId: 'modules',
      child: module,
    );
  }

  String _accessToken(UserSession session) {
    final token = session.jwtToken;
    if (token == null || token.trim().isEmpty) {
      throw StateError('A signed-in backend session token is required.');
    }
    return token;
  }
}
