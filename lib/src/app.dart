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
import 'core/notifications/push_notification_service.dart';
import 'core/notifications/notification_deep_link.dart';
import 'core/widgets/app_design_viewport.dart';
import 'core/widgets/launch_brand_intro.dart';
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
import 'features/examination/data/marks_batch_repository.dart';
import 'features/feedback/presentation/feedback_shell.dart';
import 'features/gatepass/presentation/gatepass_shell.dart';
import 'features/gatepass/data/backend_gatepass_repository.dart';
import 'features/gatepass/data/approval_portal_repository.dart';
import 'features/gatepass/data/gatepass_repository.dart';
import 'features/gatepass/presentation/approval_portal_screen.dart';
import 'features/library/presentation/library_shell.dart';
import 'features/library/data/librarian_repository.dart';
import 'features/library/presentation/librarian_portal_screen.dart';
import 'features/academics/presentation/academic_management_shell.dart';
import 'features/academics/presentation/student_academics_shell.dart';
import 'features/academics/data/student_assessments_repository.dart';
import 'features/vendor_management/presentation/vendor_management_shell.dart';
import 'features/admin_portal/presentation/admin_portal_shell.dart';
import 'features/admin_portal/data/admin_student_repository.dart';
import 'features/modules/data/glance_source.dart';
import 'features/modules/presentation/module_dashboard_screen.dart';
import 'features/modules/presentation/module_navigation_host.dart';
import 'features/modules/presentation/today_glance.dart';
import 'features/parent/presentation/parent_portal_screen.dart';
import 'features/notifications/data/notification_repository.dart';
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
    this.approvalPortalRepository,
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
  final ApprovalPortalRepository? approvalPortalRepository;

  @override
  State<SupercampusApp> createState() => _SupercampusAppState();
}

