class FacultyCourse {
  const FacultyCourse({
    required this.id,
    required this.code,
    required this.name,
    required this.section,
    required this.totalEnrolled,
    required this.schedule,
    required this.roomNumber,
  });

  final String id;
  final String code;
  final String name;
  final String section;
  final int totalEnrolled;
  final String schedule;
  final String roomNumber;
}

class StudentAttendanceItem {
  StudentAttendanceItem({
    required this.rollNumber,
    required this.studentName,
    this.attendanceStatus = 'Present', // "Present", "Absent", "On Duty (OD)"
    this.isApprovedOD = false,
    this.odReason,
    this.isODConsented = false,
  });

  final String rollNumber;
  final String studentName;
  String attendanceStatus;
  bool isApprovedOD;
  String? odReason;
  bool isODConsented;
}

class FacultyAcademicLeaveRequest {
  const FacultyAcademicLeaveRequest({
    required this.id,
    required this.studentName,
    required this.rollNumber,
    required this.leaveType,
    required this.reason,
    required this.startDate,
    required this.endDate,
    required this.status, // "Pending", "Approved", "Rejected"
  });

  final String id;
  final String studentName;
  final String rollNumber;
  final String leaveType;
  final String reason;
  final DateTime startDate;
  final DateTime endDate;
  final String status;
}

class DepartmentNotice {
  const DepartmentNotice({
    required this.id,
    required this.title,
    required this.content,
    required this.postedAt,
    required this.author,
    required this.targetAudience,
  });

  final String id;
  final String title;
  final String content;
  final DateTime postedAt;
  final String author;
  final String targetAudience;
}
