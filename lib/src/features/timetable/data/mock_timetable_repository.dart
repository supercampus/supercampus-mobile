import 'dart:async';
import 'package:intl/intl.dart';
import 'timetable_models.dart';
import 'timetable_repository.dart';

class MockTimetableRepository implements TimetableRepository {
  MockTimetableRepository() {
    _initSeedData();
  }

  late TimetableConfig _config;
  final List<TimetableEntry> _entries = [];
  final List<ConflictItem> _conflicts = [];
  final List<FacultySubstitution> _substitutions = [];
  final List<TimetableVersion> _versions = [];
  final List<FacultyMember> _facultyList = [];
  final List<FacultySubjectQuota> _quotas = [];
  final List<DisruptionAlert> _disruptions = [];
  final List<String> _availableClasses = ['CS-3A', 'CS-3B', 'ECE-2A', 'ME-2B'];

  // New Backend Module Storage
  final List<PeriodAttendanceRecord> _attendanceRecords = [];
  final List<FacultyLeaveRequest> _leaveRequests = [];
  final List<StudentOdRequest> _odRequests = [];
  final List<AppNotification> _notifications = [];
  final List<AuditLogEntry> _auditLogs = [];

  // Reactive Stream Controllers (WebSocket / SSE Simulation)
  final _substitutionsController = StreamController<List<FacultySubstitution>>.broadcast();
  final _disruptionsController = StreamController<List<DisruptionAlert>>.broadcast();
  final _attendanceController = StreamController<List<PeriodAttendanceRecord>>.broadcast();
  final _notificationsController = StreamController<List<AppNotification>>.broadcast();
  final _auditLogsController = StreamController<List<AuditLogEntry>>.broadcast();

  @override
  Stream<List<FacultySubstitution>> get substitutionsStream => _substitutionsController.stream;

  @override
  Stream<List<DisruptionAlert>> get disruptionsStream => _disruptionsController.stream;

  @override
  Stream<List<PeriodAttendanceRecord>> get attendanceStream => _attendanceController.stream;

  @override
  Stream<List<AppNotification>> get notificationsStream => _notificationsController.stream;

  @override
  Stream<List<AuditLogEntry>> get auditLogsStream => _auditLogsController.stream;