class _SupercampusAppState extends State<SupercampusApp>
    with WidgetsBindingObserver {
  static const _backendBaseUrl = String.fromEnvironment(
    'SUPERCAMPUS_API_BASE_URL',
    defaultValue: 'https://api.supercampus.ai',
  );
  static const _allowLocalApiOverride = bool.fromEnvironment(
    'SUPERCAMPUS_ALLOW_LOCAL_API',
  );
  static const _useMockData = bool.fromEnvironment('SUPERCAMPUS_USE_MOCK_DATA');
  static const _themePreferencePrefix = 'supercampus.theme.';

  late final AuthRepository _authRepository;
  late final PermissionsRepository _permissionsRepository;

  UserSession? _session;
  EffectivePermissions? _permissions;
  String? _openModuleId;
  String? _openModuleAction;
  TodayClass? _attendanceClass;
  ThemeMode _themeMode = ThemeMode.light;
  bool _permissionRefreshInProgress = false;
  Future<UserSession>? _sessionRenewal;
  MediaRepository? _mediaRepository;
  RealtimeClient? _realtimeClient;
  StreamSubscription<RealtimeEvent>? _realtimeEventSubscription;
  StreamSubscription<String>? _pushDeepLinkSubscription;
  Timer? _realtimeRefreshDebounce;
  int _surfaceRevision = 0;
  int _glanceRevision = 0;
  int _notificationRevision = 0;

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
    _pushDeepLinkSubscription = PushNotificationService.instance.deepLinks
        .listen(_openPushDeepLink);
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
    _realtimeRefreshDebounce?.cancel();
    unawaited(_realtimeEventSubscription?.cancel());
    unawaited(_pushDeepLinkSubscription?.cancel());
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
    unawaited(_realtimeClient?.start());
    final notificationRepository = _notificationRepository();
    if (notificationRepository != null) {
      unawaited(
        PushNotificationService.instance.activate(notificationRepository),
      );
    }
  }

  void _signOut() {
    unawaited(_completeSignOut());
  }

  Future<void> _completeSignOut() async {
    _realtimeRefreshDebounce?.cancel();
    unawaited(_realtimeClient?.stop());
    await PushNotificationService.instance.deactivate();
    if (!mounted) return;
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

  void _openPushDeepLink(String deepLink) {
    final permissions = _permissions;
    if (_session == null || permissions == null) return;
    final moduleId = notificationModuleId(
      deepLink: deepLink,
      preferAttendanceModule: permissions.canSeeModule(
        ModuleCatalog.attendance,
      ),
    );
    if (moduleId == null || !permissions.canSeeModule(moduleId)) return;
    setState(() {
      _openModuleId = moduleId;
      _openModuleAction = null;
      _attendanceClass = null;
    });
  }

  void _onRealtimeEvent(RealtimeEvent event) {
    if (!mounted || _session == null) return;

    // `realtime.ready` is emitted after every socket reconnect. Authentication
    // already loaded the initial permission snapshot, so treating readiness as
    // a data change made the home dashboard flash on each reconnect.
    if (event.type == 'realtime.ready') return;
    // The operations API publishes completed rolls as
    // `attendance.session.published_to_hod`. Keep the legacy event name for
    // compatibility with older deployments, but refresh on the canonical
    // event so student attendance cards immediately use the latest records.
    if (event.type == 'attendance.session.published_to_hod' ||
        event.type == 'attendance.record.published') {
      setState(() {
        // Keep the dashboard mounted and refresh only its attendance-backed
        // glance. An open module can still remount to reread its own records.
        if (_openModuleId == null) {
          _glanceRevision++;
        } else {
          _surfaceRevision++;
        }
        _notificationRevision++;
      });
      return;
    }
    if (_eventCreatesNotification(event.type)) {
      // A new inbox item must not remount the dashboard or reload "Your day".
      setState(() => _notificationRevision++);
      return;
    }
    if (!_eventMayChangeAccess(event.type)) return;

    // Operational events (including daily_access.activated) must not remount
    // the open module. Gatepass activation itself emits that event, so doing so
    // creates a feedback loop: remount -> activate -> event -> remount.
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

  bool _eventCreatesNotification(String type) =>
      type.startsWith('canteen.order.') ||
      type == 'canteen.wallet.credited' ||
      type == 'gatepass.request.decided' ||
      type == 'attendance.report.submitted_to_principal';

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
    _realtimeRefreshDebounce?.cancel();
    unawaited(_realtimeClient?.stop());
    unawaited(PushNotificationService.instance.deactivate());
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
        builder: (context, child) => AppDesignViewport(
          child: Stack(
            fit: StackFit.expand,
            children: [
              child ?? const SizedBox.shrink(),
              const LaunchBrandIntro(),
            ],
          ),
        ),
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
          // The tenant surface can style cards, but the light-mode page canvas
          // stays the shared near-white lavender blush. A green tenant surface
          // previously washed the entire student app mint.
          : AppColors.canvas,
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
        glanceRevision: _glanceRevision,
        advisorStudentsSource: _advisorStudentsSource(session),
        notificationRepository: _notificationRepository(),
        notificationRevision: _notificationRevision,
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

  NotificationRepository? _notificationRepository() {
    if (_useMockData || _resolvedBackendBaseUrl.isEmpty) return null;
    return NotificationRepository(
      baseUrl: _resolvedBackendBaseUrl,
      accessTokenProvider: _provideAccessToken,
    );
  }

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
      (ModuleCatalog.administration, 'access_control') => (
        'access_control',
        ModuleActions.read,
      ),
      (ModuleCatalog.administration, 'approvals') => (
        'approvals',
        ModuleActions.read,
      ),
      (ModuleCatalog.administration, 'emergency') => (
        'emergency',
        ModuleActions.read,
      ),
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
      (ModuleCatalog.attendance, 'mark') => ('session', ModuleActions.create),
      (ModuleCatalog.attendance, 'history') => ('records', ModuleActions.read),
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
      (ModuleCatalog.library, 'slots') => ('capacity', 'manage'),
      (ModuleCatalog.library, 'scan') => ('visit_pass', ModuleActions.approve),
      (ModuleCatalog.library, 'logs' || 'download') => (
        'logs',
        ModuleActions.read,
      ),
      (ModuleCatalog.library, 'announcement') => (
        'announcement',
        ModuleActions.create,
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
      (ModuleCatalog.canteen, 'order_history') => ('order', ModuleActions.read),
      (ModuleCatalog.canteen, 'wallet') => ('wallet', ModuleActions.read),
      (ModuleCatalog.canteen, 'transactions') => ('wallet', ModuleActions.read),
      (ModuleCatalog.canteen, 'top_up') => ('wallet', ModuleActions.update),
      (ModuleCatalog.gatepass, 'outpass') => ('outpass', ModuleActions.read),
      (ModuleCatalog.gatepass, 'visitors') => ('visitor', ModuleActions.read),
      (ModuleCatalog.gatepass, 'access') => ('access', ModuleActions.read),
      (ModuleCatalog.gatepass, 'scan' || 'manual_code') => (
        'scan',
        ModuleActions.create,
      ),
      (ModuleCatalog.gatepass, 'movement_logs') => ('scan', ModuleActions.read),
      (ModuleCatalog.gatepass, 'leave_pending' || 'leave_history') => (
        'leave',
        ModuleActions.read,
      ),
      (ModuleCatalog.gatepass, 'outpass_pending' || 'outpass_history') => (
        'outpass',
        ModuleActions.read,
      ),
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
      (ModuleCatalog.vendorManagement, 'vendors') => (
        'vendors',
        ModuleActions.read,
      ),
      (ModuleCatalog.vendorManagement, 'contracts') => (
        'contracts',
        ModuleActions.read,
      ),
      (ModuleCatalog.vendorManagement, 'purchase_orders') => (
        'purchase_orders',
        ModuleActions.read,
      ),
      (ModuleCatalog.vendorManagement, 'payments') => (
        'payments',
        ModuleActions.read,
      ),
      (ModuleCatalog.vendorManagement, 'work_orders') => (
        'work_orders',
        ModuleActions.read,
      ),
      (ModuleCatalog.tuitionFee, 'dues') => ('invoice', ModuleActions.read),
      (ModuleCatalog.tuitionFee, 'pay') => ('payment', ModuleActions.create),
      (ModuleCatalog.tuitionFee, 'receipts') => ('payment', ModuleActions.read),
      _ => null,
    };

    return grant == null || permissions.can(moduleId, grant.$1, grant.$2);
  }

  Widget _buildModule(String moduleId, UserSession session) {
    // Permission payloads from older tenants used `fees` while the current
    // catalog uses `tuition_fee`. Canonicalise at the navigation boundary so
    // an existing account or cached dashboard card can never fall through to
    // the generic "not available" page.
    final resolvedModuleId = switch (moduleId.trim().toLowerCase()) {
      'fees' || 'fee' || 'tuition' || 'tuition-fee' => ModuleCatalog.tuitionFee,
      final id => id,
    };
    final roleKeys = <String>{
      ...session.roleIds,
      session.roleKey,
    }.map((role) => role.trim().toLowerCase()).toSet();
    final isAccountant = roleKeys.contains('accountant');
    final isSecurity =
        session.role == UserRole.security || roleKeys.contains('security');
    final isLibrarian = roleKeys.contains('librarian');
    final approvalViewerKind =
        session.role == UserRole.parent || roleKeys.contains('parent')
        ? 'parent'
        : roleKeys.contains('warden')
        ? 'warden'
        : roleKeys.contains('principal')
        ? 'principal'
        : roleKeys.contains('class_advisor') ||
              roleKeys.contains('hod') ||
              roleKeys.contains('head_of_department')
        ? 'advisor_or_hod'
        : null;

    void exit() => setState(() {
      _openModuleId = null;
      _openModuleAction = null;
      _attendanceClass = null;
    });

    final module = switch (resolvedModuleId) {
      ModuleCatalog.administration => AdminPortalShell(
        libraryRepository: LibrarianRepository(
          baseUrl: _resolvedBackendBaseUrl,
          accessTokenProvider: _provideAccessToken,
        ),
        studentRepository: AdminStudentRepository(
          baseUrl: _resolvedBackendBaseUrl,
          accessTokenProvider: _provideAccessToken,
        ),
      ),
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
        marksRepository: _useMockData
            ? null
            : MarksBatchRepository(
                baseUrl: _resolvedBackendBaseUrl,
                accessTokenProvider: _provideAccessToken,
              ),
      ),
      ModuleCatalog.canteen =>
        isAccountant
            ? AccountantWalletScreen(
                repository: BackendAccountantWalletRepository(
                  baseUrl: _resolvedBackendBaseUrl,
                  accessTokenProvider: _provideAccessToken,
                ),
                accountantName: session.displayName,
                onSignOut: _signOut,
              )
            : CanteenShell(
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
        isSecurity
            ? SecurityPortalScreen(
                session: session,
                initialAction: _openModuleAction,
                repository: _useMockData
                    ? MockSecurityGateRepository()
                    : BackendSecurityGateRepository(
                        baseUrl: _resolvedBackendBaseUrl,
                        accessTokenProvider: _provideAccessToken,
                      ),
                onSignOut: _signOut,
              )
            : approvalViewerKind != null
            ? (_useMockData && approvalViewerKind == 'parent'
                  ? ParentPortalScreen(
                      session: session,
                      onExitModule: exit,
                      onSignOut: _signOut,
                    )
                  : ApprovalPortalScreen(
                      session: session,
                      viewerKind: approvalViewerKind,
                      repository:
                          widget.approvalPortalRepository ??
                          BackendApprovalPortalRepository(
                            baseUrl: _resolvedBackendBaseUrl,
                            accessTokenProvider: _provideAccessToken,
                          ),
                      onSignOut: _signOut,
                    ))
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
      ModuleCatalog.library =>
        isLibrarian
            ? LibrarianPortalScreen(
                session: session,
                initialAction: _openModuleAction,
                repository: LibrarianRepository(
                  baseUrl: _resolvedBackendBaseUrl,
                  accessTokenProvider: _provideAccessToken,
                ),
                onSignOut: _signOut,
              )
            : LibraryShell(
                session: session,
                onExitModule: exit,
                initialAction: _openModuleAction,
                baseUrl: _useMockData ? null : _resolvedBackendBaseUrl,
                accessTokenProvider: _useMockData ? null : _provideAccessToken,
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
        canManageFees:
            _permissions!.can('fees', 'records', ModuleActions.create) ||
            _permissions!.can('fees', 'records', ModuleActions.update) ||
            _permissions!.can(
              ModuleCatalog.tuitionFee,
              'invoice',
              ModuleActions.create,
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
          title: Text(ModuleCatalog.byId(resolvedModuleId)?.title ?? 'Module'),
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
