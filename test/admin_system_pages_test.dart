import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/core/access/effective_permissions.dart';
import 'package:supercampus_mobile/src/core/theme/app_theme.dart';
import 'package:supercampus_mobile/src/features/admin_system/data/admin_system_models.dart';
import 'package:supercampus_mobile/src/features/admin_system/data/admin_system_repository.dart';
import 'package:supercampus_mobile/src/features/admin_system/presentation/admin_system_entries.dart';
import 'package:supercampus_mobile/src/features/admin_system/presentation/app_versions_screen.dart';
import 'package:supercampus_mobile/src/features/admin_system/presentation/audit_logs_screen.dart';
import 'package:supercampus_mobile/src/features/admin_system/presentation/security_logs_screen.dart';

class FakeAdminSystemRepository implements AdminSystemRepository {
  final auditFilters = <AuditFilter>[];
  final sessionQueries = <SecurityLogQuery>[];
  final revoked = <String>[];
  final saved = <AppVersionPolicy>[];

  List<AuditEntry> entries = [
    AuditEntry.fromJson({
      'id': 'txn-1',
      'source': 'wallet',
      'kind': 'deduction',
      'direction': 'debit',
      'amount': -180,
      'createdAt': DateTime.now()
          .subtract(const Duration(minutes: 5))
          .toIso8601String(),
      'targetName': 'Priya Kumar',
      'targetNumber': 'MEC26AI001',
      'actorName': 'Abhinaya',
      'actorUserId': 'acct-1',
      'shopName': 'Canteen',
      'description': 'Broken plate',
      'balanceBefore': 500,
      'balanceAfter': 320,
    }),
    AuditEntry.fromJson({
      'id': 'txn-2',
      'source': 'wallet',
      'kind': 'top_up',
      'direction': 'credit',
      'amount': 1000,
      'createdAt': DateTime.now()
          .subtract(const Duration(hours: 2))
          .toIso8601String(),
      'targetName': 'Vignesh Kumar',
      'description': 'Cash top-up',
      'balanceBefore': 0,
      'balanceAfter': 1000,
    }),
  ];

  List<LoginSession> sessionList = [
    LoginSession.fromJson({
      'id': 'session-student',
      'status': 'active',
      'name': 'Priya Kumar',
      'email': 'student001@mec.local',
      'deviceName': 'Android device',
      'platform': 'android',
      'ipAddress': '103.249.204.94',
      'signedInAt': DateTime.now().toIso8601String(),
    }),
    LoginSession.fromJson({
      'id': 'session-me',
      'status': 'active',
      'name': 'Arun Iyer',
      'deviceName': 'Web browser',
      'current': true,
    }),
    LoginSession.fromJson({
      'id': 'session-old',
      'status': 'revoked',
      'endReason': 'signed_out',
      'name': 'Vignesh Kumar',
      'deviceName': 'iPhone or iPad',
    }),
  ];

  List<AppVersionPolicy> policies = const [
    AppVersionPolicy(
      platform: 'android',
      latestVersion: '1.0.9',
      minimumVersion: '1.0.0',
      storeUrl:
          'https://play.google.com/store/apps/details?id=ai.supercampus.mobile',
    ),
    AppVersionPolicy(
      platform: 'ios',
      latestVersion: '1.0.9',
      minimumVersion: '1.0.0',
    ),
  ];

  @override
  Future<AuditPage> auditLogs(
    AuditFilter filter, {
    int limit = 50,
    int offset = 0,
  }) async {
    auditFilters.add(filter);
    final visible = entries.where((entry) {
      if (filter.direction != null && entry.direction != filter.direction) {
        return false;
      }
      return filter.kinds.isEmpty || filter.kinds.contains(entry.kind);
    }).toList();
    return AuditPage(
      entries: visible,
      total: visible.length,
      credits: 1000,
      debits: 180,
    );
  }

  @override
  Future<SessionsPage> sessions(
    SecurityLogQuery query, {
    int limit = 50,
    int offset = 0,
  }) async {
    sessionQueries.add(query);
    final visible = sessionList
        .where((s) => query.status == null || s.status == query.status)
        .toList();
    return SessionsPage(
      sessions: visible,
      total: visible.length,
      active: 2,
      revoked: 1,
    );
  }

