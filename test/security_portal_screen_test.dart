import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/features/authentication/data/auth_repository.dart';
import 'package:supercampus_mobile/src/features/security/data/security_gate_repository.dart';
import 'package:supercampus_mobile/src/features/security/presentation/security_portal_screen.dart';

void main() {
  testWidgets('gate security portal is scanner-first', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SecurityPortalScreen(
          session: const UserSession(
            email: 'security@mec.local',
            displayName: 'MEC Gate Security',
            role: UserRole.security,
            departmentOrWard: 'Main Gate',
          ),
          repository: _FakeSecurityGateRepository(),
          onSignOut: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Gate security'), findsOneWidget);
    expect(find.text('Scan gatepass QR'), findsOneWidget);
    expect(find.text('Gate in'), findsWidgets);
    expect(find.text('Gate out'), findsWidgets);
    expect(find.text('Access approvals'), findsNothing);
    expect(find.text('Emergency response'), findsNothing);
  });

  testWidgets('manual gatepass code posts a movement', (tester) async {
    final repository = _FakeSecurityGateRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: SecurityPortalScreen(
          session: const UserSession(
            email: 'security@mec.local',
            displayName: 'MEC Gate Security',
            role: UserRole.security,
          ),
          repository: repository,
          onSignOut: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView).first, const Offset(0, -420));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'valid-qr-token');
    await tester.tap(find.byTooltip('Verify code'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(repository.lastPayload, 'valid-qr-token');
    expect(find.text('Gate-in recorded'), findsOneWidget);
    expect(find.textContaining('Valid pass'), findsOneWidget);
  });
}

class _FakeSecurityGateRepository implements SecurityGateRepository {
  String? lastPayload;

  @override
  Future<List<SecurityGateMovement>> recentMovements() async => const [];

  @override
  Future<SecurityGateMovement> scan({
    required String qrPayload,
    required GateDirection direction,
    required String checkpoint,
  }) async {
    lastPayload = qrPayload;
    return SecurityGateMovement(
      id: 'movement-1',
      userId: 'student-1',
      direction: direction,
      checkpoint: checkpoint,
      createdAt: DateTime(2026, 8, 28, 9, 30),
    );
  }
}
