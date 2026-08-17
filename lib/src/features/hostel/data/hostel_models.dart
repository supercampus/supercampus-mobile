import 'package:flutter/material.dart';

enum ResidencyStatus {
  reserved,
  checkInPending,
  active,
  vacating,
  completed,
  cancelled,
}

extension ResidencyStatusX on ResidencyStatus {
  String get label => switch (this) {
        ResidencyStatus.reserved => 'Reserved',
        ResidencyStatus.checkInPending => 'Check-In Pending',
        ResidencyStatus.active => 'Active Resident',
        ResidencyStatus.vacating => 'Vacating',
        ResidencyStatus.completed => 'Completed / Checked-Out',
        ResidencyStatus.cancelled => 'Cancelled',
      };

  Color get color => switch (this) {
        ResidencyStatus.active => const Color(0xFF1B5E20),
        ResidencyStatus.checkInPending || ResidencyStatus.reserved => const Color(0xFFE65100),
        ResidencyStatus.vacating => const Color(0xFFC2185B),
        ResidencyStatus.completed => const Color(0xFF424242),
        ResidencyStatus.cancelled => const Color(0xFFB71C1C),
      };
}

enum PresenceStatus {
  insideHostel,
  outsideHostel,
  away,
}

extension PresenceStatusX on PresenceStatus {
  String get label => switch (this) {
        PresenceStatus.insideHostel => 'Inside Hostel',
        PresenceStatus.outsideHostel => 'Outside Hostel',
        PresenceStatus.away => 'Away on Leave',
      };

  Color get color => switch (this) {
        PresenceStatus.insideHostel => const Color(0xFF2E7D32),
        PresenceStatus.outsideHostel => const Color(0xFFEF6C00),
        PresenceStatus.away => const Color(0xFF1565C0),
      };
}

enum ApplicationStatus {
  submitted,
  underReview,
  approved,
  waitlisted,
  rejected,
  cancelled,
}

extension ApplicationStatusX on ApplicationStatus {
  String get label => switch (this) {
        ApplicationStatus.submitted => 'Submitted',
        ApplicationStatus.underReview => 'Under Review',
        ApplicationStatus.approved => 'Approved',
        ApplicationStatus.waitlisted => 'Waitlisted',
        ApplicationStatus.rejected => 'Rejected',
        ApplicationStatus.cancelled => 'Cancelled',
      };
}

enum RoomStatus { available, partiallyOccupied, full, maintenance, blocked }

extension RoomStatusX on RoomStatus {
  String get label => switch (this) {
        RoomStatus.available => 'Available',
        RoomStatus.partiallyOccupied => 'Partially Occupied',
        RoomStatus.full => 'Full',
        RoomStatus.maintenance => 'Maintenance',
        RoomStatus.blocked => 'Blocked',
      };
}

enum BedStatus { available, reserved, occupied, maintenance, blocked }

extension BedStatusX on BedStatus {
  String get label => switch (this) {
        BedStatus.available => 'Available',
        BedStatus.reserved => 'Reserved',
        BedStatus.occupied => 'Occupied',
        BedStatus.maintenance => 'Maintenance',
        BedStatus.blocked => 'Blocked',
      };
}

enum OutpassStatus {
  draft,
  submitted,
  underReview,
  approved,
  active,
  completed,
  lateReturn,
  rejected,
  cancelled,
  expired,
}

extension OutpassStatusX on OutpassStatus {
  String get label => switch (this) {
        OutpassStatus.draft => 'Draft',
        OutpassStatus.submitted => 'Submitted',
        OutpassStatus.underReview => 'Under Review',
        OutpassStatus.approved => 'Approved',
        OutpassStatus.active => 'Active Away',
        OutpassStatus.completed => 'Completed',
        OutpassStatus.lateReturn => 'Late Return Flagged',
        OutpassStatus.rejected => 'Rejected',
        OutpassStatus.cancelled => 'Cancelled',
        OutpassStatus.expired => 'Expired',
      };
}

enum MealType { breakfast, lunch, dinner }

extension MealTypeX on MealType {
  String get label => switch (this) {
        MealType.breakfast => 'Breakfast',
        MealType.lunch => 'Lunch',
        MealType.dinner => 'Dinner',
      };

  String get timeWindow => switch (this) {
        MealType.breakfast => '7:30 AM – 9:30 AM',
        MealType.lunch => '12:30 PM – 2:30 PM',
        MealType.dinner => '7:30 PM – 9:30 PM',
      };
}

