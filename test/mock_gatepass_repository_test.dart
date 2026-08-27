import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/features/gatepass/data/gatepass_models.dart';
import 'package:supercampus_mobile/src/features/gatepass/data/gatepass_repository.dart';
import 'package:supercampus_mobile/src/features/gatepass/data/mock_gatepass_repository.dart';

void main() {
  late MockGatepassRepository repository;

  setUp(() {
    repository = MockGatepassRepository(
      studentName: 'Test Student',
      email: 'student@example.com',
    );
  });

  test('loads student access, requests and movement history', () async {
    final store = await repository.loadStore();

    expect(store.student.name, 'Test Student');
    expect(store.student.residency, StudentResidency.hosteller);
    // The mock never fails to activate, so this one is always present.
    expect(store.dailyPass?.qrPayload, isNotEmpty);
    expect(store.requests, isNotEmpty);
    expect(store.movements, isNotEmpty);
  });

  test('submits and cancels a pending outpass', () async {
    final draft = _validRequestDraft();
    final request = await repository.submitRequest(draft);

    expect(request.status, ApprovalStatus.pending);
    expect(request.destination, 'City library');

    final cancelled = await repository.cancelRequest(request.id);
    expect(cancelled.status, ApprovalStatus.cancelled);
  });

  test('rejects an invalid outpass time range', () async {
    final departure = DateTime.now().add(const Duration(days: 1));

    expect(
      repository.submitRequest(
        GatepassRequestDraft(
          type: GatepassRequestType.localOuting,
          departureAt: departure,
          returnAt: departure.subtract(const Duration(hours: 1)),
          destination: 'City library',
          reason: 'Collect reference books',
          guardianPhone: '9876543210',
        ),
      ),
      throwsA(isA<GatepassException>()),
    );
  });

  test('creates a visitor invitation awaiting review', () async {
    final invitation = await repository.inviteVisitor(
      VisitorInvitationDraft(
        visitorName: 'Parent Name',
        phone: '9876543210',
        relationship: 'Parent',
        purpose: 'Meet the student',
        visitAt: DateTime.now().add(const Duration(days: 2)),
      ),
    );

    expect(invitation.status, ApprovalStatus.pending);
    expect(invitation.visitorName, 'Parent Name');
  });

  test(
    'loads tenant-specific outpass workflows without app code changes',
    () async {
      final collegeOne = await MockGatepassRepository(
        studentName: 'College One Student',
        email: 'student@college1.example',
      ).loadStore();
      final collegeTwo = await MockGatepassRepository(
        studentName: 'College Two Student',
        email: 'student@college2.example',
      ).loadStore();

      expect(collegeOne.workflow.state('parent_approved'), isNotNull);
      expect(collegeTwo.workflow.state('parent_approved'), isNull);
      expect(
        collegeOne.workflow.transition('submitted', 'approve')?.to,
        'parent_approved',
      );
      expect(
        collegeTwo.workflow.transition('submitted', 'approve')?.to,
        'warden_approved',
      );
    },
  );
}

GatepassRequestDraft _validRequestDraft() {
  final departure = DateTime.now().add(const Duration(days: 1));
  return GatepassRequestDraft(
    type: GatepassRequestType.localOuting,
    departureAt: departure,
    returnAt: departure.add(const Duration(hours: 3)),
    destination: 'City library',
    reason: 'Collect reference books',
    guardianPhone: '9876543210',
  );
}
