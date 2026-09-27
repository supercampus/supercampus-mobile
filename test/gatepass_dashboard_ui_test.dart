import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supercampus_mobile/src/features/gatepass/data/gatepass_models.dart';
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
    tester.view.physicalSize = const Size(390, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

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
    expect(find.text('Gatepass'), findsOneWidget);
    expect(find.text('Campus location verified'), findsOneWidget);
    expect(find.text('VS'), findsNothing);
    // The seeded approved outpass is for tomorrow: shown as the next pass.
    expect(find.text('Next pass'), findsOneWidget);
    expect(find.text('Local outing'), findsOneWidget);
    expect(find.text('Upcoming'), findsOneWidget);
    expect(find.text('Quick actions'), findsOneWidget);
    expect(find.text('Pass history'), findsOneWidget);
    expect(find.text('Invite visitor'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Local outing')).dy,
      lessThan(tester.getTopLeft(find.text('Recent movement')).dy),
    );
    // Only the campus entry QR is on the dashboard.
    expect(find.byType(QrImageView), findsOneWidget);

    await tester.tap(find.byType(QrImageView));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Gate-in QR'), findsOneWidget);
    expect(find.text('CAMPUS GATE-IN ACCESS'), findsOneWidget);
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
    expect(find.text('CAMPUS GATE-IN ACCESS'), findsOneWidget);
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

  testWidgets('an expired pass never surfaces as the current pass', (
    tester,
  ) async {
    final storeFuture = MockGatepassRepository(
      studentName: 'Vishnu S',
      email: 'student@mec.local',
    ).loadStore();
    await tester.pump(const Duration(milliseconds: 500));
    final loaded = await storeFuture;
    final expired = GatepassRequest(
      id: 'GP-OLD',
      type: GatepassRequestType.homeVisit,
      departureAt: DateTime(2026, 9, 26, 16),
      returnAt: DateTime(2026, 9, 26, 20),
      destination: 'Town',
      reason: 'Errand',
      guardianPhone: '9876543210',
      status: ApprovalStatus.approved,
      submittedAt: DateTime(2026, 9, 25),
      qrPayload: 'supercampus://gate/outpass/GP-OLD',
    );
    final store = loaded.copyWith(requests: [expired]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GatepassDashboardScreen(
            store: store,
            now: DateTime(2026, 9, 27, 10),
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

    expect(find.text('Home visit'), findsNothing);
    expect(find.text('Active pass'), findsNothing);
    expect(find.byType(QrImageView), findsOneWidget);
  });

  testWidgets('a failed location check is explained in full with a retry', (
    tester,
  ) async {
    final storeFuture = MockGatepassRepository(
      studentName: 'Vishnu S',
      email: 'student@mec.local',
    ).loadStore();
    await tester.pump(const Duration(milliseconds: 500));
    final loaded = await storeFuture;
    const issue =
        'Location permission is off. Turn it on in settings so we can confirm you are on campus.';
    final store = GatepassStore(
      student: loaded.student,
      workflow: loaded.workflow,
      dailyPass: null,
      dailyPassIssue: issue,
      requests: const [],
      visitors: const [],
      movements: const [],
    );
    var retried = 0;

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
            onRetryLocation: () => retried++,
            onExitModule: () {},
          ),
        ),
      ),
    );

    expect(find.text('Location check needs attention'), findsOneWidget);
    final text = tester.widget<Text>(find.text(issue));
    expect(text.maxLines, isNull);
    await tester.tap(find.text('Check location again'));
    expect(retried, 1);
  });
}