enum MealTokenStatus { unused, used, expired, rejected }

enum ComplaintStatus { submitted, assigned, inProgress, resolved, closed }

extension ComplaintStatusX on ComplaintStatus {
  String get label => switch (this) {
        ComplaintStatus.submitted => 'Submitted',
        ComplaintStatus.assigned => 'Assigned',
        ComplaintStatus.inProgress => 'In Progress',
        ComplaintStatus.resolved => 'Resolved',
        ComplaintStatus.closed => 'Closed',
      };
}

enum RoomChangeStatus {
  submitted,
  underReview,
  approved,
  newRoomReserved,
  moving,
  completed,
  rejected,
  cancelled,
}

enum ClearanceStatus {
  requested,
  underReview,
  approved,
  inspectionPending,
  clearancePending,
  readyForCheckout,
  completed,
  cancelled,
}

/// A Bed inside a Hostel Room
class HostelBed {
  const HostelBed({
    required this.id,
    required this.code, // e.g. Bed A
    required this.status,
    this.occupantName,
    this.occupantStudentId,
  });

  final String id;
  final String code;
  final BedStatus status;
  final String? occupantName;
  final String? occupantStudentId;
}

/// A Room inside a Block/Floor
class HostelRoom {
  const HostelRoom({
    required this.id,
    required this.roomNumber,
    required this.capacity,
    required this.status,
    required this.beds,
    required this.type, // Single, Double Sharing, Triple Sharing
  });

  final String id;
  final String roomNumber;
  final int capacity;
  final RoomStatus status;
  final List<HostelBed> beds;
  final String type;
}

/// A Floor inside a Block
class HostelFloor {
  const HostelFloor({
    required this.floorNumber,
    required this.rooms,
  });

  final int floorNumber;
  final List<HostelRoom> rooms;
}

/// A Block inside a Hostel
class HostelBlock {
  const HostelBlock({
    required this.id,
    required this.name,
    required this.floors,
  });

  final String id;
  final String name;
  final List<HostelFloor> floors;
}

/// Main Hostel Entity
class HostelBuilding {
  const HostelBuilding({
    required this.id,
    required this.name,
    required this.campus,
    required this.genderPolicy,
    required this.blocks,
    required this.totalBeds,
    required this.occupiedBeds,
  });

  final String id;
  final String name;
  final String campus;
  final String genderPolicy;
  final List<HostelBlock> blocks;
  final int totalBeds;
  final int occupiedBeds;
}

/// Core Hostel Operational Record - Everything connects to this!
class HostelResidency {
  const HostelResidency({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.studentCode,
    required this.programme,
    required this.academicYear,
    required this.hostelName,
    required this.blockName,
    required this.floorNumber,
    required this.roomNumber,
    required this.bedCode,
    required this.checkInAt,
    required this.residencyStatus,
    required this.presenceStatus,
    required this.dueAmount,
    this.checkOutAt,
  });

  final String id;
  final String studentId;
  final String studentName;
  final String studentCode;
  final String programme;
  final String academicYear;
  final String hostelName;
  final String blockName;
  final int floorNumber;
  final String roomNumber;
  final String bedCode;
  final DateTime checkInAt;
  final ResidencyStatus residencyStatus;
  final PresenceStatus presenceStatus;
  final double dueAmount;
  final DateTime? checkOutAt;

  HostelResidency copyWith({
    ResidencyStatus? residencyStatus,
    PresenceStatus? presenceStatus,
    double? dueAmount,
    String? roomNumber,
    String? bedCode,
    DateTime? checkOutAt,
  }) {
    return HostelResidency(
      id: id,
      studentId: studentId,
      studentName: studentName,
      studentCode: studentCode,
      programme: programme,
      academicYear: academicYear,
      hostelName: hostelName,
      blockName: blockName,
      floorNumber: floorNumber,
      roomNumber: roomNumber ?? this.roomNumber,
      bedCode: bedCode ?? this.bedCode,
      checkInAt: checkInAt,
      residencyStatus: residencyStatus ?? this.residencyStatus,
      presenceStatus: presenceStatus ?? this.presenceStatus,
      dueAmount: dueAmount ?? this.dueAmount,
      checkOutAt: checkOutAt ?? this.checkOutAt,
    );
  }
}