  void _initSeedData() {
    _config = const TimetableConfig(
      academicYear: '2026 - 2027',
      semester: 'Odd Semester 5',
      batchSection: 'CS-3A',
      workingDays: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'],
      collegeStartTime: '08:30',
      collegeEndTime: '16:30',
      periodsPerDay: 6,
      periodDurationMinutes: 50,
      breakSlots: [
        '11:10 AM - 11:30 AM (Tea Break)',
        '01:10 PM - 02:00 PM (Lunch Break)',
      ],
    );

    _facultyList.addAll([
      const FacultyMember(
        id: 'FAC-101',
        name: 'Prof. Sarah Jenkins',
        department: 'Computer Science',
        subjectsHandled: ['Database Systems', 'DBMS Lab'],
        isAvailable: true,
      ),
      const FacultyMember(
        id: 'FAC-102',
        name: 'Prof. Alan Turing',
        department: 'Computer Science',
        subjectsHandled: ['Operating Systems', 'OS Lab'],
        isAvailable: false,
        onLeave: true,
        leaveReason: 'Attending CS Conference',
      ),
      const FacultyMember(
        id: 'FAC-103',
        name: 'Prof. Grace Hopper',
        department: 'Computer Science',
        subjectsHandled: ['Computer Networks', 'Network Security'],
        isAvailable: true,
      ),
      const FacultyMember(
        id: 'FAC-104',
        name: 'Prof. Donald Knuth',
        department: 'Computer Science',
        subjectsHandled: ['Software Engineering', 'Algorithms'],
        isAvailable: true,
      ),
      const FacultyMember(
        id: 'FAC-105',
        name: 'Prof. Tim Berners-Lee',
        department: 'Computer Science',
        subjectsHandled: ['Web Development', 'Web Dev Lab'],
        isAvailable: false,
        onLeave: true,
        leaveReason: 'Personal Leave',
      ),
      const FacultyMember(
        id: 'ALLOC-9012',
        name: 'Dr. Marcus Vance',
        department: 'Computer Science',
        subjectsHandled: ['AI & Machine Learning', 'Data Mining'],
        isAvailable: true,
      ),
      const FacultyMember(
        id: 'FAC-108',
        name: 'Prof. Barbara Liskov',
        department: 'Computer Science',
        subjectsHandled: ['Cloud Computing Elective'],
        isAvailable: true,
      ),
    ]);

    _quotas.addAll([
      const FacultySubjectQuota(
        id: 'QUO-101',
        facultyName: 'Prof. Sarah Jenkins',
        department: 'Computer Science',
        subjectCode: 'CS301',
        subjectName: 'Database Systems',
        minWeeklyPeriods: 4,
      ),
      const FacultySubjectQuota(
        id: 'QUO-102',
        facultyName: 'Prof. Alan Turing',
        department: 'Computer Science',
        subjectCode: 'CS302',
        subjectName: 'Operating Systems',
        minWeeklyPeriods: 4,
      ),
      const FacultySubjectQuota(
        id: 'QUO-103',
        facultyName: 'Prof. Grace Hopper',
        department: 'Computer Science',
        subjectCode: 'CS303',
        subjectName: 'Computer Networks',
        minWeeklyPeriods: 3,
      ),
      const FacultySubjectQuota(
        id: 'QUO-104',
        facultyName: 'Prof. Donald Knuth',
        department: 'Computer Science',
        subjectCode: 'CS304',
        subjectName: 'Software Engineering',
        minWeeklyPeriods: 3,
      ),
      const FacultySubjectQuota(
        id: 'QUO-105',
        facultyName: 'Prof. Tim Berners-Lee',
        department: 'Computer Science',
        subjectCode: 'CS305L',
        subjectName: 'Web Dev Lab',
        minWeeklyPeriods: 2,
        isLab: true,
      ),
      const FacultySubjectQuota(
        id: 'QUO-106',
        facultyName: 'Dr. Marcus Vance',
        department: 'Computer Science',
        subjectCode: 'CS306',
        subjectName: 'AI & Machine Learning',
        minWeeklyPeriods: 3,
      ),
      const FacultySubjectQuota(
        id: 'QUO-107',
        facultyName: 'Prof. Barbara Liskov',
        department: 'Computer Science',
        subjectCode: 'CS308',
        subjectName: 'Cloud Computing Elective',
        minWeeklyPeriods: 2,
      ),
    ]);

    // Seed CS-3A entries
    _entries.addAll([
      const TimetableEntry(
        id: 'ENT-01',
        subjectCode: 'CS301',
        subjectName: 'Database Systems',
        facultyId: 'FAC-101',
        facultyName: 'Prof. Sarah Jenkins',
        className: 'CS-3A',
        dayOfWeek: 'Monday',
        timeSlot: '08:30 - 09:20 AM',
        periodIndex: 1,
        categoryColorValue: 0xFF1E88E5,
      ),
      const TimetableEntry(
        id: 'ENT-02',
        subjectCode: 'CS302',
        subjectName: 'Operating Systems',
        facultyId: 'FAC-102',
        facultyName: 'Prof. Alan Turing',
        className: 'CS-3A',
        dayOfWeek: 'Monday',
        timeSlot: '09:30 - 10:20 AM',
        periodIndex: 2,
        categoryColorValue: 0xFF43A047,
      ),
      const TimetableEntry(
        id: 'ENT-03',
        subjectCode: 'CS303',
        subjectName: 'Computer Networks',
        facultyId: 'FAC-103',
        facultyName: 'Prof. Grace Hopper',
        className: 'CS-3A',
        dayOfWeek: 'Monday',
        timeSlot: '10:20 - 11:10 AM',
        periodIndex: 3,
        categoryColorValue: 0xFFFB8C00,
      ),
      const TimetableEntry(
        id: 'ENT-04',
        subjectCode: 'CS304',
        subjectName: 'Software Engineering',
        facultyId: 'FAC-104',
        facultyName: 'Prof. Donald Knuth',
        className: 'CS-3A',
        dayOfWeek: 'Monday',
        timeSlot: '11:30 - 12:20 PM',
        periodIndex: 4,
        categoryColorValue: 0xFF8E24AA,
      ),
      const TimetableEntry(
        id: 'ENT-05',
        subjectCode: 'CS305L',
        subjectName: 'Web Dev Lab',
        facultyId: 'FAC-105',
        facultyName: 'Prof. Tim Berners-Lee',
        className: 'CS-3A',
        dayOfWeek: 'Monday',
        timeSlot: '02:00 - 02:50 PM',
        periodIndex: 5,
        isLab: true,
        categoryColorValue: 0xFF00ACC1,
      ),

      // Wednesday Exam Entry (Spanning Periods 1 & 2)
      TimetableEntry(
        id: 'EXAM-01',
        subjectCode: 'CS302',
        subjectName: 'Operating Systems',
        facultyId: 'FAC-102',
        facultyName: 'Prof. Sarah Jenkins',
        className: 'CS-3A',
        dayOfWeek: 'Wednesday',
        timeSlot: '08:30 AM – 10:20 AM',
        periodIndex: 1,
        periodType: PeriodType.examType,
        examTitle: 'Midterm Examination',
        maxMarks: 100,
        hallNumber: 'Hall 3B',
        seatNumber: 'Desk #24',
        invigilatorName: 'Prof. Sarah Jenkins',
        startPeriodIndex: 1,
        endPeriodIndex: 2,
        duration: '1h 50m',
        examDate: DateTime(2026, 8, 12),
        syllabus: 'Units 1 & 2: Process Management, Threading, Deadlocks & Memory Allocation',
        permittedItems: 'Non-programmable Scientific Calculator, Physical College ID Card',
      ),
      const TimetableEntry(
        id: 'ENT-WED-03',
        subjectCode: 'CS303',
        subjectName: 'Computer Networks',
        facultyId: 'FAC-103',
        facultyName: 'Prof. Grace Hopper',
        className: 'CS-3A',
        dayOfWeek: 'Wednesday',
        timeSlot: '10:20 - 11:10 AM',
        periodIndex: 3,
        categoryColorValue: 0xFFFB8C00,
      ),

      // Friday Exam Entry (Spanning Periods 2 & 3)
      TimetableEntry(
        id: 'EXAM-02',
        subjectCode: 'CS301',
        subjectName: 'Database Systems',
        facultyId: 'FAC-101',
        facultyName: 'Prof. Grace Hopper',
        className: 'CS-3A',
        dayOfWeek: 'Friday',
        timeSlot: '09:30 AM – 11:10 AM',
        periodIndex: 2,
        periodType: PeriodType.examType,
        examTitle: 'Internal Assessment 2',
        maxMarks: 50,
        hallNumber: 'Auditorium 1',
        seatNumber: 'Seat A-18',
        invigilatorName: 'Prof. Grace Hopper',
        startPeriodIndex: 2,
        endPeriodIndex: 3,
        duration: '1h 40m',
        examDate: DateTime(2026, 8, 14),
        syllabus: 'Unit 3: SQL Relational Algebra, Normalization & Indexing B-Trees',
        permittedItems: 'College ID Card, Blue/Black Pen only (No electronic gadgets allowed)',
      ),

      // Term-Wide Exam Entries (for Filtered Exam View)
      TimetableEntry(
        id: 'EXAM-03',
        subjectCode: 'CS305L',
        subjectName: 'Web Dev Lab',
        facultyId: 'FAC-105',
        facultyName: 'Prof. Tim Berners-Lee',
        className: 'CS-3A',
        dayOfWeek: 'Monday',
        timeSlot: '08:30 AM – 10:20 AM',
        periodIndex: 1,
        periodType: PeriodType.examType,
        examTitle: 'End-Sem Practical Evaluation',
        maxMarks: 100,
        hallNumber: 'Lab 4 (CS Block)',
        seatNumber: 'Workstation #12',
        invigilatorName: 'Prof. Tim Berners-Lee',
        startPeriodIndex: 1,
        endPeriodIndex: 2,
        duration: '1h 50m',
        examDate: DateTime(2026, 8, 17),
        syllabus: 'Full Lab Coursework: REST API Integration, Responsive UI & State Management',
        permittedItems: 'Open Documentation & Workspace IDE (No internet communication tools)',
      ),
      TimetableEntry(
        id: 'EXAM-04',
        subjectCode: 'CS303',
        subjectName: 'Computer Networks',
        facultyId: 'FAC-104',
        facultyName: 'Prof. Donald Knuth',
        className: 'CS-3A',
        dayOfWeek: 'Wednesday',
        timeSlot: '10:20 AM – 12:20 PM',
        periodIndex: 3,
        periodType: PeriodType.examType,
        examTitle: 'Midterm Examination',
        maxMarks: 100,
        hallNumber: 'Hall 2A',
        seatNumber: 'Desk #08',
        invigilatorName: 'Prof. Donald Knuth',
        startPeriodIndex: 3,
        endPeriodIndex: 4,
        duration: '2h 00m',
        examDate: DateTime(2026, 8, 19),
        syllabus: 'Units 1 to 3: OSI & TCP/IP Stack, Subnetting, Routing Algorithms',
        permittedItems: 'College ID Card, Basic Calculator allowed',
      ),
    ]);

    // Seed Disruptions & Substitutions
    _disruptions.add(
      DisruptionAlert(
        id: 'DIS-101',
        absentFacultyName: 'Prof. Alan Turing',
        className: 'CS-3A',
        subjectCode: 'CS302',
        subjectName: 'Operating Systems',
        dayOfWeek: 'Monday',
        timeSlot: '09:30 - 10:20 AM',
        periodIndex: 2,
        suggestedSubstitutes: ['Prof. Donald Knuth', 'Prof. Sarah Jenkins', 'Prof. Barbara Liskov'],
      ),
    );

    _substitutions.add(
      FacultySubstitution(
        id: 'SUB-201',
        date: DateTime.now(),
        originalFaculty: 'Prof. Tim Berners-Lee',
        substituteFaculty: 'Prof. Grace Hopper',
        className: 'CS-3A',
        subjectCode: 'CS305L',
        subjectName: 'Web Dev Lab',
        timeSlot: '02:00 - 02:50 PM',
        dayOfWeek: 'Monday',
        reason: 'Personal Leave',
        status: 'Approved',
        triggerType: SubstitutionTriggerType.allocatorAbsence,
        note: 'Covering Lab Practical 4',
      ),
    );

    // Initial Audit Log Entry
    _auditLogs.add(
      AuditLogEntry(
        id: 'AUD-INIT',
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        actionType: 'SYSTEM_INITIALIZED',
        performedBy: 'Dr. Marcus Vance',
        details: 'Master Timetable v1.0 active for CS-3A',
        affectedClass: 'CS-3A',
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _dispatchNotification({
    required String title,
    required String body,
    required NotificationType type,
    required String recipientUser,
    String? deepLinkRoute,
  }) {
    final notification = AppNotification(
      id: 'NOTIF-${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      body: body,
      type: type,
      recipientUser: recipientUser,
      timestamp: DateTime.now(),
      deepLinkRoute: deepLinkRoute,
    );
    _notifications.insert(0, notification);
    _notificationsController.add(List.unmodifiable(_notifications));
  }

  // ---------------------------------------------------------------------------
  // Standard Repository Methods
  // ---------------------------------------------------------------------------
  @override
  TimetableConfig getConfig() => _config;

  @override
  void updateConfig(TimetableConfig config) {
    _config = config;
  }

  @override
  List<String> getAvailableClasses() => List.unmodifiable(_availableClasses);

  @override
  List<FacultyMember> getFacultyList() => List.unmodifiable(_facultyList);

  @override
  List<TimetableVersion> getVersions() => List.unmodifiable(_versions);

  @override
  TimetableVersion? getActiveVersion(String className) {
    try {
      return _versions.firstWhere(
        (v) => v.className == className && v.status == TimetableStatus.published,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  List<TimetableEntry> getEntriesForClass(String className) {
    return _entries.where((e) => e.className.toLowerCase() == className.toLowerCase()).toList();
  }

  @override
  List<TimetableEntry> getEntriesForFaculty(String facultyName) {
    return _entries.where((e) => e.facultyName.toLowerCase() == facultyName.toLowerCase()).toList();
  }

  @override
  void addEntry(TimetableEntry entry) {
    _entries.add(entry);
  }

  @override
  void updateEntry(TimetableEntry entry) {
    final index = _entries.indexWhere((e) => e.id == entry.id);
    if (index != -1) {
      _entries[index] = entry;
    }
  }

  @override
  void deleteEntry(String entryId) {
    _entries.removeWhere((e) => e.id == entryId);
  }

  @override
  List<ConflictItem> getConflicts() => List.unmodifiable(_conflicts);

  @override
  List<ConflictItem> runConflictDetection(List<TimetableEntry> entries) {
    final detected = <ConflictItem>[];
    for (int i = 0; i < entries.length; i++) {
      for (int j = i + 1; j < entries.length; j++) {
        final a = entries[i];
        final b = entries[j];
        if (a.dayOfWeek == b.dayOfWeek && a.periodIndex == b.periodIndex) {
          if (a.facultyId == b.facultyId) {
            detected.add(
              ConflictItem(
                id: 'CONF-${a.id}-${b.id}',
                type: ConflictType.facultyConflict,
                title: 'Faculty Double-Booking',
                description: '${a.facultyName} is assigned to ${a.className} and ${b.className} simultaneously.',
                affectedEntryIds: [a.id, b.id],
              ),
            );
          }
        }
      }
    }
    _conflicts.clear();
    _conflicts.addAll(detected);
    return List.unmodifiable(_conflicts);
  }

  @override
  void resolveConflict(String conflictId) {
    final index = _conflicts.indexWhere((c) => c.id == conflictId);
    if (index != -1) {
      _conflicts[index].isResolved = true;
    }
  }

  @override
  TimetableVersion publishTimetable(String versionId) {
    final index = _versions.indexWhere((v) => v.id == versionId);
    if (index != -1) {
      final old = _versions[index];
      final updated = TimetableVersion(
        id: old.id,
        versionNumber: old.versionNumber,
        title: old.title,
        createdAt: old.createdAt,
        publishedAt: DateTime.now(),
        status: TimetableStatus.published,
        entries: old.entries,
        className: old.className,
      );
      _versions[index] = updated;
      return updated;
    }
    throw Exception('Version not found');
  }

  @override
  TimetableVersion saveNewVersion(String title, List<TimetableEntry> entries) {
    final version = TimetableVersion(
      id: 'VER-${DateTime.now().millisecondsSinceEpoch}',
      versionNumber: _versions.length + 1,
      title: title,
      createdAt: DateTime.now(),
      status: TimetableStatus.draft,
      entries: entries,
      className: _config.batchSection,
    );
    _versions.add(version);
    return version;
  }

  // ---------------------------------------------------------------------------
  // Disruption Alerts & Substitutions Engine with Real-Time Streams
  // ---------------------------------------------------------------------------
  @override
  List<DisruptionAlert> getDisruptionAlerts() => List.unmodifiable(_disruptions);

  @override
  void resolveDisruptionAlert(String alertId, String chosenSubstitute) {
    final index = _disruptions.indexWhere((d) => d.id == alertId);
    if (index != -1) {
      final alert = _disruptions[index];
      alert.isResolved = true;
      _disruptionsController.add(List.unmodifiable(_disruptions));

      final newSub = FacultySubstitution(
        id: 'SUB-${DateTime.now().millisecondsSinceEpoch}',
        date: DateTime.now(),
        originalFaculty: alert.absentFacultyName,
        substituteFaculty: chosenSubstitute,
        className: alert.className,
        subjectCode: alert.subjectCode,
        subjectName: alert.subjectName,
        timeSlot: alert.timeSlot,
        dayOfWeek: alert.dayOfWeek,
        reason: 'Disruption resolution (Faculty Leave)',
        status: 'Approved',
        triggerType: SubstitutionTriggerType.allocatorAbsence,
      );
      _substitutions.insert(0, newSub);
      _substitutionsController.add(List.unmodifiable(_substitutions));

      _auditLogs.insert(
        0,
        AuditLogEntry(
          id: 'AUD-${DateTime.now().millisecondsSinceEpoch}',
          timestamp: DateTime.now(),
          actionType: 'DISRUPTION_RESOLVED',
          performedBy: 'Dr. Marcus Vance',
          details: 'Assigned $chosenSubstitute for ${alert.className} (${alert.subjectCode})',
          affectedClass: alert.className,
          affectedFaculty: chosenSubstitute,
        ),
      );
      _auditLogsController.add(List.unmodifiable(_auditLogs));
    }
  }

  @override
  List<FacultySubstitution> getSubstitutions() => List.unmodifiable(_substitutions);

  @override
  void requestSubstitution(FacultySubstitution sub) {
    _substitutions.insert(0, sub);
    _substitutionsController.add(List.unmodifiable(_substitutions));

    _auditLogs.insert(
      0,
      AuditLogEntry(
        id: 'AUD-${DateTime.now().millisecondsSinceEpoch}',
        timestamp: DateTime.now(),
        actionType: 'SUBSTITUTION_REQUESTED',
        performedBy: sub.originalFaculty,
        details: '${sub.triggerType.label}: Request for ${sub.className} (${sub.subjectCode}) assigned to ${sub.substituteFaculty}',
        affectedClass: sub.className,
        affectedFaculty: sub.substituteFaculty,
      ),
    );
    _auditLogsController.add(List.unmodifiable(_auditLogs));

    if (sub.isPoolBroadcast) {
      _dispatchNotification(
        title: 'Department Pool Broadcast Invite',
        body: '${sub.originalFaculty} requested coverage for ${sub.className} (${sub.subjectCode}) at ${sub.timeSlot}.',
        type: NotificationType.peerInvite,
        recipientUser: 'POOL_BROADCAST_${sub.className}',
        deepLinkRoute: '/substitutions?tab=invites',
      );
    } else {
      _dispatchNotification(
        title: 'Peer Substitution Request',
        body: '${sub.originalFaculty} requested you for coverage in ${sub.className} (${sub.subjectCode}).',
        type: NotificationType.peerInvite,
        recipientUser: sub.substituteFaculty,
        deepLinkRoute: '/substitutions?tab=invites',
      );
    }
  }

  @override
  void approveSubstitution(String subId) {
    final index = _substitutions.indexWhere((s) => s.id == subId);
    if (index != -1) {
      final sub = _substitutions[index];
      sub.status = 'Approved';
      _substitutionsController.add(List.unmodifiable(_substitutions));

      _auditLogs.insert(
        0,
        AuditLogEntry(
          id: 'AUD-${DateTime.now().millisecondsSinceEpoch}',
          timestamp: DateTime.now(),
          actionType: 'SUBSTITUTION_APPROVED',
          performedBy: sub.substituteFaculty,
          details: 'Proxy confirmed for ${sub.className} (${sub.subjectCode}) on ${sub.dayOfWeek}',
          affectedClass: sub.className,
          affectedFaculty: sub.originalFaculty,
        ),
      );
      _auditLogsController.add(List.unmodifiable(_auditLogs));

      _dispatchNotification(
        title: 'Substitution Request Approved',
        body: '${sub.substituteFaculty} accepted proxy duty for ${sub.className} (${sub.subjectCode}).',
        type: NotificationType.allocatorApproval,
        recipientUser: sub.originalFaculty,
        deepLinkRoute: '/substitutions?tab=my_requests',
      );

      _dispatchNotification(
        title: 'Class Schedule Update',
        body: 'Substitute teacher ${sub.substituteFaculty} is assigned for ${sub.className} (${sub.subjectCode}) today.',
        type: NotificationType.studentClassUpdate,
        recipientUser: 'STUDENTS_${sub.className}',
        deepLinkRoute: '/student_dashboard',
      );
    }
  }

  @override
  void rejectSubstitution(String subId) {
    final index = _substitutions.indexWhere((s) => s.id == subId);
    if (index != -1) {
      final sub = _substitutions[index];
      sub.status = 'Rejected';
      _substitutionsController.add(List.unmodifiable(_substitutions));

      _auditLogs.insert(
        0,
        AuditLogEntry(
          id: 'AUD-${DateTime.now().millisecondsSinceEpoch}',
          timestamp: DateTime.now(),
          actionType: 'SUBSTITUTION_REJECTED',
          performedBy: sub.substituteFaculty,
          details: 'Declined proxy for ${sub.className} (${sub.subjectCode})',
          affectedClass: sub.className,
          affectedFaculty: sub.originalFaculty,
        ),
      );
      _auditLogsController.add(List.unmodifiable(_auditLogs));
    }
  }

  @override
  void cancelSubstitution(String subId) {
    final index = _substitutions.indexWhere((s) => s.id == subId);
    if (index != -1) {
      final sub = _substitutions[index];
      sub.status = 'Cancelled';
      _substitutionsController.add(List.unmodifiable(_substitutions));

      _auditLogs.insert(
        0,
        AuditLogEntry(
          id: 'AUD-${DateTime.now().millisecondsSinceEpoch}',
          timestamp: DateTime.now(),
          actionType: 'SUBSTITUTION_CANCELLED',
          performedBy: sub.originalFaculty,
          details: 'Retracted request for ${sub.className} (${sub.subjectCode})',
          affectedClass: sub.className,
        ),
      );
      _auditLogsController.add(List.unmodifiable(_auditLogs));
    }
  }

  @override
  List<TimetableEntry> generateAiCandidate(TimetableConfig config) {
    final days = config.workingDays;
    final subjects = [
      ('CS301', 'Database Systems', 'Prof. Sarah Jenkins', 0xFF1E88E5, false),
      ('CS302', 'Operating Systems', 'Prof. Alan Turing', 0xFF43A047, false),
      ('CS303', 'Computer Networks', 'Prof. Grace Hopper', 0xFFFB8C00, false),
      ('CS304', 'Software Engineering', 'Prof. Donald Knuth', 0xFF8E24AA, false),
      ('CS306', 'AI & Machine Learning', 'Dr. Marcus Vance', 0xFFD81B60, false),
      ('CS305L', 'Web Dev Lab', 'Prof. Tim Berners-Lee', 0xFF00ACC1, true),
      ('CS308', 'Cloud Computing Elective', 'Prof. Barbara Liskov', 0xFF3949AB, false),
    ];

    final slots = [
      '08:30 - 09:20 AM',
      '09:30 - 10:20 AM',
      '10:20 - 11:10 AM',
      '11:30 - 12:20 PM',
      '02:00 - 02:50 PM',
      '02:50 - 03:40 PM',
    ];

    final candidate = <TimetableEntry>[];
    int counter = 1;

    for (final day in days) {
      for (int i = 0; i < slots.length && i < config.periodsPerDay; i++) {
        final subIndex = (counter + i) % subjects.length;
        final sub = subjects[subIndex];

        candidate.add(
          TimetableEntry(
            id: 'AI-ENT-${counter++}',
            subjectCode: sub.$1,
            subjectName: sub.$2,
            facultyId: 'FAC-$subIndex',
            facultyName: sub.$3,
            className: config.batchSection,
            dayOfWeek: day,
            timeSlot: slots[i],
            periodIndex: i + 1,
            isLab: sub.$5,
            categoryColorValue: sub.$4,
          ),
        );
      }
    }
    return candidate;
  }

  @override
  List<FacultySubjectQuota> getFacultyQuotas() => List.unmodifiable(_quotas);

  @override
  void addFacultyQuota(FacultySubjectQuota quota) {
    _quotas.add(quota);
  }

  @override
  void updateFacultyQuota(FacultySubjectQuota quota) {
    final index = _quotas.indexWhere((q) => q.id == quota.id);
    if (index != -1) {
      _quotas[index] = quota;
    }
  }

  @override
  void deleteFacultyQuota(String id) {
    _quotas.removeWhere((q) => q.id == id);
  }

  @override
  void importFacultyQuotas(List<FacultySubjectQuota> quotas) {
    _quotas.addAll(quotas);
  }

  // ---------------------------------------------------------------------------
  // 1. ATTENDANCE ENGINE SERVICE & DYNAMIC PROXY AUTHORIZATION
  // ---------------------------------------------------------------------------
  @override
  bool canFacultyMarkAttendance(String facultyName, String className, String timeSlot, DateTime date) {
    final dayStr = DateFormat('EEEE').format(date).toLowerCase();
    final entryExists = _entries.any(
      (e) => e.facultyName.toLowerCase() == facultyName.toLowerCase() &&
             e.className.toLowerCase() == className.toLowerCase() &&
             e.dayOfWeek.toLowerCase() == dayStr &&
             e.timeSlot == timeSlot,
    );
    if (entryExists) return true;

    final proxyApproved = _substitutions.any(
      (s) => s.substituteFaculty.toLowerCase() == facultyName.toLowerCase() &&
             s.className.toLowerCase() == className.toLowerCase() &&
             s.timeSlot == timeSlot &&
             s.status == 'Approved',
    );
    return proxyApproved;
  }

  @override
  void markPeriodAttendance(PeriodAttendanceRecord record) {
    final index = _attendanceRecords.indexWhere(
      (r) => r.className == record.className && r.periodIndex == record.periodIndex && _isSameDay(r.date, record.date),
    );
    if (index != -1) {
      _attendanceRecords[index] = record;
    } else {
      _attendanceRecords.add(record);
    }
    _attendanceController.add(List.unmodifiable(_attendanceRecords));

    _auditLogs.insert(
      0,
      AuditLogEntry(
        id: 'AUD-${DateTime.now().millisecondsSinceEpoch}',
        timestamp: DateTime.now(),
        actionType: 'ATTENDANCE_MARKED',
        performedBy: record.markedByFaculty,
        details: 'Attendance marked as ${record.status.label} for ${record.className} Period ${record.periodIndex}',
        affectedClass: record.className,
      ),
    );
    _auditLogsController.add(List.unmodifiable(_auditLogs));
  }

  @override
  List<PeriodAttendanceRecord> getAttendanceRecords(String className, DateTime date) {
    return _attendanceRecords
        .where((r) => r.className.toLowerCase() == className.toLowerCase() && _isSameDay(r.date, date))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // 2. LEAVE & ON-DUTY (OD) MANAGEMENT PIPELINE
  // ---------------------------------------------------------------------------
  @override
  void approveFacultyLeave(FacultyLeaveRequest leave) {
    leave.status = 'Approved';
    _leaveRequests.add(leave);

    final dayStr = DateFormat('EEEE').format(leave.startDate);
    final affectedEntries = _entries.where(
      (e) => e.facultyName.toLowerCase() == leave.facultyName.toLowerCase() &&
             e.dayOfWeek.toLowerCase() == dayStr.toLowerCase(),
    );

    for (final entry in affectedEntries) {
      final alertId = 'DIS-LVE-${DateTime.now().millisecondsSinceEpoch}-${entry.periodIndex}';
      final alert = DisruptionAlert(
        id: alertId,
        absentFacultyName: leave.facultyName,
        className: entry.className,
        subjectCode: entry.subjectCode,
        subjectName: entry.subjectName,
        dayOfWeek: entry.dayOfWeek,
        timeSlot: entry.timeSlot,
        periodIndex: entry.periodIndex,
        suggestedSubstitutes: ['Prof. Donald Knuth', 'Prof. Sarah Jenkins', 'Prof. Grace Hopper'],
      );
      _disruptions.add(alert);
    }
    _disruptionsController.add(List.unmodifiable(_disruptions));

    _dispatchNotification(
      title: 'Faculty Disruption Alert',
      body: '${leave.facultyName} leave approved. Disruption slots generated for Allocator resolution.',
      type: NotificationType.leaveDisruption,
      recipientUser: 'ALLOCATOR',
      deepLinkRoute: '/allocator_dashboard?tab=disruptions',
    );
  }

  @override
  List<FacultyLeaveRequest> getFacultyLeaveRequests() => List.unmodifiable(_leaveRequests);

  @override
  void approveStudentOd(StudentOdRequest od) {
    od.status = 'Approved';
    _odRequests.add(od);

    for (final periodIndex in od.periodIndexes) {
      markPeriodAttendance(
        PeriodAttendanceRecord(
          id: 'ATT-OD-${od.id}-$periodIndex',
          date: od.date,
          className: od.className,
          subjectCode: 'OD-OVERRIDE',
          subjectName: 'On-Duty Leave Approved',
          periodIndex: periodIndex,
          timeSlot: 'Period $periodIndex',
          status: PeriodAttendanceStatus.onDuty,
          markedByFaculty: 'SYSTEM_OD_SERVICE',
          timestamp: DateTime.now(),
        ),
      );
    }
  }

  @override
  List<StudentOdRequest> getStudentOdRequests(String className, DateTime date) {
    return _odRequests
        .where((r) => r.className.toLowerCase() == className.toLowerCase() && _isSameDay(r.date, date))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // 3. NOTIFICATION & COMMUNICATION ENGINE
  // ---------------------------------------------------------------------------
  @override
  List<AppNotification> getNotificationsForUser(String userIdentifier) {
    return _notifications.where((n) {
      final target = n.recipientUser.toLowerCase();
      final query = userIdentifier.toLowerCase();
      return target == query || target == 'all' || target.startsWith('students_') || target.startsWith('pool_broadcast_');
    }).toList();
  }

  @override
  void markNotificationRead(String notificationId) {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      _notifications[index].isRead = true;
      _notificationsController.add(List.unmodifiable(_notifications));
    }
  }

  // ---------------------------------------------------------------------------
  // 4. INFRASTRUCTURE & TECHNICAL ESSENTIALS
  // ---------------------------------------------------------------------------
  @override
  DateTime getServerTime() => DateTime.now();

  @override
  List<AuditLogEntry> getAuditLogs() => List.unmodifiable(_auditLogs);

  @override
  Future<bool> executeOptimisticAction(Future<void> Function() action, void Function() rollback) async {
    try {
      await action();
      return true;
    } catch (_) {
      rollback();
      return false;
    }
  }
}
