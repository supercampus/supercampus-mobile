import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/features/authentication/data/auth_repository.dart';
import 'package:supercampus_mobile/src/features/security/data/security_gate_repository.dart';
import 'package:supercampus_mobile/src/features/security/presentation/gate_movement_detail_screen.dart';
import 'package:supercampus_mobile/src/features/security/presentation/security_portal_screen.dart';
import 'package:supercampus_mobile/src/features/security/presentation/walk_in_visitor_screen.dart';

const _session = UserSession(
  email: 'security@mec.local',
  displayName: 'MEC Gate Security',
  role: UserRole.security,
  departmentOrWard: 'Main Gate',
);

Widget _portal(SecurityGateRepository repository) => MaterialApp(
  home: SecurityPortalScreen(
    session: _session,
    repository: repository,
    onSignOut: () {},
    scanner: (_) async => 'scanned-qr-token',
  ),
);

final _movement = SecurityGateMovement(
  id: 'movement-1',
  userId: 'student-1',
  requestId: 'request-1',
  holderName: 'Asha Raman',
  passType: 'outpass',
  rollNumber: '21CS001',
  scannedByName: 'Arun Sundaram',
  direction: GateDirection.exit,
  checkpoint: 'Main gate',
  createdAt: DateTime(2026, 9, 28, 9, 30),
);

void main() {
  testWidgets('the gate desk has only Home and History in its navigation', (
    tester,
  ) async {
    await tester.pumpWidget(_portal(_FakeSecurityGateRepository()));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationDestination), findsNWidgets(2));
    expect(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Home'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('History'),
      ),
      findsOneWidget,
    );
    expect(find.text('Modules'), findsNothing);
    expect(find.text('Scanner'), findsNothing);

    // Home carries the scan, the manual code, direction and checkpoint.
    expect(find.text('Gate security'), findsOneWidget);
    expect(find.byKey(const ValueKey('security-scan-gatepass')), findsOneWidget);
    expect(find.byKey(const ValueKey('security-manual-code')), findsOneWidget);
    expect(find.text('Gate in'), findsWidgets);
    expect(find.text('Gate out'), findsWidgets);
    expect(find.byKey(const ValueKey('security-checkpoint')), findsOneWidget);
  });

  testWidgets('today counters come from the server activity', (tester) async {
    final repository = _FakeSecurityGateRepository()
      ..activityResult = GateActivity(
        movements: [_movement],
        entriesToday: 7,
        exitsToday: 3,
      );
    await tester.pumpWidget(_portal(repository));
    await tester.pumpAndSettle();

    expect(find.text('7'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('manual gatepass code posts a movement', (tester) async {
    final repository = _FakeSecurityGateRepository();
    await tester.pumpWidget(_portal(repository));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('security-manual-code')),
      '123456',
    );
    await tester.tap(find.byTooltip('Verify code'));
    await tester.pumpAndSettle();

    expect(repository.lastPayload, '123456');
    expect(repository.lastDirection, GateDirection.entry);
    expect(find.byKey(const ValueKey('gate-result-accepted')), findsOneWidget);
    expect(find.text('Gate-in recorded'), findsOneWidget);
  });

  testWidgets('a replayed pass shows the already-scanned state', (
    tester,
  ) async {
    final repository = _FakeSecurityGateRepository()
      ..scanError = GateAlreadyScannedException(
        'Already scanned at 9:30 AM, 28 Sep by Main gate',
        previous: _movement,
      );
    await tester.pumpWidget(_portal(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('security-scan-gatepass')));
    await tester.pumpAndSettle();

    expect(repository.lastPayload, 'scanned-qr-token');
    expect(
      find.byKey(const ValueKey('gate-result-alreadyScanned')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('gate-result-rejected')), findsNothing);
    expect(find.text('Already scanned'), findsOneWidget);
    expect(
      find.text('Already scanned at 9:30 AM, 28 Sep by Main gate'),
      findsOneWidget,
    );
    expect(find.text('Asha Raman'), findsWidgets);
    expect(find.text('Arun Sundaram'), findsOneWidget);
  });

  testWidgets('an invalid pass shows the rejected state', (tester) async {
    final repository = _FakeSecurityGateRepository()
      ..scanError = const SecurityGateException(
        'This QR or code is not a valid pass',
      );
    await tester.pumpWidget(_portal(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('security-scan-gatepass')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('gate-result-rejected')), findsOneWidget);
    expect(find.text('This QR or code is not a valid pass'), findsOneWidget);
  });

  testWidgets('tapping a history card opens the movement detail', (
    tester,
  ) async {
    final repository = _FakeSecurityGateRepository()
      ..activityResult = GateActivity(movements: [_movement]);
    await tester.pumpWidget(_portal(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('security-nav-history')));
    await tester.pumpAndSettle();
    expect(find.text('Every gate movement, newest first.'), findsOneWidget);

    final card = find.descendant(
      of: find.byKey(const ValueKey('security-history')),
      matching: find.byKey(const ValueKey('gate-movement-movement-1')),
    );
    expect(card, findsOneWidget);
    await tester.tap(card);
    await tester.pumpAndSettle();

    expect(find.byType(GateMovementDetailScreen), findsOneWidget);
    expect(repository.detailRequests, ['movement-1']);
    expect(find.text('Tambaram market'), findsOneWidget);
    expect(find.text('Warden Boys'), findsOneWidget);
    expect(find.text('Scanned by'), findsOneWidget);
  });

  testWidgets('walk-in form validates before registering', (tester) async {
    final repository = _FakeSecurityGateRepository();
    await tester.pumpWidget(_portal(repository));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('security-walk-in')),
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('security-home')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('security-walk-in')));
    await tester.pumpAndSettle();
    expect(find.byType(WalkInVisitorScreen), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('walk-in-submit')));
    await tester.pumpAndSettle();
    expect(repository.walkIns, isEmpty);
    expect(find.text('Enter the visitor’s full name'), findsOneWidget);
    expect(find.text('Enter a 10 to 15 digit phone number'), findsOneWidget);
    expect(find.text('Enter the purpose of the visit'), findsOneWidget);
    expect(find.text('Enter whom the visitor is meeting'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('walk-in-name')),
      'Ravi Kumar',
    );
    await tester.enterText(
      find.byKey(const ValueKey('walk-in-phone')),
      '98765 43210',
    );
    await tester.enterText(
      find.byKey(const ValueKey('walk-in-purpose')),
      'Admission enquiry',
    );
    await tester.enterText(
      find.byKey(const ValueKey('walk-in-host')),
      'Admissions office',
    );
    await tester.enterText(
      find.byKey(const ValueKey('walk-in-vehicle')),
      'TN 09 AB 1234',
    );
    await tester.tap(find.byKey(const ValueKey('walk-in-submit')));
    await tester.pumpAndSettle();

    expect(repository.walkIns, hasLength(1));
    expect(repository.walkIns.single.name, 'Ravi Kumar');
    expect(repository.walkIns.single.checkpoint, 'Main gate');
    expect(find.byType(WalkInVisitorScreen), findsNothing);
    expect(find.text('Visitor gated in'), findsOneWidget);
  });

  test('walk-in validation mirrors the server rules', () {
    expect(WalkInValidation.name('R'), isNotNull);
    expect(WalkInValidation.name('Ravi'), isNull);
    expect(WalkInValidation.phone('12345'), isNotNull);
    expect(WalkInValidation.phone('98765abc43'), isNotNull);
    expect(WalkInValidation.phone('+91 98765-43210'), isNull);
    expect(WalkInValidation.vehicle(''), isNull);
    expect(WalkInValidation.vehicle('TN-09;DROP'), isNotNull);
    expect(WalkInValidation.host(' '), isNotNull);
  });

  test('a 409 already_scanned response carries the earlier movement', () {
    final error = gateErrorFromResponse(409, {
      'error': 'Already scanned at 9:30 AM, 28 Sep by Main gate',
      'code': 'already_scanned',
      'details': {
        'id': 'movement-1',
        'direction': 'entry',
        'checkpoint': 'Main gate',
        'holderName': 'Asha Raman',
        'scannedByName': 'Arun Sundaram',
        'createdAt': '2026-09-28T04:00:00Z',
      },
    });
    expect(error, isA<GateAlreadyScannedException>());
    final previous = (error as GateAlreadyScannedException).previous!;
    expect(previous.holderName, 'Asha Raman');
    expect(previous.direction, GateDirection.entry);

    final conflict = gateErrorFromResponse(409, {
      'error': 'This visitor has not gated in yet',
      'code': 'conflict',
    });
    expect(conflict, isNot(isA<GateAlreadyScannedException>()));
    expect(conflict.message, 'This visitor has not gated in yet');
  });
}

