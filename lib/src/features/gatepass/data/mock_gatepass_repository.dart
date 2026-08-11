import 'gatepass_models.dart';
import 'gatepass_repository.dart';

class MockGatepassRepository implements GatepassRepository {
  MockGatepassRepository({required String studentName, required String email})
    : _studentName = studentName,
      _email = email;

  final String _studentName;
  final String _email;
  GatepassStore? _store;

  @override
  Future<GatepassStore> loadStore() async {
    await Future<void>.delayed(const Duration(milliseconds: 450));
    return _store ??= _seedStore();
  }

  @override
  Future<GatepassRequest> submitRequest(GatepassRequestDraft draft) async {
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!draft.returnAt.isAfter(draft.departureAt)) {
      throw const GatepassException('Return time must be after departure.');
    }
    if (draft.reason.trim().length < 8) {
      throw const GatepassException('Add a little more detail to the reason.');
    }
    final store = await loadStore();
    if (store.requests.any(
      (request) => request.status == ApprovalStatus.pending,
    )) {
      throw const GatepassException(
        'You already have an outpass waiting for approval.',
      );
    }
    final request = GatepassRequest(
      id: 'GP-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      type: draft.type,
      departureAt: draft.departureAt,
      returnAt: draft.returnAt,
      destination: draft.destination.trim(),
      reason: draft.reason.trim(),
      guardianPhone: draft.guardianPhone.trim(),
      status: ApprovalStatus.pending,
      submittedAt: DateTime.now(),
      workflowVersion: store.workflow.version,
    );
    _store = store.copyWith(requests: [request, ...store.requests]);
    return request;
  }

  @override
  Future<VisitorInvitation> inviteVisitor(VisitorInvitationDraft draft) async {
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!draft.visitAt.isAfter(DateTime.now())) {
      throw const GatepassException('Choose a future visit time.');
    }
    final store = await loadStore();
    final invitation = VisitorInvitation(
      id: 'VIS-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      visitorName: draft.visitorName.trim(),
      phone: draft.phone.trim(),
      relationship: draft.relationship.trim(),
      purpose: draft.purpose.trim(),
      visitAt: draft.visitAt,
      status: ApprovalStatus.pending,
      submittedAt: DateTime.now(),
    );
    _store = store.copyWith(visitors: [invitation, ...store.visitors]);
    return invitation;
  }

  @override
  Future<GatepassRequest> cancelRequest(String requestId) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    final store = await loadStore();
    final index = store.requests.indexWhere(
      (request) => request.id == requestId,
    );
    if (index == -1 || store.requests[index].status != ApprovalStatus.pending) {
      throw const GatepassException('Only pending requests can be cancelled.');
    }
    final current = store.requests[index];
    final cancelled = GatepassRequest(
      id: current.id,
      type: current.type,
      departureAt: current.departureAt,
      returnAt: current.returnAt,
      destination: current.destination,
      reason: current.reason,
      guardianPhone: current.guardianPhone,
      status: ApprovalStatus.cancelled,
      submittedAt: current.submittedAt,
    );
    final requests = [...store.requests]..[index] = cancelled;
    _store = store.copyWith(requests: requests);
    return cancelled;
  }

  GatepassStore _seedStore() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return GatepassStore(
      student: GatepassStudent(
        name: _studentName,
        email: _email,
        rollNumber: 'MEC25AD48',
        department: 'AIDS',
        residency: StudentResidency.hosteller,
        hostel: 'Bharathi Hostel',
        room: 'B-214',
        isOnCampus: true,
      ),
      workflow: _workflowForEmail(),
      dailyPass: DailyAccessPass(
        id: 'DAY-${today.year}${today.month.toString().padLeft(2, '0')}${today.day.toString().padLeft(2, '0')}-48',
        validOn: today,
        validFrom: today.add(const Duration(hours: 6)),
        validUntil: today.add(const Duration(hours: 21)),
        qrPayload:
            'supercampus://gate/day/MEC25AD48/${today.toIso8601String()}',
      ),
      requests: [
        GatepassRequest(
          id: 'GP-240803',
          type: GatepassRequestType.localOuting,
          departureAt: today.add(const Duration(days: 1, hours: 16)),
          returnAt: today.add(const Duration(days: 1, hours: 20)),
          destination: 'City library',
          reason: 'Collect reserved academic reference books',
          guardianPhone: '9876543210',
          status: ApprovalStatus.approved,
          submittedAt: today.subtract(const Duration(hours: 5)),
          approver: 'Dr. Priya, HOD',
          qrPayload: 'supercampus://gate/outpass/GP-240803',
          workflowState: _approvedWorkflowState(),
        ),
        GatepassRequest(
          id: 'GP-240731',
          type: GatepassRequestType.homeVisit,
          departureAt: today
              .subtract(const Duration(days: 4))
              .add(const Duration(hours: 16)),
          returnAt: today
              .subtract(const Duration(days: 2))
              .add(const Duration(hours: 19)),
          destination: 'Coimbatore',
          reason: 'Weekend visit with family',
          guardianPhone: '9876543210',
          status: ApprovalStatus.completed,
          submittedAt: today.subtract(const Duration(days: 5)),
          approver: 'Dr. Priya, HOD',
          qrPayload: 'supercampus://gate/outpass/GP-240731',
          workflowState: 'completed',
        ),
        GatepassRequest(
          id: 'GP-240725',
          type: GatepassRequestType.localOuting,
          departureAt: today
              .subtract(const Duration(days: 9))
              .add(const Duration(hours: 17)),
          returnAt: today
              .subtract(const Duration(days: 9))
              .add(const Duration(hours: 20)),
          destination: 'Town centre',
          reason: 'Purchase academic supplies',
          guardianPhone: '9876543210',
          status: ApprovalStatus.rejected,
          submittedAt: today.subtract(const Duration(days: 10)),
          approver: 'Hostel warden',
          reviewNote: 'Requests must be submitted before 3 PM.',
          workflowState: 'rejected',
        ),
      ],
      visitors: [
        VisitorInvitation(
          id: 'VIS-8421',
          visitorName: 'Suresh Kumar',
          phone: '9876501234',
          relationship: 'Parent',
          purpose: 'Meet student and collect documents',
          visitAt: today.add(const Duration(days: 2, hours: 11)),
          status: ApprovalStatus.approved,
          submittedAt: today.subtract(const Duration(days: 1)),
          qrPayload: 'supercampus://visitor/VIS-8421',
        ),
      ],
      movements: [
        GateMovement(
          id: 'MOV-1',
          direction: MovementDirection.entry,
          recordedAt: today
              .subtract(const Duration(days: 2))
              .add(const Duration(hours: 18, minutes: 42)),
          gate: 'Main gate',
          method: 'Outpass QR',
        ),
        GateMovement(
          id: 'MOV-2',
          direction: MovementDirection.exit,
          recordedAt: today
              .subtract(const Duration(days: 4))
              .add(const Duration(hours: 16, minutes: 8)),
          gate: 'Main gate',
          method: 'Outpass QR',
        ),
      ],
    );
  }

  GatepassWorkflowDefinition _workflowForEmail() {
    if (_email.toLowerCase().contains('college1') ||
        _email.toLowerCase().contains('tenant-a')) {
      return _collegeOneWorkflow();
    }
    return _collegeTwoWorkflow();
  }

  String _approvedWorkflowState() =>
      _workflowForEmail().state('parent_approved') == null
      ? 'warden_approved'
      : 'parent_approved';

  GatepassWorkflowDefinition _collegeOneWorkflow() {
    return GatepassWorkflowDefinition(
      tenantId: 'college_1',
      version: 1,
      initialState: 'draft',
      terminalStates: const ['rejected', 'completed'],
      states: const [
        GatepassWorkflowState(
          id: 'draft',
          label: 'Draft',
          status: WorkflowStateStatus.draft,
        ),
        GatepassWorkflowState(
          id: 'submitted',
          label: 'Student submitted',
          status: WorkflowStateStatus.pending,
        ),
        GatepassWorkflowState(
          id: 'parent_approved',
          label: 'Parent approved',
          status: WorkflowStateStatus.approved,
        ),
        GatepassWorkflowState(
          id: 'warden_approved',
          label: 'Warden approved',
          status: WorkflowStateStatus.approved,
        ),
        GatepassWorkflowState(
          id: 'security_verified',
          label: 'Security verified',
          status: WorkflowStateStatus.completed,
        ),
        GatepassWorkflowState(
          id: 'rejected',
          label: 'Rejected',
          status: WorkflowStateStatus.rejected,
        ),
        GatepassWorkflowState(
          id: 'completed',
          label: 'Exit completed',
          status: WorkflowStateStatus.completed,
        ),
      ],
      transitions: const [
        GatepassWorkflowTransition(
          from: 'submitted',
          to: 'parent_approved',
          action: 'approve',
          requiredPermission: 'gatepass.outpass.approve',
          requiredRole: 'parent',
          label: 'Parent approve',
        ),
        GatepassWorkflowTransition(
          from: 'parent_approved',
          to: 'warden_approved',
          action: 'approve',
          requiredPermission: 'gatepass.outpass.approve',
          requiredRole: 'warden',
          label: 'Warden approve',
        ),
      ],
    );
  }

  GatepassWorkflowDefinition _collegeTwoWorkflow() {
    return const GatepassWorkflowDefinition(
      tenantId: 'college_2',
      version: 1,
      initialState: 'draft',
      terminalStates: ['rejected', 'completed'],
      states: [
        GatepassWorkflowState(
          id: 'draft',
          label: 'Draft',
          status: WorkflowStateStatus.draft,
        ),
        GatepassWorkflowState(
          id: 'submitted',
          label: 'Student submitted',
          status: WorkflowStateStatus.pending,
        ),
        GatepassWorkflowState(
          id: 'warden_approved',
          label: 'Warden approved',
          status: WorkflowStateStatus.approved,
        ),
        GatepassWorkflowState(
          id: 'security_verified',
          label: 'Security verified',
          status: WorkflowStateStatus.completed,
        ),
        GatepassWorkflowState(
          id: 'rejected',
          label: 'Rejected',
          status: WorkflowStateStatus.rejected,
        ),
        GatepassWorkflowState(
          id: 'completed',
          label: 'Exit completed',
          status: WorkflowStateStatus.completed,
        ),
      ],
      transitions: [
        GatepassWorkflowTransition(
          from: 'submitted',
          to: 'warden_approved',
          action: 'approve',
          requiredPermission: 'gatepass.outpass.approve',
          requiredRole: 'warden',
          label: 'Warden approve',
        ),
      ],
    );
  }
}