/// Accommodation Application
class HostelApplication {
  const HostelApplication({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.academicYear,
    required this.preferredRoomType,
    required this.specialRequirements,
    required this.status,
    required this.appliedAt,
  });

  final String id;
  final String studentId;
  final String studentName;
  final String academicYear;
  final String preferredRoomType;
  final String specialRequirements;
  final ApplicationStatus status;
  final DateTime appliedAt;
}

/// Outpass / Leave Record with QR Code data
class HostelOutpass {
  const HostelOutpass({
    required this.id,
    required this.residencyId,
    required this.studentName,
    required this.studentCode,
    required this.hostelRoom,
    required this.leavingAt,
    required this.expectedReturnAt,
    required this.destination,
    required this.reason,
    required this.status,
    this.actualExitAt,
    this.actualReturnAt,
    this.qrPayload,
  });

  final String id;
  final String residencyId;
  final String studentName;
  final String studentCode;
  final String hostelRoom;
  final DateTime leavingAt;
  final DateTime expectedReturnAt;
  final String destination;
  final String reason;
  final OutpassStatus status;
  final DateTime? actualExitAt;
  final DateTime? actualReturnAt;
  final String? qrPayload;

  HostelOutpass copyWith({
    OutpassStatus? status,
    DateTime? actualExitAt,
    DateTime? actualReturnAt,
  }) {
    return HostelOutpass(
      id: id,
      residencyId: residencyId,
      studentName: studentName,
      studentCode: studentCode,
      hostelRoom: hostelRoom,
      leavingAt: leavingAt,
      expectedReturnAt: expectedReturnAt,
      destination: destination,
      reason: reason,
      status: status ?? this.status,
      actualExitAt: actualExitAt ?? this.actualExitAt,
      actualReturnAt: actualReturnAt ?? this.actualReturnAt,
      qrPayload: qrPayload,
    );
  }
}

/// Movement Record (Gate Log)
class HostelMovement {
  const HostelMovement({
    required this.id,
    required this.residencyId,
    required this.studentName,
    required this.movementType, // ENTRY / EXIT
    required this.timestamp,
    required this.gateName,
    required this.method, // QR / Biometric / Manual
    this.outpassId,
  });

  final String id;
  final String residencyId;
  final String studentName;
  final String movementType;
  final DateTime timestamp;
  final String gateName;
  final String method;
  final String? outpassId;
}

/// Mess Meal QR Token
class MessMealToken {
  const MessMealToken({
    required this.id,
    required this.residencyId,
    required this.studentName,
    required this.mealType,
    required this.date,
    required this.status,
    required this.qrCode,
    this.redeemedAt,
  });

  final String id;
  final String residencyId;
  final String studentName;
  final MealType mealType;
  final DateTime date;
  final MealTokenStatus status;
  final String qrCode;
  final DateTime? redeemedAt;

  MessMealToken copyWith({
    MealTokenStatus? status,
    DateTime? redeemedAt,
  }) {
    return MessMealToken(
      id: id,
      residencyId: residencyId,
      studentName: studentName,
      mealType: mealType,
      date: date,
      status: status ?? this.status,
      qrCode: qrCode,
      redeemedAt: redeemedAt ?? this.redeemedAt,
    );
  }
}

/// Complaint / Maintenance Item
class HostelComplaint {
  const HostelComplaint({
    required this.id,
    required this.residencyId,
    required this.roomNumber,
    required this.category,
    required this.description,
    required this.status,
    required this.createdAt,
    this.assignedTo,
    this.resolutionNotes,
  });

  final String id;
  final String residencyId;
  final String roomNumber;
  final String category;
  final String description;
  final ComplaintStatus status;
  final DateTime createdAt;
  final String? assignedTo;
  final String? resolutionNotes;

  HostelComplaint copyWith({
    ComplaintStatus? status,
    String? assignedTo,
    String? resolutionNotes,
  }) {
    return HostelComplaint(
      id: id,
      residencyId: residencyId,
      roomNumber: roomNumber,
      category: category,
      description: description,
      status: status ?? this.status,
      createdAt: createdAt,
      assignedTo: assignedTo ?? this.assignedTo,
      resolutionNotes: resolutionNotes ?? this.resolutionNotes,
    );
  }
}

