import 'hostel_models.dart';
import 'hostel_repository.dart';

class MockHostelRepository implements HostelRepository {
  MockHostelRepository({
    required this.studentName,
    required this.studentCode,
  });

  final String studentName;
  final String studentCode;

  late HostelStore _store = _initMockData();

  HostelStore _initMockData() {
    final now = DateTime.now();

    final bedA = HostelBed(
      id: 'bed_b204_a',
      code: 'Bed A',
      status: BedStatus.occupied,
      occupantName: 'Rohan Sharma',
      occupantStudentId: 'SC2600101',
    );

    final bedB = HostelBed(
      id: 'bed_b204_b',
      code: 'Bed B',
      status: BedStatus.occupied,
      occupantName: studentName,
      occupantStudentId: studentCode,
    );

    final room204 = HostelRoom(
      id: 'room_b204',
      roomNumber: 'B-204',
      capacity: 2,
      status: RoomStatus.full,
      type: 'Double Sharing',
      beds: [bedA, bedB],
    );

    final room205 = HostelRoom(
      id: 'room_b205',
      roomNumber: 'B-205',
      capacity: 2,
      status: RoomStatus.partiallyOccupied,
      type: 'Double Sharing',
      beds: [
        const HostelBed(
          id: 'bed_b205_a',
          code: 'Bed A',
          status: BedStatus.occupied,
          occupantName: 'Aarav Patel',
        ),
        const HostelBed(
          id: 'bed_b205_b',
          code: 'Bed B',
          status: BedStatus.available,
        ),
      ],
    );

    final room206 = HostelRoom(
      id: 'room_b206',
      roomNumber: 'B-206',
      capacity: 1,
      status: RoomStatus.available,
      type: 'Single',
      beds: [
        const HostelBed(
          id: 'bed_b206_a',
          code: 'Bed A',
          status: BedStatus.available,
        ),
      ],
    );

    final floor2 = HostelFloor(floorNumber: 2, rooms: [room204, room205, room206]);

    final blockB = HostelBlock(id: 'block_b', name: 'Block B', floors: [floor2]);

    final hostelA = HostelBuilding(
      id: 'hostel_a',
      name: 'Hostel A (Men\'s Residency)',
      campus: 'Main Campus',
      genderPolicy: 'Male Only',
      blocks: [blockB],
      totalBeds: 450,
      occupiedBeds: 412,
    );

    final hostelB = HostelBuilding(
      id: 'hostel_b',
      name: 'Hostel B (Women\'s Residency)',
      campus: 'Main Campus',
      genderPolicy: 'Female Only',
      blocks: [],
      totalBeds: 500,
      occupiedBeds: 468,
    );

    final activeResidency = HostelResidency(
      id: 'res_2026_01',
      studentId: 'stud_999',
      studentName: studentName,
      studentCode: studentCode,
      programme: 'B.Tech Computer Science',
      academicYear: '2026-27',
      hostelName: 'Hostel A',
      blockName: 'Block B',
      floorNumber: 2,
      roomNumber: 'B-204',
      bedCode: 'Bed B',
      checkInAt: now.subtract(const Duration(days: 45)),
      residencyStatus: ResidencyStatus.active,
      presenceStatus: PresenceStatus.insideHostel,
      dueAmount: 0.0,
    );

    final sampleOutpass = HostelOutpass(
      id: 'OUT-2026-8842',
      residencyId: activeResidency.id,
      studentName: studentName,
      studentCode: studentCode,
      hostelRoom: 'Hostel A · B-204',
      leavingAt: DateTime(now.year, now.month, now.day, 18, 30),
      expectedReturnAt: DateTime(now.year, now.month, now.day, 21, 30),
      destination: 'Central Mall & Book Store',
      reason: 'Personal Supplies Purchase',
      status: OutpassStatus.approved,
      qrPayload: 'SC-OUTPASS:OUT-2026-8842:${activeResidency.id}',
    );

    final messBreakfast = MessMealToken(
      id: 'MESS-${now.year}${now.month}${now.day}-BF',
      residencyId: activeResidency.id,
      studentName: studentName,
      mealType: MealType.breakfast,
      date: now,
      status: MealTokenStatus.used,
      qrCode: 'MESS-TOKEN:BF:${activeResidency.id}',
      redeemedAt: DateTime(now.year, now.month, now.day, 8, 25),
    );

    final messLunch = MessMealToken(
      id: 'MESS-${now.year}${now.month}${now.day}-LN',
      residencyId: activeResidency.id,
      studentName: studentName,
      mealType: MealType.lunch,
      date: now,
      status: MealTokenStatus.unused,
      qrCode: 'MESS-TOKEN:LN:${activeResidency.id}',
    );

    final messDinner = MessMealToken(
      id: 'MESS-${now.year}${now.month}${now.day}-DN',
      residencyId: activeResidency.id,
      studentName: studentName,
      mealType: MealType.dinner,
      date: now,
      status: MealTokenStatus.unused,
      qrCode: 'MESS-TOKEN:DN:${activeResidency.id}',
    );

    final complaint1 = HostelComplaint(
      id: 'HM-4821',
      residencyId: activeResidency.id,
      roomNumber: 'B-204',
      category: 'Electrical',
      description: 'Ceiling fan regulator knob broken, running at max speed.',
      status: ComplaintStatus.inProgress,
      createdAt: now.subtract(const Duration(days: 2)),
      assignedTo: 'Manoj Kumar (Electrical Team)',
    );

    final roomChangeReq = RoomChangeRequest(
      id: 'RCR-1049',
      residencyId: activeResidency.id,
      studentName: studentName,
      currentRoom: 'Hostel A / B-204 / Bed B',
      reason: 'Prefer quiet study environment on higher floor.',
      preferredHostel: 'Hostel A / Block C (Floor 3)',
      status: RoomChangeStatus.underReview,
      requestedAt: now.subtract(const Duration(days: 4)),
    );

    final visitorPass = VisitorPass(
      id: 'VIS-9932',
      residencyId: activeResidency.id,
      visitorName: 'Rajesh Kumar (Father)',
      visitorContact: '+91 98765 43210',
      purpose: 'Deliver academic books & laptop charger',
      visitDate: now,
      validFromTime: '04:00 PM',
      validUntilTime: '07:00 PM',
      status: 'APPROVED',
    );

    final clearance = HostelClearance(
      id: 'CLR-SC2600142',
      residencyId: activeResidency.id,
      studentName: studentName,
      roomNumber: 'B-204',
      roomCleared: true,
      assetsReturned: true,
      keyReturned: true,
      feesPaid: true,
      messCleared: true,
      complaintsClosed: true,
      damageSettled: true,
      status: ClearanceStatus.approved,
    );

    final movementLogs = [
      HostelMovement(
        id: 'MOV-101',
        residencyId: activeResidency.id,
        studentName: studentName,
        movementType: 'ENTRY',
        timestamp: DateTime(now.year, now.month, now.day - 1, 21, 12),
        gateName: 'Hostel A Gate 1',
        method: 'QR Scan',
        outpassId: 'OUT-2026-8800',
      ),
      HostelMovement(
        id: 'MOV-100',
        residencyId: activeResidency.id,
        studentName: studentName,
        movementType: 'EXIT',
        timestamp: DateTime(now.year, now.month, now.day - 1, 18, 45),
        gateName: 'Hostel A Gate 1',
        method: 'QR Scan',
        outpassId: 'OUT-2026-8800',
      ),
    ];

    return HostelStore(
      activeResidency: activeResidency,
      buildings: [hostelA, hostelB],
      applications: [],
      outpasses: [sampleOutpass],
      movements: movementLogs,
      messTokens: [messBreakfast, messLunch, messDinner],
      complaints: [complaint1],
      roomChangeRequests: [roomChangeReq],
      visitorPasses: [visitorPass],
      clearance: clearance,
    );
  }

