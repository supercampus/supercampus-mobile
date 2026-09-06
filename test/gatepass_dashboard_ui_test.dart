import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supercampus_mobile/src/features/gatepass/data/mock_gatepass_repository.dart';
import 'package:supercampus_mobile/src/features/gatepass/presentation/gatepass_dashboard_screen.dart';

void main() {
  testWidgets('shows stacked pass actions with the gate-in QR', (tester) async {
    final storeFuture = MockGatepassRepository(
      studentName: 'Vishnu S',
      email: 'student@mec.local',
    ).loadStore();
    await tester.pump(const Duration(milliseconds: 500));
    final store = await storeFuture;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GatepassDashboardScreen(
            store: store,
            onApplyLeavePass: () {},
            onApplyOutpass: () {},
            onOpenAccess: () {},
            onOpenRequests: () {},
            onInviteVisitor: () {},
            onExitModule: () {},
          ),
        ),
      ),
    );

    expect(find.text('Apply leave pass'), findsOneWidget);
    expect(find.text('Apply outpass'), findsOneWidget);
    expect(find.text('Finding your location'), findsNothing);
    expect(find.text('VS'), findsNothing);
    expect(find.text('Local outing'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Local outing')).dy,
      greaterThan(tester.getTopLeft(find.text('Recent movement')).dy),
    );
    expect(find.byType(QrImageView), findsOneWidget);

    await tester.tap(find.byType(QrImageView));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Gate-in QR'), findsOneWidget);
    expect(find.text('DAILY GATE-IN ACCESS'), findsOneWidget);
  });
}
