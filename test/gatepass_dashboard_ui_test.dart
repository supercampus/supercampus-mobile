import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supercampus_mobile/src/features/gatepass/data/gatepass_models.dart';
import 'package:supercampus_mobile/src/features/gatepass/data/mock_gatepass_repository.dart';
import 'package:supercampus_mobile/src/features/gatepass/presentation/gatepass_dashboard_screen.dart';
import 'package:supercampus_mobile/src/features/gatepass/presentation/widgets/gatepass_ui.dart';

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
            onRetryLocation: () {},
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
    expect(find.text('Approved'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Local outing')).dy,
      greaterThan(tester.getTopLeft(find.text('Recent movement')).dy),
    );
    final recentSurface = find.ancestor(
      of: find.text('Recent movement'),
      matching: find.byType(GatepassSurface),
    );
    final outingSurface = find.ancestor(
      of: find.text('Local outing'),
      matching: find.byType(GatepassSurface),
    );
    expect(recentSurface, findsOneWidget);
    expect(outingSurface, findsOneWidget);
    expect(
      outingSurface.evaluate().single,
      same(recentSurface.evaluate().single),
    );
    expect(find.byType(QrImageView), findsOneWidget);

    await tester.tap(find.byType(QrImageView));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Gate-in QR'), findsOneWidget);
    expect(find.text('LOCAL OUTING'), findsOneWidget);
  });

  testWidgets('open daily QR expires on exit and refreshes on re-entry', (
    tester,
  ) async {
    final storeFuture = MockGatepassRepository(
      studentName: 'Vishnu S',
      email: 'student@mec.local',
    ).loadStore();
    await tester.pump(const Duration(milliseconds: 500));
    final loaded = await storeFuture;
    final store = loaded.copyWith(requests: const []);
    final livePass = ValueNotifier<DailyAccessPass?>(store.dailyPass);
    addTearDown(livePass.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GatepassDashboardScreen(
            store: store,
            liveDailyPass: livePass,
            onApplyLeavePass: () {},
            onApplyOutpass: () {},
            onOpenAccess: () {},
            onOpenRequests: () {},
            onInviteVisitor: () {},
            onRetryLocation: () {},
            onExitModule: () {},
          ),
        ),
      ),
    );

    await tester.tap(find.byType(QrImageView));
    await tester.pumpAndSettle();
    expect(find.text('DAILY GATE-IN ACCESS'), findsOneWidget);
    expect(find.text('567890'), findsOneWidget);

    livePass.value = null;
    await tester.pump();
    expect(find.text('QR expired'), findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);

    final previous = store.dailyPass!;
    livePass.value = DailyAccessPass(
      id: 'new-pass',
      validOn: previous.validOn,
      validFrom: DateTime.now(),
      validUntil: DateTime.now().add(const Duration(days: 365)),
      qrPayload: 'new-after-reentry',
      manualCode: '876543',
    );
    await tester.pump();
    expect(find.text('QR expired'), findsNothing);
    expect(find.text('876543'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
  });
}