/// Room Change Request
class RoomChangeRequest {
  const RoomChangeRequest({
    required this.id,
    required this.residencyId,
    required this.studentName,
    required this.currentRoom,
    required this.reason,
    required this.preferredHostel,
    required this.status,
    required this.requestedAt,
    this.newRoomAllocated,
  });

  final String id;
  final String residencyId;
  final String studentName;
  final String currentRoom;
  final String reason;
  final String preferredHostel;
  final RoomChangeStatus status;
  final DateTime requestedAt;
  final String? newRoomAllocated;

  RoomChangeRequest copyWith({
    RoomChangeStatus? status,
    String? newRoomAllocated,
  }) {
    return RoomChangeRequest(
      id: id,
      residencyId: residencyId,
      studentName: studentName,
      currentRoom: currentRoom,
      reason: reason,
      preferredHostel: preferredHostel,
      status: status ?? this.status,
      requestedAt: requestedAt,
      newRoomAllocated: newRoomAllocated ?? this.newRoomAllocated,
    );
  }
}

/// Visitor Pass
class VisitorPass {
  const VisitorPass({
    required this.id,
    required this.residencyId,
    required this.visitorName,
    required this.visitorContact,
    required this.purpose,
    required this.visitDate,
    required this.validFromTime,
    required this.validUntilTime,
    required this.status, // PENDING, APPROVED, CHECKED_IN, CHECKED_OUT
  });

  final String id;
  final String residencyId;
  final String visitorName;
  final String visitorContact;
  final String purpose;
  final DateTime visitDate;
  final String validFromTime;
  final String validUntilTime;
  final String status;
}

/// 7-Point Hostel Clearance Checklist
class HostelClearance {
  const HostelClearance({
    required this.id,
    required this.residencyId,
    required this.studentName,
    required this.roomNumber,
    required this.roomCleared,
    required this.assetsReturned,
    required this.keyReturned,
    required this.feesPaid,
    required this.messCleared,
    required this.complaintsClosed,
    required this.damageSettled,
    required this.status,
    this.damageChargeAmount = 0.0,
  });

  final String id;
  final String residencyId;
  final String studentName;
  final String roomNumber;
  final bool roomCleared;
  final bool assetsReturned;
  final bool keyReturned;
  final bool feesPaid;
  final bool messCleared;
  final bool complaintsClosed;
  final bool damageSettled;
  final ClearanceStatus status;
  final double damageChargeAmount;

  bool get isFullyCleared =>
      roomCleared &&
      assetsReturned &&
      keyReturned &&
      feesPaid &&
      messCleared &&
      complaintsClosed &&
      damageSettled;
}

/// Aggregate store holding all hostel state
class HostelStore {
  const HostelStore({
    required this.activeResidency,
    required this.buildings,
    required this.applications,
    required this.outpasses,
    required this.movements,
    required this.messTokens,
    required this.complaints,
    required this.roomChangeRequests,
    required this.visitorPasses,
    required this.clearance,
  });

  final HostelResidency? activeResidency;
  final List<HostelBuilding> buildings;
  final List<HostelApplication> applications;
  final List<HostelOutpass> outpasses;
  final List<HostelMovement> movements;
  final List<MessMealToken> messTokens;
  final List<HostelComplaint> complaints;
  final List<RoomChangeRequest> roomChangeRequests;
  final List<VisitorPass> visitorPasses;
  final HostelClearance? clearance;

  HostelStore copyWith({
    HostelResidency? activeResidency,
    List<HostelBuilding>? buildings,
    List<HostelApplication>? applications,
    List<HostelOutpass>? outpasses,
    List<HostelMovement>? movements,
    List<MessMealToken>? messTokens,
    List<HostelComplaint>? complaints,
    List<RoomChangeRequest>? roomChangeRequests,
    List<VisitorPass>? visitorPasses,
    HostelClearance? clearance,
  }) {
    return HostelStore(
      activeResidency: activeResidency ?? this.activeResidency,
      buildings: buildings ?? this.buildings,
      applications: applications ?? this.applications,
      outpasses: outpasses ?? this.outpasses,
      movements: movements ?? this.movements,
      messTokens: messTokens ?? this.messTokens,
      complaints: complaints ?? this.complaints,
      roomChangeRequests: roomChangeRequests ?? this.roomChangeRequests,
      visitorPasses: visitorPasses ?? this.visitorPasses,
      clearance: clearance ?? this.clearance,
    );
  }
}