  @override
  Future<LoginEventsPage> loginEvents(
    SecurityLogQuery query, {
    int limit = 50,
    int offset = 0,
  }) async => LoginEventsPage(
    events: [
      LoginEventRecord.fromJson({
        'id': 'event-1',
        'outcome': 'failure',
        'reason': 'invalid_credentials',
        'name': 'Priya Kumar',
        'deviceName': 'Android device',
        'createdAt': DateTime.now().toIso8601String(),
      }),
    ],
    total: 1,
    failures: 1,
  );

  @override
  Future<void> revokeSession(String sessionId) async => revoked.add(sessionId);

  @override
  Future<List<AppVersionPolicy>> appVersions() async => policies;

  @override
  Future<AppVersionPolicy> saveAppVersion(AppVersionPolicy policy) async {
    saved.add(policy);
    return policy;
  }
}

Widget _host(Widget child) => MaterialApp(theme: AppTheme.light, home: child);

void main() {
  group('Audit logs', () {
    testWidgets('lists entries with actor, balance and a detail view', (
      tester,
    ) async {
      final repository = FakeAdminSystemRepository();
      await tester.pumpWidget(_host(AuditLogsScreen(repository: repository)));
      await tester.pumpAndSettle();

      expect(find.text('Audit Logs'), findsOneWidget);
      expect(find.text('Priya Kumar'), findsOneWidget);
      expect(find.text('−₹180'), findsOneWidget);
      expect(find.text('+₹1,000'), findsOneWidget);
      expect(find.textContaining('by Abhinaya'), findsOneWidget);
      expect(find.text('₹500 → ₹320'), findsOneWidget);

      await tester.tap(find.byKey(const Key('audit-entry-txn-1')));
      await tester.pumpAndSettle();
      expect(find.text('Performed by'), findsOneWidget);
      expect(find.text('Broken plate'), findsWidgets);
      expect(find.text('MEC26AI001'), findsOneWidget);
    });

    testWidgets('type chips and search filter the request', (tester) async {
      final repository = FakeAdminSystemRepository();
      await tester.pumpWidget(_host(AuditLogsScreen(repository: repository)));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ChoiceChip, 'Credits'));
      await tester.pumpAndSettle();
      expect(repository.auditFilters.last.direction, AuditDirection.credit);
      expect(find.text('Vignesh Kumar'), findsOneWidget);
      expect(find.text('Priya Kumar'), findsNothing);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Refunds'));
      await tester.pumpAndSettle();
      expect(repository.auditFilters.last.kinds, {AuditKind.refund});
      expect(find.text('No entries'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('audit-search')), 'MEC26');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(repository.auditFilters.last.search, 'MEC26');
    });

    test('filters become query parameters', () {
      final query = AuditFilter(
        kinds: {AuditKind.laundryPayment, AuditKind.refund},
        direction: AuditDirection.debit,
        from: DateTime(2026, 9, 1),
        to: DateTime(2026, 9, 29),
        search: ' priya ',
        actor: 'system',
      ).toQuery(limit: 50, offset: 100);
      expect(query['kind'], 'laundry_payment,refund');
      expect(query['direction'], 'debit');
      expect(query['from'], '2026-09-01');
      expect(query['to'], '2026-09-29');
      expect(query['q'], 'priya');
      expect(query['actor'], 'system');
      expect(query['offset'], '100');
    });
  });

  group('Security logs', () {
    testWidgets('shows sessions and revokes an active one', (tester) async {
      final repository = FakeAdminSystemRepository();
      await tester.pumpWidget(
        _host(SecurityLogsScreen(repository: repository, canRevoke: true)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Security Logs'), findsOneWidget);
      expect(find.text('Priya Kumar'), findsOneWidget);
      expect(find.text('Logged out'), findsOneWidget);
      expect(find.textContaining('Android · 103.249.204.94'), findsOneWidget);

      await tester.tap(find.byKey(const Key('session-session-student')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('revoke-session')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('revoke-session')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm-revoke-session')));
      await tester.pumpAndSettle();

      expect(repository.revoked, ['session-student']);
      expect(find.text('Revoked'), findsOneWidget);
    });

    testWidgets(
      'never offers to revoke your own session or without the grant',
      (tester) async {
        final repository = FakeAdminSystemRepository();
        await tester.pumpWidget(
          _host(SecurityLogsScreen(repository: repository, canRevoke: true)),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('session-session-me')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('revoke-session')), findsNothing);
        await tester.ensureVisible(find.text('This is your current session.'));
        expect(find.text('This is your current session.'), findsOneWidget);

        await tester.pumpWidget(
          MaterialApp(
            key: UniqueKey(),
            theme: AppTheme.light,
            home: SecurityLogsScreen(repository: repository),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('session-session-student')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('revoke-session')), findsNothing);
      },
    );

    testWidgets('status chips and the activity tab', (tester) async {
      final repository = FakeAdminSystemRepository();
      await tester.pumpWidget(
        _host(SecurityLogsScreen(repository: repository)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ChoiceChip, 'Active'));
      await tester.pumpAndSettle();
      expect(repository.sessionQueries.last.status, SessionStatus.active);
      expect(find.text('Vignesh Kumar'), findsNothing);

      await tester.tap(find.text('Sign-in activity'));
      await tester.pumpAndSettle();
      expect(find.text('Sign-in failed'), findsOneWidget);
    });
  });

  group('App versions', () {
    testWidgets('edits and saves a platform policy', (tester) async {
      final repository = FakeAdminSystemRepository();
      await tester.pumpWidget(
        _host(AppVersionsScreen(repository: repository, canUpdate: true)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Android'), findsOneWidget);
      expect(find.text('iOS'), findsOneWidget);
      expect(find.text('Users can skip this update'), findsNWidgets(2));

      await tester.enterText(find.byKey(const Key('latest-android')), '1.1.0');
      await tester.enterText(find.byKey(const Key('minimum-android')), '1.0.9');
      await tester.tap(find.byKey(const Key('force-android')));
      await tester.pumpAndSettle();
      expect(
        find.text('Users must update to the latest version'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('save-android')));
      await tester.pumpAndSettle();

      final saved = repository.saved.single;
      expect(saved.platform, 'android');
      expect(saved.latestVersion, '1.1.0');
      expect(saved.minimumVersion, '1.0.9');
      expect(saved.forceUpdate, isTrue);
    });

    testWidgets(
      'rejects a minimum above latest and a forced update with no store',
      (tester) async {
        final repository = FakeAdminSystemRepository();
        await tester.pumpWidget(
          _host(AppVersionsScreen(repository: repository, canUpdate: true)),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('minimum-android')),
          '2.0.0',
        );
        await tester.tap(find.byKey(const Key('save-android')));
        await tester.pumpAndSettle();
        expect(find.text('Above the latest'), findsOneWidget);

        await tester.drag(find.byType(ListView), const Offset(0, -600));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('force-ios')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('save-ios')));
        await tester.pumpAndSettle();
        expect(
          find.text('Add the store URL to force an update'),
          findsOneWidget,
        );
        expect(repository.saved, isEmpty);
      },
    );

    testWidgets('is read-only without the update grant', (tester) async {
      await tester.pumpWidget(
        _host(AppVersionsScreen(repository: FakeAdminSystemRepository())),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('save-android')), findsNothing);
    });
  });

  group('Admin home entries', () {
    test('are decided by grants, not roles', () {
      List<String> ids(Set<String> grants) => adminSystemEntries(
        EffectivePermissions(grants: grants),
      ).map((entry) => entry.id).toList();

      expect(ids({'*'}), ['audit_logs', 'security_logs', 'app_versions']);
      expect(ids({'administration.audit_logs.read'}), ['audit_logs']);
      expect(ids({'administration.app_versions.update'}), ['app_versions']);
      expect(ids({'canteen.wallet.top_up'}), isEmpty);
    });
  });
}
