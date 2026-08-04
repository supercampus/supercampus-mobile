import 'parent_models.dart';

class MockParentRepository {
  WardProfile _ward = WardProfile(
    name: 'Alex Johnson',
    rollNumber: '2024-CS-042',
    department: 'B.Tech Computer Science & Eng.',
    semester: 'Semester 5',
    hostelName: 'Hostel B (Boys Block)',
    roomNumber: 'Room 304',
    campusStatus: 'Inside Campus (Hostel B)',
    canteenBalance: 450.0,
    overallAttendancePercentage: 88.5,
  );

  final List<ParentOutpassRequest> _outpassRequests = [
    ParentOutpassRequest(
      id: 'GP-2026-990',
      wardName: 'Alex Johnson',
      requestType: 'Weekend Home Visit',
      destination: 'Home (Springfield, Sector 4)',
      reason: 'Family function & weekend visit',
      departureTime: DateTime.now().add(const Duration(hours: 4)),
      expectedReturnTime: DateTime.now().add(const Duration(days: 2)),
      status: 'Pending Parent Approval',
    ),
    ParentOutpassRequest(
      id: 'GP-2026-881',
      wardName: 'Alex Johnson',
      requestType: 'Local Outing',
      destination: 'Downtown Tech Hub',
      reason: 'Project team discussion',
      departureTime: DateTime.now().subtract(const Duration(days: 1)),
      expectedReturnTime: DateTime.now().subtract(const Duration(days: 1, hours: -4)),
      status: 'Approved',
      parentComment: 'Approved via SMS OTP',
    ),
  ];

  final List<WardFeeItem> _fees = [
    WardFeeItem(
      id: 'FEE-501',
      title: 'Semester 5 Tuition Fee',
      dueDate: DateTime.now().add(const Duration(days: 15)),
      amount: 45000.0,
      isPaid: false,
    ),
    WardFeeItem(
      id: 'FEE-502',
      title: 'Hostel & Mess Charges (Q3)',
      dueDate: DateTime.now().add(const Duration(days: 25)),
      amount: 18500.0,
      isPaid: false,
    ),
    WardFeeItem(
      id: 'FEE-401',
      title: 'Semester 4 Examination Fee',
      dueDate: DateTime.now().subtract(const Duration(days: 60)),
      amount: 2500.0,
      isPaid: true,
    ),
  ];

  final List<WardSubjectAttendance> _attendanceList = [
    const WardSubjectAttendance(
      subjectCode: 'CS301',
      subjectName: 'Data Structures & Algorithms',
      attendedClasses: 28,
      totalClasses: 30,
      facultyName: 'Prof. Sarah Jenkins',
    ),
    const WardSubjectAttendance(
      subjectCode: 'CS302',
      subjectName: 'Database Management Systems',
      attendedClasses: 24,
      totalClasses: 28,
      facultyName: 'Dr. Michael Chang',
    ),
    const WardSubjectAttendance(
      subjectCode: 'CS303',
      subjectName: 'Computer Networks',
      attendedClasses: 22,
      totalClasses: 26,
      facultyName: 'Prof. Alan Vance',
    ),
    const WardSubjectAttendance(
      subjectCode: 'CS304',
      subjectName: 'Software Engineering Lab',
      attendedClasses: 14,
      totalClasses: 16,
      facultyName: 'Dr. Emily Watson',
    ),
  ];

  WardProfile getWardProfile() => _ward;
  List<ParentOutpassRequest> getOutpassRequests() => List.unmodifiable(_outpassRequests);
  List<WardFeeItem> getFees() => List.unmodifiable(_fees);
  List<WardSubjectAttendance> getAttendance() => List.unmodifiable(_attendanceList);

  void reviewOutpass(String requestId, bool approve, String? note) {
    final index = _outpassRequests.indexWhere((r) => r.id == requestId);
    if (index != -1) {
      final req = _outpassRequests[index];
      _outpassRequests[index] = ParentOutpassRequest(
        id: req.id,
        wardName: req.wardName,
        requestType: req.requestType,
        destination: req.destination,
        reason: req.reason,
        departureTime: req.departureTime,
        expectedReturnTime: req.expectedReturnTime,
        status: approve ? 'Approved' : 'Rejected',
        parentComment: note,
      );
    }
  }

  void topupCanteenWallet(double amount) {
    _ward = WardProfile(
      name: _ward.name,
      rollNumber: _ward.rollNumber,
      department: _ward.department,
      semester: _ward.semester,
      hostelName: _ward.hostelName,
      roomNumber: _ward.roomNumber,
      campusStatus: _ward.campusStatus,
      canteenBalance: _ward.canteenBalance + amount,
      overallAttendancePercentage: _ward.overallAttendancePercentage,
    );
  }

  void payFee(String feeId) {
    final index = _fees.indexWhere((f) => f.id == feeId);
    if (index != -1) {
      final f = _fees[index];
      _fees[index] = WardFeeItem(
        id: f.id,
        title: f.title,
        dueDate: f.dueDate,
        amount: f.amount,
        isPaid: true,
      );
    }
  }
}
