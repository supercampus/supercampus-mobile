enum PassVerificationStatus { valid, expired, restricted, invalid }

class GateVerificationResult {
  const GateVerificationResult({
    required this.passId,
    required this.studentName,
    required this.rollNumber,
    required this.department,
    required this.hostelRoom,
    required this.passType,
    required this.departureTime,
    required this.expectedReturnTime,
    required this.status,
    required this.statusReason,
    required this.parentApproved,
    required this.wardenApproved,
  });

  final String passId;
  final String studentName;
  final String rollNumber;
  final String department;
  final String hostelRoom;
  final String passType;
  final DateTime departureTime;
  final DateTime expectedReturnTime;
  final PassVerificationStatus status;
  final String statusReason;
  final bool parentApproved;
  final bool wardenApproved;
}

class SecurityActiveOutpass {
  const SecurityActiveOutpass({
    required this.id,
    required this.studentName,
    required this.rollNumber,
    required this.passType,
    required this.destination,
    required this.exitTime,
    required this.expectedReturnTime,
    required this.statusLabel,
    required this.isOverdue,
  });

  final String id;
  final String studentName;
  final String rollNumber;
  final String passType;
  final String destination;
  final DateTime exitTime;
  final DateTime expectedReturnTime;
  final String statusLabel;
  final bool isOverdue;
}

class VisitorPassLog {
  const VisitorPassLog({
    required this.id,
    required this.visitorName,
    required this.phone,
    required this.personToVisit,
    required this.relationship,
    required this.purpose,
    required this.checkInTime,
    this.checkOutTime,
    required this.isCheckedIn,
    required this.badgeNumber,
  });

  final String id;
  final String visitorName;
  final String phone;
  final String personToVisit;
  final String relationship;
  final String purpose;
  final DateTime checkInTime;
  final DateTime? checkOutTime;
  final bool isCheckedIn;
  final String badgeNumber;
}

class SecurityAlert {
  const SecurityAlert({
    required this.id,
    required this.title,
    required this.description,
    required this.timestamp,
    required this.severity, // low, medium, high, critical
    required this.location,
  });

  final String id;
  final String title;
  final String description;
  final DateTime timestamp;
  final String severity;
  final String location;
}
