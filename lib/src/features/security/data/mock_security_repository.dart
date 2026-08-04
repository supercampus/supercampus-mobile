import 'security_models.dart';

class MockSecurityRepository {
  final List<SecurityActiveOutpass> _activeOutpasses = [
    SecurityActiveOutpass(
      id: 'GP-2026-881',
      studentName: 'Alex Johnson',
      rollNumber: '2024-CS-042',
      passType: 'Weekend Outing',
      destination: 'Downtown Tech Hub',
      exitTime: DateTime.now().subtract(const Duration(hours: 3)),
      expectedReturnTime: DateTime.now().add(const Duration(hours: 2)),
      statusLabel: 'Out of Campus',
      isOverdue: false,
    ),
    SecurityActiveOutpass(
      id: 'GP-2026-904',
      studentName: 'Rohan Sharma',
      rollNumber: '2024-EC-109',
      passType: 'Local Outing',
      destination: 'Central Market',
      exitTime: DateTime.now().subtract(const Duration(hours: 5)),
      expectedReturnTime: DateTime.now().subtract(const Duration(minutes: 30)),
      statusLabel: 'OVERDUE RETURN',
      isOverdue: true,
    ),
    SecurityActiveOutpass(
      id: 'GP-2026-912',
      studentName: 'Priya Patel',
      rollNumber: '2024-ME-018',
      passType: 'Medical Emergency',
      destination: 'City Hospital',
      exitTime: DateTime.now().subtract(const Duration(hours: 1)),
      expectedReturnTime: DateTime.now().add(const Duration(hours: 4)),
      statusLabel: 'Out of Campus',
      isOverdue: false,
    ),
  ];

  final List<VisitorPassLog> _visitorLogs = [
    VisitorPassLog(
      id: 'VIS-401',
      visitorName: 'David Miller',
      phone: '+1 555-0192',
      personToVisit: 'Alex Johnson (Student)',
      relationship: 'Father',
      purpose: 'Delivering Academic Materials',
      checkInTime: DateTime.now().subtract(const Duration(minutes: 45)),
      isCheckedIn: true,
      badgeNumber: 'V-04',
    ),
    VisitorPassLog(
      id: 'VIS-402',
      visitorName: 'TechCorp Recruiter - Sarah',
      phone: '+1 555-0188',
      personToVisit: 'Placement Cell (Faculty)',
      relationship: 'Guest Speaker',
      purpose: 'Campus Seminar',
      checkInTime: DateTime.now().subtract(const Duration(hours: 2)),
      checkOutTime: DateTime.now().subtract(const Duration(minutes: 15)),
      isCheckedIn: false,
      badgeNumber: 'V-01',
    ),
  ];

  final List<SecurityAlert> _alerts = [
    SecurityAlert(
      id: 'ALT-101',
      title: 'Gate 2 Scanner Maintenance',
      description: 'North Gate RFID scanner undergoing scheduled calibration.',
      timestamp: DateTime.now().subtract(const Duration(minutes: 20)),
      severity: 'Low',
      location: 'North Gate 2',
    ),
    SecurityAlert(
      id: 'ALT-102',
      title: 'Overdue Student Flag',
      description: 'Rohan Sharma (2024-EC-109) exceeded return time by 30 mins.',
      timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
      severity: 'Medium',
      location: 'Main Entrance',
    ),
  ];

  List<SecurityActiveOutpass> getActiveOutpasses() => List.unmodifiable(_activeOutpasses);
  List<VisitorPassLog> getVisitorLogs() => List.unmodifiable(_visitorLogs);
  List<SecurityAlert> getAlerts() => List.unmodifiable(_alerts);

  GateVerificationResult verifyCode(String code) {
    final clean = code.trim().toUpperCase();
    if (clean.contains('EXPIRED') || clean == 'GP-EXPIRED') {
      return GateVerificationResult(
        passId: clean.isEmpty ? 'GP-EXPIRED' : clean,
        studentName: 'Rohan Sharma',
        rollNumber: '2024-EC-109',
        department: 'Electronics Eng.',
        hostelRoom: 'Hostel A, Rm 102',
        passType: 'Local Outing',
        departureTime: DateTime.now().subtract(const Duration(hours: 6)),
        expectedReturnTime: DateTime.now().subtract(const Duration(minutes: 45)),
        status: PassVerificationStatus.expired,
        statusReason: 'Gate pass expired 45 minutes ago. Needs warden clearance.',
        parentApproved: true,
        wardenApproved: false,
      );
    } else if (clean.contains('BLOCK') || clean.contains('RESTRICT')) {
      return GateVerificationResult(
        passId: clean.isEmpty ? 'GP-BLOCKED' : clean,
        studentName: 'Vikram Singh',
        rollNumber: '2024-CS-099',
        department: 'Computer Science',
        hostelRoom: 'Hostel C, Rm 401',
        passType: 'Emergency Leave',
        departureTime: DateTime.now(),
        expectedReturnTime: DateTime.now().add(const Duration(days: 1)),
        status: PassVerificationStatus.restricted,
        statusReason: 'Student is marked under academic restriction / curfew flag.',
        parentApproved: false,
        wardenApproved: false,
      );
    } else {
      return GateVerificationResult(
        passId: clean.isEmpty ? 'GP-2026-881' : clean,
        studentName: 'Alex Johnson',
        rollNumber: '2024-CS-042',
        department: 'Computer Science',
        hostelRoom: 'Hostel B, Rm 304',
        passType: 'Weekend Outing',
        departureTime: DateTime.now().subtract(const Duration(hours: 1)),
        expectedReturnTime: DateTime.now().add(const Duration(hours: 5)),
        status: PassVerificationStatus.valid,
        statusReason: 'Pass active and fully verified by parent & warden.',
        parentApproved: true,
        wardenApproved: true,
      );
    }
  }

  void recordGateAction(String passId, String actionType) {
    _activeOutpasses.removeWhere((p) => p.id == passId);
  }

  void addVisitorLog(VisitorPassLog log) {
    _visitorLogs.insert(0, log);
  }

  void checkoutVisitor(String visitorId) {
    final index = _visitorLogs.indexWhere((v) => v.id == visitorId);
    if (index != -1) {
      final existing = _visitorLogs[index];
      _visitorLogs[index] = VisitorPassLog(
        id: existing.id,
        visitorName: existing.visitorName,
        phone: existing.phone,
        personToVisit: existing.personToVisit,
        relationship: existing.relationship,
        purpose: existing.purpose,
        checkInTime: existing.checkInTime,
        checkOutTime: DateTime.now(),
        isCheckedIn: false,
        badgeNumber: existing.badgeNumber,
      );
    }
  }
}
