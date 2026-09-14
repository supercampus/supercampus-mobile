import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/features/gatepass/data/gatepass_models.dart';
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
          ),
        ),
      ),
    );

    expect(find.text('My requests'), findsNothing);
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