  @override
  Future<HostelStore> loadStore() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return _store;
  }

  @override
  Future<HostelApplication> applyForAccommodation({
    required String preferredRoomType,
    required String specialRequirements,
  }) async {
    final app = HostelApplication(
      id: 'APP-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      studentId: studentCode,
      studentName: studentName,
      academicYear: '2026-27',
      preferredRoomType: preferredRoomType,
      specialRequirements: specialRequirements,
      status: ApplicationStatus.submitted,
      appliedAt: DateTime.now(),
    );

    _store = _store.copyWith(applications: [app, ..._store.applications]);
    return app;
  }

  @override
  Future<HostelOutpass> requestOutpass({
    required DateTime leavingAt,
    required DateTime expectedReturnAt,
    required String destination,
    required String reason,
  }) async {
    final id = 'OUT-2026-${(1000 + _store.outpasses.length + 1)}';
    final activeRes = _store.activeResidency!;
    final outpass = HostelOutpass(
      id: id,
      residencyId: activeRes.id,
      studentName: studentName,
      studentCode: studentCode,
      hostelRoom: '${activeRes.hostelName} · ${activeRes.roomNumber}',
      leavingAt: leavingAt,
      expectedReturnAt: expectedReturnAt,
      destination: destination,
      reason: reason,
      status: OutpassStatus.approved,
      qrPayload: 'SC-OUTPASS:$id:${activeRes.id}',
    );

    _store = _store.copyWith(outpasses: [outpass, ..._store.outpasses]);
    return outpass;
  }

  @override
  Future<HostelOutpass> approveOutpass(String outpassId) async {
    final outpasses = _store.outpasses.map((o) {
      if (o.id == outpassId) {
        return o.copyWith(status: OutpassStatus.approved);
      }
      return o;
    }).toList();
    _store = _store.copyWith(outpasses: outpasses);
    return outpasses.firstWhere((o) => o.id == outpassId);
  }

  @override
  Future<HostelMovement> scanOutpassGate({
    required String outpassId,
    required String gateName,
    required String action,
  }) async {
    final now = DateTime.now();
    final isExit = action.toUpperCase() == 'EXIT';

    final outpasses = _store.outpasses.map((o) {
      if (o.id == outpassId) {
        if (isExit) {
          return o.copyWith(
            status: OutpassStatus.active,
            actualExitAt: now,
          );
        } else {
          final isLate = now.isAfter(o.expectedReturnAt);
          return o.copyWith(
            status: isLate ? OutpassStatus.lateReturn : OutpassStatus.completed,
            actualReturnAt: now,
          );
        }
      }
      return o;
    }).toList();

    var updatedResidency = _store.activeResidency;
    if (updatedResidency != null) {
      updatedResidency = updatedResidency.copyWith(
        presenceStatus: isExit ? PresenceStatus.outsideHostel : PresenceStatus.insideHostel,
      );
    }

    final movement = HostelMovement(
      id: 'MOV-${now.millisecondsSinceEpoch.toString().substring(7)}',
      residencyId: updatedResidency?.id ?? 'res_01',
      studentName: studentName,
      movementType: isExit ? 'EXIT' : 'ENTRY',
      timestamp: now,
      gateName: gateName,
      method: 'QR Scan',
      outpassId: outpassId,
    );

    _store = _store.copyWith(
      outpasses: outpasses,
      activeResidency: updatedResidency,
      movements: [movement, ..._store.movements],
    );

    return movement;
  }

  @override
  Future<MessMealToken> redeemMessMeal(String tokenId) async {
    final now = DateTime.now();
    final updatedTokens = _store.messTokens.map((t) {
      if (t.id == tokenId) {
        return t.copyWith(
          status: MealTokenStatus.used,
          redeemedAt: now,
        );
      }
      return t;
    }).toList();

    _store = _store.copyWith(messTokens: updatedTokens);
    return updatedTokens.firstWhere((t) => t.id == tokenId);
  }

  @override
  Future<HostelComplaint> submitComplaint({
    required String category,
    required String description,
  }) async {
    final complaint = HostelComplaint(
      id: 'HM-${(4820 + _store.complaints.length + 1)}',
      residencyId: _store.activeResidency?.id ?? 'res_01',
      roomNumber: _store.activeResidency?.roomNumber ?? 'B-204',
      category: category,
      description: description,
      status: ComplaintStatus.submitted,
      createdAt: DateTime.now(),
    );

    _store = _store.copyWith(complaints: [complaint, ..._store.complaints]);
    return complaint;
  }

  @override
  Future<RoomChangeRequest> requestRoomChange({
    required String reason,
    required String preferredHostel,
  }) async {
    final req = RoomChangeRequest(
      id: 'RCR-${(1050 + _store.roomChangeRequests.length)}',
      residencyId: _store.activeResidency?.id ?? 'res_01',
      studentName: studentName,
      currentRoom: '${_store.activeResidency?.hostelName} / ${_store.activeResidency?.roomNumber}',
      reason: reason,
      preferredHostel: preferredHostel,
      status: RoomChangeStatus.submitted,
      requestedAt: DateTime.now(),
    );

    _store = _store.copyWith(roomChangeRequests: [req, ..._store.roomChangeRequests]);
    return req;
  }

  @override
  Future<VisitorPass> inviteVisitor({
    required String visitorName,
    required String visitorContact,
    required String purpose,
    required DateTime visitDate,
    required String validFromTime,
    required String validUntilTime,
  }) async {
    final pass = VisitorPass(
      id: 'VIS-${(9930 + _store.visitorPasses.length + 1)}',
      residencyId: _store.activeResidency?.id ?? 'res_01',
      visitorName: visitorName,
      visitorContact: visitorContact,
      purpose: purpose,
      visitDate: visitDate,
      validFromTime: validFromTime,
      validUntilTime: validUntilTime,
      status: 'APPROVED',
    );

    _store = _store.copyWith(visitorPasses: [pass, ..._store.visitorPasses]);
    return pass;
  }

  @override
  Future<HostelClearance> submitVacateRequest() async {
    final clr = HostelClearance(
      id: 'CLR-$studentCode',
      residencyId: _store.activeResidency?.id ?? 'res_01',
      studentName: studentName,
      roomNumber: _store.activeResidency?.roomNumber ?? 'B-204',
      roomCleared: false,
      assetsReturned: false,
      keyReturned: false,
      feesPaid: true,
      messCleared: true,
      complaintsClosed: true,
      damageSettled: true,
      status: ClearanceStatus.requested,
    );

    _store = _store.copyWith(
      clearance: clr,
      activeResidency: _store.activeResidency?.copyWith(
        residencyStatus: ResidencyStatus.vacating,
      ),
    );
    return clr;
  }

  @override
  Future<HostelClearance> updateClearanceChecklist({
    required String clearanceId,
    required bool roomCleared,
    required bool assetsReturned,
    required bool keyReturned,
    required bool feesPaid,
    required bool messCleared,
    required bool complaintsClosed,
    required bool damageSettled,
  }) async {
    final updated = HostelClearance(
      id: clearanceId,
      residencyId: _store.activeResidency?.id ?? 'res_01',
      studentName: studentName,
      roomNumber: _store.activeResidency?.roomNumber ?? 'B-204',
      roomCleared: roomCleared,
      assetsReturned: assetsReturned,
      keyReturned: keyReturned,
      feesPaid: feesPaid,
      messCleared: messCleared,
      complaintsClosed: complaintsClosed,
      damageSettled: damageSettled,
      status: (roomCleared && assetsReturned && keyReturned && feesPaid && messCleared && complaintsClosed && damageSettled)
          ? ClearanceStatus.readyForCheckout
          : ClearanceStatus.inspectionPending,
    );

    _store = _store.copyWith(clearance: updated);
    return updated;
  }

  @override
  Future<HostelResidency> completeCheckout(String residencyId) async {
    final updatedResidency = _store.activeResidency?.copyWith(
      residencyStatus: ResidencyStatus.completed,
      checkOutAt: DateTime.now(),
    );

    _store = _store.copyWith(
      activeResidency: updatedResidency,
      clearance: HostelClearance(
        id: _store.clearance?.id ?? 'CLR_01',
        residencyId: residencyId,
        studentName: studentName,
        roomNumber: _store.activeResidency?.roomNumber ?? 'B-204',
        roomCleared: true,
        assetsReturned: true,
        keyReturned: true,
        feesPaid: true,
        messCleared: true,
        complaintsClosed: true,
        damageSettled: true,
        status: ClearanceStatus.completed,
      ),
    );

    return updatedResidency!;
  }
}
