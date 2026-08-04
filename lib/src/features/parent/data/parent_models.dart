class WardProfile {
  const WardProfile({
    required this.name,
    required this.rollNumber,
    required this.department,
    required this.semester,
    required this.hostelName,
    required this.roomNumber,
    required this.campusStatus,
    required this.canteenBalance,
    required this.overallAttendancePercentage,
  });

  final String name;
  final String rollNumber;
  final String department;
  final String semester;
  final String hostelName;
  final String roomNumber;
  final String campusStatus; // e.g. "Inside Campus", "Outpass Active"
  final double canteenBalance;
  final double overallAttendancePercentage;
}

class ParentOutpassRequest {
  const ParentOutpassRequest({
    required this.id,
    required this.wardName,
    required this.requestType,
    required this.destination,
    required this.reason,
    required this.departureTime,
    required this.expectedReturnTime,
    required this.status, // "Pending Parent Approval", "Approved", "Rejected"
    this.parentComment,
  });

  final String id;
  final String wardName;
  final String requestType;
  final String destination;
  final String reason;
  final DateTime departureTime;
  final DateTime expectedReturnTime;
  final String status;
  final String? parentComment;
}

class WardFeeItem {
  const WardFeeItem({
    required this.id,
    required this.title,
    required this.dueDate,
    required this.amount,
    required this.isPaid,
  });

  final String id;
  final String title;
  final DateTime dueDate;
  final double amount;
  final bool isPaid;
}

class WardSubjectAttendance {
  const WardSubjectAttendance({
    required this.subjectCode,
    required this.subjectName,
    required this.attendedClasses,
    required this.totalClasses,
    required this.facultyName,
  });

  final String subjectCode;
  final String subjectName;
  final int attendedClasses;
  final int totalClasses;
  final String facultyName;

  double get percentage =>
      totalClasses == 0 ? 0 : (attendedClasses / totalClasses) * 100;
}
