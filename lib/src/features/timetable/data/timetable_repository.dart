import 'dart:async';
import 'timetable_models.dart';

abstract interface class TimetableRepository {
  // Config & Master Matrix
  TimetableConfig getConfig();
  void updateConfig(TimetableConfig config);

  List<String> getAvailableClasses();
  List<FacultyMember> getFacultyList();
  List<FacultySubjectQuota> getFacultyQuotas();
  void addFacultyQuota(FacultySubjectQuota quota);
  void updateFacultyQuota(FacultySubjectQuota quota);
  void deleteFacultyQuota(String id);
  void importFacultyQuotas(List<FacultySubjectQuota> quotas);

  List<TimetableVersion> getVersions();
  TimetableVersion? getActiveVersion(String className);

  List<TimetableEntry> getEntriesForClass(String className);
  List<TimetableEntry> getEntriesForFaculty(
    String facultyName, {
    String? facultyId,
  });

  void addEntry(TimetableEntry entry);
  void updateEntry(TimetableEntry entry);
  void deleteEntry(String entryId);
  void replaceClassSchedule(String className, List<TimetableEntry> entries);

  List<ConflictItem> getConflicts();
  List<ConflictItem> runConflictDetection(List<TimetableEntry> entries);
  void resolveConflict(String conflictId);

  TimetableVersion publishTimetable(String versionId);
  TimetableVersion saveNewVersion(String title, List<TimetableEntry> entries);

  // Disruption Alerts & Substitutions Engine
  List<DisruptionAlert> getDisruptionAlerts();
  void resolveDisruptionAlert(String alertId, String chosenSubstitute);

  List<FacultySubstitution> getSubstitutions();
  void requestSubstitution(FacultySubstitution sub);
  void approveSubstitution(String subId);
  void rejectSubstitution(String subId);
  void cancelSubstitution(String subId);

  List<TimetableEntry> generateAiCandidate(TimetableConfig config);

  // ---------------------------------------------------------------------------
  // 1. ATTENDANCE ENGINE SERVICE & DYNAMIC PROXY AUTHORIZATION
  // ---------------------------------------------------------------------------
  bool canFacultyMarkAttendance(
    String facultyName,
    String className,
    String timeSlot,
    DateTime date,
  );
  void markPeriodAttendance(PeriodAttendanceRecord record);
  List<PeriodAttendanceRecord> getAttendanceRecords(
    String className,
    DateTime date,
  );

  // ---------------------------------------------------------------------------
  // 2. LEAVE & ON-DUTY (OD) MANAGEMENT PIPELINE
  // ---------------------------------------------------------------------------
  void approveFacultyLeave(FacultyLeaveRequest leave);
  List<FacultyLeaveRequest> getFacultyLeaveRequests();
  void approveStudentOd(StudentOdRequest od);
  List<StudentOdRequest> getStudentOdRequests(String className, DateTime date);

  // ---------------------------------------------------------------------------
  // 3. NOTIFICATION & COMMUNICATION ENGINE
  // ---------------------------------------------------------------------------
  List<AppNotification> getNotificationsForUser(String userIdentifier);
  void markNotificationRead(String notificationId);

  // ---------------------------------------------------------------------------
  // 4. REAL-TIME DATA SYNCHRONIZATION STREAMS (WebSocket / SSE Simulation)
  // ---------------------------------------------------------------------------
  Stream<List<FacultySubstitution>> get substitutionsStream;
  Stream<List<DisruptionAlert>> get disruptionsStream;
  Stream<List<PeriodAttendanceRecord>> get attendanceStream;
  Stream<List<AppNotification>> get notificationsStream;
  Stream<List<AuditLogEntry>> get auditLogsStream;

  // ---------------------------------------------------------------------------
  // 5. INFRASTRUCTURE & TECHNICAL ESSENTIALS
  // ---------------------------------------------------------------------------
  DateTime getServerTime();
  List<AuditLogEntry> getAuditLogs();
  Future<bool> executeOptimisticAction(
    Future<void> Function() action,
    void Function() rollback,
  );
}
