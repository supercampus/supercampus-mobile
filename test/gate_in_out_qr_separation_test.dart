import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supercampus_mobile/src/features/gatepass/data/gatepass_models.dart';
import 'package:supercampus_mobile/src/features/gatepass/data/gatepass_qr_selector.dart';
import 'package:supercampus_mobile/src/features/gatepass/presentation/gatepass_dashboard_screen.dart';
import 'package:supercampus_mobile/src/features/modules/presentation/today_glance.dart';
import 'package:supercampus_mobile/src/features/modules/presentation/widgets/status_cards/gatepass_ticket_card.dart';
import 'package:supercampus_mobile/src/features/modules/presentation/widgets/status_cards/status_card_builder.dart';
import 'package:supercampus_mobile/src/features/modules/presentation/widgets/status_cards/status_card_models.dart';
import 'package:supercampus_mobile/src/features/security/data/security_gate_repository.dart';

void main() {
  group('Gate-In vs Gate-Out QR Separation', () {
    final now = DateTime.now();
    final sampleStore = GatepassStore(
      student: const GatepassStudent(
        name: 'Alex Johnson',
        email: 'alex@mec.local',
        rollNumber: '413225243049',
        department: 'AIDS',
        residency: StudentResidency.hosteller,
        hostel: 'Hostel A',
        room: '101',
        isOnCampus: true,
      ),
      workflow: const GatepassWorkflowDefinition(
        tenantId: 'college_1',
        version: 1,
        initialState: 'submitted',
        terminalStates: ['completed', 'rejected'],
        states: [],
        transitions: [],
      ),
      dailyPass: DailyAccessPass(
        id: 'DAY-01',
        validOn: now,
        validFrom: now.subtract(const Duration(hours: 1)),
        validUntil: now.add(const Duration(hours: 8)),
        qrPayload: 'supercampus://gate/entry/413225243049',
        manualCode: '567890',
      ),
      requests: [
        GatepassRequest(
          id: 'GP-OUT-101',
          type: GatepassRequestType.localOuting,
          departureAt: now.add(const Duration(hours: 1)),
          returnAt: now.add(const Duration(hours: 5)),
          destination: 'City Center',
          reason: 'Books',
          guardianPhone: '9876543210',
          status: ApprovalStatus.approved,
          submittedAt: now.subtract(const Duration(hours: 2)),
          qrPayload: 'supercampus://gate/outpass/GP-OUT-101',
          manualCode: '235512',
        ),
      ],
      visitors: const [],
      movements: const [],
    );

    test('Gate-In QR payload is NOT the same as Gate-Out QR payload', () {
      final gateInQr = gateInPassQr(sampleStore);
      final gateOutQr = validGateOutPassQr(sampleStore);

      expect(gateInQr, contains('/entry/'));
      expect(gateOutQr, contains('/outpass/'));
      expect(gateInQr, isNot(equals(gateOutQr)));
    });

    test('validGateOutPassQr returns null when there is no approved outpass', () {
      final storeWithoutApproved = sampleStore.copyWith(requests: const []);
      final gateOut = validGateOutPassQr(storeWithoutApproved);
      expect(gateOut, isNull);
    });

    testWidgets('Dashboard QR next to apply buttons opens Gate-In QR dialog', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GatepassDashboardScreen(
              store: sampleStore,
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

      // Verify the QR in the row next to Apply buttons exists
      final qrFinder = find.byType(QrImageView);
      expect(qrFinder, findsOneWidget);

      // Tap the QR code next to Apply buttons
      await tester.tap(qrFinder);
      await tester.pumpAndSettle();

      // Verify full screen dialog explicitly displays CAMPUS GATE-IN ACCESS
      expect(find.text('CAMPUS GATE-IN ACCESS'), findsOneWidget);
      expect(
        find.text('Present this QR at security gate for campus entry (Gate-In)'),
        findsOneWidget,
      );
      // And the 6-digit gate-in manual code
      expect(find.text('567890'), findsOneWidget);
      // And definitely NOT the outpass manual code
      expect(find.text('235512'), findsNothing);
    });
  });

  group('Status Card Gatepass Restrictions & Dotted QR Style', () {
    test('Status card does NOT show Gate-In QR code', () {
      const glanceWithGateInOnly = GlanceFacts(
        activities: [
          StudentActivity(
            id: 'gatepass-entry-1',
            kind: StudentActivityKind.gatepass,
            title: 'Campus gate-in',
            supporting: 'Entry credential',
            moduleId: 'gatepass',
            priority: 20,
            statusLabel: 'approved',
          ),
        ],
        // If gatepassQr contains a Gate-In payload, it must be ignored by status card builder
        gatepassQr: 'supercampus://gate/entry/413225243049',
      );

      final cards = buildStudentStatusCards(
        glance: glanceWithGateInOnly,
        includePreviews: false,
      );

      // Must be empty because Gate-In passes are not outpasses/leavepasses
      expect(cards, isEmpty);
    });

    test('Status card shows valid approved outpass with outpass QR', () {
      const glanceWithApprovedOutpass = GlanceFacts(
        activities: [
          StudentActivity(
            id: 'gatepass-GP-OUT-101',
            kind: StudentActivityKind.gatepass,
            title: 'Outpass approved',
            supporting: 'City Center · Return: 8:00 PM',
            moduleId: 'gatepass',
            priority: 20,
            statusLabel: 'approved',
          ),
        ],
        gatepassQr: 'supercampus://gate/outpass/GP-OUT-101',
      );

      final cards = buildStudentStatusCards(
        glance: glanceWithApprovedOutpass,
        includePreviews: false,
      );

      expect(cards.length, 1);
      final gpCard = cards.first as GatepassTicketCardData;
      expect(gpCard.qrPayload, 'supercampus://gate/outpass/GP-OUT-101');
      expect(gpCard.status, ApprovalStatus.approved);
    });

    testWidgets('GatepassTicketCard renders QR with dotted circle style', (
      tester,
    ) async {
      const data = GatepassTicketCardData(
        id: 'gp-101',
        title: 'outpass',
        status: ApprovalStatus.approved,
        validUntilText: 'VALID UNTIL 08:00 PM',
        destination: 'Campus Exit',
        qrPayload: 'supercampus://gate/outpass/GP-OUT-101',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GatepassTicketCard(
              data: data,
              onTap: () {},
            ),
          ),
        ),
      );

      final qrWidgetFinder = find.byType(QrImageView);
      expect(qrWidgetFinder, findsOneWidget);

      final qrWidget = tester.widget<QrImageView>(qrWidgetFinder);
      expect(qrWidget.dataModuleStyle?.dataModuleShape, QrDataModuleShape.circle);
      expect(qrWidget.eyeStyle?.eyeShape, QrEyeShape.circle);
    });
  });

  group('Purpose Validation for Gatepass Scanning', () {
    final repo = MockSecurityGateRepository();

    test('Reject Gate-Out pass when security is set to Gate-In', () async {
      expect(
        () => repo.scan(
          qrPayload: 'supercampus://gate/outpass/GP-OUT-101',
          direction: GateDirection.entry,
          checkpoint: 'Main gate',
        ),
        throwsA(
          isA<SecurityGateException>().having(
            (e) => e.message,
            'message',
            contains('It cannot be used for campus Gate-In'),
          ),
        ),
      );
    });

    test('Reject Gate-In pass when security is set to Gate-Out', () async {
      expect(
        () => repo.scan(
          qrPayload: 'supercampus://gate/entry/413225243049',
          direction: GateDirection.exit,
          checkpoint: 'Main gate',
        ),
        throwsA(
          isA<SecurityGateException>().having(
            (e) => e.message,
            'message',
            contains('requires an approved Outpass or Leave pass'),
          ),
        ),
      );
    });

    test('Accept Gate-In pass when security is set to Gate-In', () async {
      final movement = await repo.scan(
        qrPayload: 'supercampus://gate/entry/413225243049',
        direction: GateDirection.entry,
        checkpoint: 'Main gate',
      );

      expect(movement.direction, GateDirection.entry);
      expect(movement.passType, 'Daily Gate-In Pass');
    });

    test('Accept Gate-Out pass when security is set to Gate-Out', () async {
      final movement = await repo.scan(
        qrPayload: 'supercampus://gate/outpass/GP-OUT-101',
        direction: GateDirection.exit,
        checkpoint: 'Main gate',
      );

      expect(movement.direction, GateDirection.exit);
      expect(movement.passType, 'Approved Outpass');
    });
  });
}