class _FakeSecurityGateRepository implements SecurityGateRepository {
  String? lastPayload;
  GateDirection? lastDirection;
  SecurityGateException? scanError;
  GateActivity activityResult = const GateActivity();
  final detailRequests = <String>[];
  final walkIns = <WalkInVisitorDraft>[];

  @override
  Future<GateActivity> activity({DateTime? before}) async => activityResult;

  @override
  Future<SecurityGateMovement> scan({
    required String qrPayload,
    required GateDirection direction,
    required String checkpoint,
  }) async {
    lastPayload = qrPayload;
    lastDirection = direction;
    if (scanError != null) throw scanError!;
    return SecurityGateMovement(
      id: 'movement-2',
      userId: 'student-1',
      holderName: 'Asha Raman',
      passType: 'daily_access',
      direction: direction,
      checkpoint: checkpoint,
      createdAt: DateTime(2026, 9, 28, 9, 30),
    );
  }

  @override
  Future<GateMovementDetail> movementDetail(String movementId) async {
    detailRequests.add(movementId);
    return GateMovementDetail(
      movement: _movement,
      person: const GateMovementPerson(
        name: 'Asha Raman',
        rollNumber: '21CS001',
        department: 'Computer Science',
      ),
      pass: GateMovementPass(
        type: 'outpass',
        state: 'approved',
        destination: 'Tambaram market',
        reason: 'Buy lab supplies',
        validFrom: DateTime(2026, 9, 28, 9),
        validUntil: DateTime(2026, 9, 28, 17),
        approvedBy: 'Warden Boys',
      ),
      timeline: [_movement],
    );
  }

  @override
  Future<SecurityGateMovement> registerWalkIn(WalkInVisitorDraft draft) async {
    walkIns.add(draft);
    return SecurityGateMovement(
      id: 'movement-3',
      userId: 'visitor-1',
      visitorPassId: 'visitor-1',
      holderName: draft.name,
      passType: 'walk_in',
      direction: GateDirection.entry,
      checkpoint: draft.checkpoint,
      createdAt: DateTime(2026, 9, 28, 10),
    );
  }

  @override
  Future<SecurityGateMovement> visitorGateOut({
    required String visitorPassId,
    required String checkpoint,
  }) async => throw UnimplementedError();
}
