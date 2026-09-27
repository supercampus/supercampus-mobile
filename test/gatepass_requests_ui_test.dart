import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supercampus_mobile/src/features/gatepass/data/gatepass_models.dart';
import 'package:supercampus_mobile/src/features/gatepass/data/gatepass_pass_phase.dart';
import 'package:supercampus_mobile/src/features/gatepass/presentation/apply_outpass_sheet.dart';
import 'package:supercampus_mobile/src/features/gatepass/presentation/gatepass_requests_screen.dart';

void main() {
  testWidgets('request cards omit ids and workflow tags and open the QR', (
    tester,
  ) async {
    final request = GatepassRequest(
      id: '3fa677e5-8f41-4355-8e74-03fe770cd135',
      type: GatepassRequestType.localOuting,
      departureAt: DateTime(2026, 9, 2, 16),
      returnAt: DateTime(2026, 9, 2, 20),
      destination: 'Lala',
      reason: 'Personal work',
      guardianPhone: '9876543210',
      status: ApprovalStatus.approved,
      submittedAt: DateTime(2026, 9, 1),
      qrPayload: '3fa677e5-8f41-4355-8e74-03fe770cd135',
      manualCode: '9021',
      workflowState: 'approved',
      passKind: GatepassPassKind.outpass,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GatepassRequestsScreen(
            requests: [request],
            residency: StudentResidency.hosteller,
            onApplyLeavePass: () {},
            onApplyOutpass: () {},
            onCancel: (_) async {},
            now: DateTime(2026, 9, 2, 17),
          ),
        ),
      ),
    );

    expect(find.text('My requests'), findsNothing);
    expect(find.text('Active'), findsWidgets);
    expect(find.textContaining('3fa677e5'), findsNothing);
    expect(find.text('Parent approval'), findsNothing);
    expect(find.text('Warden approval'), findsNothing);
    expect(find.text('Principal approval'), findsNothing);
    expect(find.text('009021'), findsOneWidget);
    expect(find.byKey(const ValueKey('request-qr-open')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('request-qr-open')));
    await tester.pumpAndSettle();

    expect(find.text('Gatepass QR'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('fullscreen-request-qr-code')),
      findsOneWidget,
    );
  });

  GatepassRequest outpass({
    required String id,
    required DateTime from,
    required DateTime to,
    ApprovalStatus status = ApprovalStatus.approved,
  }) => GatepassRequest(
    id: id,
    type: GatepassRequestType.localOuting,
    departureAt: from,
    returnAt: to,
    destination: 'City library',
    reason: 'Collect reserved books',
    guardianPhone: '9876543210',
    status: status,
    submittedAt: from.subtract(const Duration(days: 1)),
    qrPayload: 'supercampus://gate/outpass/$id',
    manualCode: '123456',
    workflowState: status.name,
  );

  Future<void> pumpHistory(
    WidgetTester tester,
    List<GatepassRequest> requests,
    DateTime now,
  ) {
    tester.view.physicalSize = const Size(420, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GatepassRequestsScreen(
            requests: requests,
            residency: StudentResidency.hosteller,
            onApplyLeavePass: () {},
            onApplyOutpass: () {},
            onCancel: (_) async {},
            now: now,
          ),
        ),
      ),
    );
  }

  testWidgets('an approved pass expires once its return time has passed', (
    tester,
  ) async {
    // 26 Sep, 4 PM to 8 PM, viewed on 27 Sep.
    final request = outpass(
      id: 'GP-1',
      from: DateTime(2026, 9, 26, 16),
      to: DateTime(2026, 9, 26, 20),
    );
    await pumpHistory(tester, [request], DateTime(2026, 9, 27, 10));

    expect(find.text('Expired'), findsOneWidget);
    expect(find.text('Past'), findsOneWidget);
    expect(find.text('Ready at the gate'), findsNothing);
    expect(find.text('Gate access ready'), findsNothing);
    expect(find.byType(QrImageView), findsNothing);
    expect(find.byKey(const ValueKey('request-qr-open')), findsNothing);
    expect(find.byKey(const ValueKey('request-qr-code')), findsNothing);
    expect(find.byKey(const ValueKey('request-expired-note')), findsOneWidget);
  });

  testWidgets('only a pass inside its window shows the QR', (tester) async {
    final now = DateTime(2026, 9, 27, 17);
    final current = outpass(
      id: 'GP-NOW',
      from: DateTime(2026, 9, 27, 16),
      to: DateTime(2026, 9, 27, 20),
    );
    final later = outpass(
      id: 'GP-LATER',
      from: DateTime(2026, 9, 28, 16),
      to: DateTime(2026, 9, 28, 20),
    );
    final lapsed = outpass(
      id: 'GP-OLD',
      from: DateTime(2026, 9, 20, 16),
      to: DateTime(2026, 9, 20, 20),
    );
    await pumpHistory(tester, [lapsed, later, current], now);

    expect(find.text('Active'), findsNWidgets(2)); // section + chip
    expect(find.text('Upcoming'), findsNWidgets(2)); // section + chip
    expect(find.text('Expired'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.byKey(const ValueKey('request-qr-open')), findsOneWidget);
    expect(find.text('Ready at the gate'), findsOneWidget);
  });

  testWidgets('completed and rejected statuses from the server are kept', (
    tester,
  ) async {
    final now = DateTime(2026, 9, 27, 10);
    await pumpHistory(tester, [
      outpass(
        id: 'GP-DONE',
        from: DateTime(2026, 9, 25, 16),
        to: DateTime(2026, 9, 25, 20),
        status: ApprovalStatus.completed,
      ),
      outpass(
        id: 'GP-NO',
        from: DateTime(2026, 9, 28, 16),
        to: DateTime(2026, 9, 28, 20),
        status: ApprovalStatus.rejected,
      ),
    ], now);

    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('Rejected'), findsOneWidget);
    expect(find.text('Expired'), findsNothing);
    expect(find.byType(QrImageView), findsNothing);
  });

  test('pass phase follows the pass window', () {
    final request = outpass(
      id: 'GP-P',
      from: DateTime(2026, 9, 26, 16),
      to: DateTime(2026, 9, 26, 20),
    );
    expect(
      gatepassPassPhase(request, at: DateTime(2026, 9, 26, 12)),
      GatepassPassPhase.upcoming,
    );
    expect(
      gatepassPassPhase(request, at: DateTime(2026, 9, 26, 17)),
      GatepassPassPhase.active,
    );
    expect(
      gatepassPassPhase(request, at: DateTime(2026, 9, 26, 20)),
      GatepassPassPhase.expired,
    );
    expect(
      gatepassPassPhase(
        outpass(
          id: 'GP-W',
          from: DateTime(2026, 9, 26, 16),
          to: DateTime(2026, 9, 26, 20),
          status: ApprovalStatus.pending,
        ),
        at: DateTime(2026, 9, 27),
      ),
      GatepassPassPhase.expired,
    );
  });

  testWidgets('leave form uses only the free-text reason field', (
    tester,
  ) async {
    const student = GatepassStudent(
      name: 'Vishnu',
      email: 'vishnu@example.com',
      rollNumber: '413225243049',
      department: 'CSE',
      residency: StudentResidency.hosteller,
      hostel: 'Hostel A',
      room: 'B-204',
      isOnCampus: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ApplyOutpassSheet(
          passKind: GatepassPassKind.leavePass,
          student: student,
          onSubmit: (_) async => throw UnimplementedError(),
        ),
      ),
    );

    expect(find.text('Leave reason'), findsNothing);
    expect(find.text('Medical'), findsNothing);
    expect(find.text('Emergency'), findsNothing);
    expect(find.text('Reason'), findsOneWidget);
  });
}
