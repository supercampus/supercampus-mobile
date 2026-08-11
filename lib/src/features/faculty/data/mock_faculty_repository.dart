import 'faculty_models.dart';

class MockFacultyRepository {
  static final MockFacultyRepository _shared =
      MockFacultyRepository._internal();

  factory MockFacultyRepository() => _shared;

  MockFacultyRepository._internal();

  final List<FacultyCourse> _courses = [
    const FacultyCourse(
      id: 'CRS-101',
      code: 'CS301',
      name: 'Data Structures & Algorithms',
      section: 'CS-A',
      totalEnrolled: 42,
      schedule: 'Mon, Wed, Fri (10:00 AM - 11:30 AM)',
      roomNumber: 'Lecture Hall 302',
    ),
    const FacultyCourse(
      id: 'CRS-102',
      code: 'CS304',
      name: 'Software Engineering Lab',
      section: 'CS-B',
      totalEnrolled: 38,
      schedule: 'Tue, Thu (02:00 PM - 04:30 PM)',
      roomNumber: 'Software Lab 4',
    ),
  ];

  final Map<String, List<StudentAttendanceItem>> _rosters = {
    'CS301': [
      StudentAttendanceItem(
        rollNumber: '2024-CS-042',
        studentName: 'Alex Johnson',
        attendanceStatus: 'On Duty (OD)',
        isApprovedOD: true,
        odReason: 'Inter-University Hackathon (Approved by HOD)',
        isODConsented: false,
      ),
      StudentAttendanceItem(
        rollNumber: '2024-CS-043',
        studentName: 'Beatrix Kiddo',
        attendanceStatus: 'Present',
      ),
      StudentAttendanceItem(
        rollNumber: '2024-CS-044',
        studentName: 'Charles Xavier',
        attendanceStatus: 'Present',
      ),
      StudentAttendanceItem(
        rollNumber: '2024-CS-045',
        studentName: 'Diana Prince',
        attendanceStatus: 'On Duty (OD)',
        isApprovedOD: true,
        odReason: 'State Sports Championship (Approved by Physical Ed)',
        isODConsented: true,
      ),
      StudentAttendanceItem(
        rollNumber: '2024-CS-046',
        studentName: 'Ethan Hunt',
        attendanceStatus: 'Present',
      ),
    ],
  };

  final List<FacultyAcademicLeaveRequest> _leaveRequests = [
    FacultyAcademicLeaveRequest(
      id: 'ALR-701',
      studentName: 'Alex Johnson',
      rollNumber: '2024-CS-042',
      leaveType: 'Duty Leave (Hackathon Event)',
      reason: 'Representing college at Inter-University Tech Symposium',
      startDate: DateTime.now().add(const Duration(days: 2)),
      endDate: DateTime.now().add(const Duration(days: 4)),
      status: 'Approved',
    ),
    FacultyAcademicLeaveRequest(
      id: 'ALR-702',
      studentName: 'Priya Patel',
      rollNumber: '2024-ME-018',
      leaveType: 'Medical Leave',
      reason: 'Doctor prescribed rest for fever',
      startDate: DateTime.now().subtract(const Duration(days: 2)),
      endDate: DateTime.now(),
      status: 'Approved',
    ),
  ];

  final List<DepartmentNotice> _notices = [
    DepartmentNotice(
      id: 'NOT-301',
      title: 'Mid-Semester Exam Schedule Revision',
      content:
          'The CS301 exam will now take place on Friday at 09:00 AM in LH-302.',
      postedAt: DateTime.now().subtract(const Duration(hours: 4)),
      author: 'Prof. Sarah Jenkins',
      targetAudience: 'CS Dept Students',
      pdfName: 'mid_semester_exam_schedule.pdf',
      pdfUrl:
          'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
    ),
  ];

  List<FacultyCourse> getCourses() => List.unmodifiable(_courses);

  List<StudentAttendanceItem> getRoster(String courseCode) {
    return _rosters[courseCode] ??
        [
          StudentAttendanceItem(
            rollNumber: '2024-CS-042',
            studentName: 'Alex Johnson',
            attendanceStatus: 'On Duty (OD)',
            isApprovedOD: true,
            odReason: 'Inter-University Hackathon',
          ),
          StudentAttendanceItem(
            rollNumber: '2024-CS-043',
            studentName: 'Beatrix Kiddo',
            attendanceStatus: 'Present',
          ),
          StudentAttendanceItem(
            rollNumber: '2024-CS-044',
            studentName: 'Charles Xavier',
            attendanceStatus: 'Present',
          ),
        ];
  }

  List<FacultyAcademicLeaveRequest> getLeaveRequests() =>
      List.unmodifiable(_leaveRequests);
  List<DepartmentNotice> getNotices() => List.unmodifiable(_notices);

  void reviewLeave(String id, bool approve) {
    final index = _leaveRequests.indexWhere((l) => l.id == id);
    if (index != -1) {
      final item = _leaveRequests[index];
      _leaveRequests[index] = FacultyAcademicLeaveRequest(
        id: item.id,
        studentName: item.studentName,
        rollNumber: item.rollNumber,
        leaveType: item.leaveType,
        reason: item.reason,
        startDate: item.startDate,
        endDate: item.endDate,
        status: approve ? 'Approved' : 'Rejected',
      );
    }
  }

  void addNotice(DepartmentNotice notice) {
    _notices.insert(0, notice);
  }
}
