enum StudentResidency { dayScholar, hosteller }

extension StudentResidencyLabel on StudentResidency {
  String get label =>
      this == StudentResidency.dayScholar ? 'Day scholar' : 'Hosteller';
}

enum GatepassRequestType { localOuting, homeVisit, medical, emergency }

extension GatepassRequestTypeLabel on GatepassRequestType {
  String get label => switch (this) {
    GatepassRequestType.localOuting => 'Local outing',
    GatepassRequestType.homeVisit => 'Home visit',
    GatepassRequestType.medical => 'Medical',
    GatepassRequestType.emergency => 'Emergency',
  };
}

enum ApprovalStatus { pending, approved, rejected, completed, cancelled }

extension ApprovalStatusLabel on ApprovalStatus {
  String get label => switch (this) {
    ApprovalStatus.pending => 'Pending approval',
    ApprovalStatus.approved => 'Approved',
    ApprovalStatus.rejected => 'Rejected',
    ApprovalStatus.completed => 'Completed',
    ApprovalStatus.cancelled => 'Cancelled',
  };
}

class GatepassStudent {
  const GatepassStudent({
    required this.name,
    required this.email,
    required this.rollNumber,
    required this.department,
    required this.residency,
    required this.hostel,
    required this.room,
    required this.isOnCampus,
  });

  final String name;
  final String email;
  final String rollNumber;
  final String department;
  final StudentResidency residency;
  final String? hostel;
  final String? room;
  final bool isOnCampus;

  String get initials {
    final parts = name.split(' ').where((part) => part.isNotEmpty).toList();
    if (parts.isEmpty) return 'S';
    return parts.take(2).map((part) => part[0].toUpperCase()).join();
  }
}

class GatepassRequest {
  const GatepassRequest({
    required this.id,
    required this.type,
    required this.departureAt,
    required this.returnAt,
    required this.destination,
    required this.reason,
    required this.guardianPhone,
    required this.status,
    required this.submittedAt,
    this.approver,
    this.reviewNote,
    this.qrPayload,
  });

  final String id;
  final GatepassRequestType type;
  final DateTime departureAt;
  final DateTime returnAt;
  final String destination;
  final String reason;
  final String guardianPhone;
  final ApprovalStatus status;
  final DateTime submittedAt;
  final String? approver;
  final String? reviewNote;
  final String? qrPayload;
}

class VisitorInvitation {
  const VisitorInvitation({
    required this.id,
    required this.visitorName,
    required this.phone,
    required this.relationship,
    required this.purpose,
    required this.visitAt,
    required this.status,
    required this.submittedAt,
    this.qrPayload,
  });

  final String id;
  final String visitorName;
  final String phone;
  final String relationship;
  final String purpose;
  final DateTime visitAt;
  final ApprovalStatus status;
  final DateTime submittedAt;
  final String? qrPayload;
}

enum MovementDirection { entry, exit }

class GateMovement {
  const GateMovement({
    required this.id,
    required this.direction,
    required this.recordedAt,
    required this.gate,
    required this.method,
  });

  final String id;
  final MovementDirection direction;
  final DateTime recordedAt;
  final String gate;
  final String method;
}

class DailyAccessPass {
  const DailyAccessPass({
    required this.id,
    required this.validOn,
    required this.validFrom,
    required this.validUntil,
    required this.qrPayload,
  });

  final String id;
  final DateTime validOn;
  final DateTime validFrom;
  final DateTime validUntil;
  final String qrPayload;
}

class GatepassStore {
  const GatepassStore({
    required this.student,
    required this.dailyPass,
    required this.requests,
    required this.visitors,
    required this.movements,
  });

  final GatepassStudent student;
  final DailyAccessPass dailyPass;
  final List<GatepassRequest> requests;
  final List<VisitorInvitation> visitors;
  final List<GateMovement> movements;

  GatepassStore copyWith({
    List<GatepassRequest>? requests,
    List<VisitorInvitation>? visitors,
  }) {
    return GatepassStore(
      student: student,
      dailyPass: dailyPass,
      requests: requests ?? this.requests,
      visitors: visitors ?? this.visitors,
      movements: movements,
    );
  }
}

class GatepassRequestDraft {
  const GatepassRequestDraft({
    required this.type,
    required this.departureAt,
    required this.returnAt,
    required this.destination,
    required this.reason,
    required this.guardianPhone,
  });

  final GatepassRequestType type;
  final DateTime departureAt;
  final DateTime returnAt;
  final String destination;
  final String reason;
  final String guardianPhone;
}

class VisitorInvitationDraft {
  const VisitorInvitationDraft({
    required this.visitorName,
    required this.phone,
    required this.relationship,
    required this.purpose,
    required this.visitAt,
  });

  final String visitorName;
  final String phone;
  final String relationship;
  final String purpose;
  final DateTime visitAt;
}
