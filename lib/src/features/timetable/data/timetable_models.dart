import 'package:flutter/material.dart';

enum TimetableStatus {
  draft,
  generated,
  validated,
  underReview,
  approved,
  published,
  archived,
}

extension TimetableStatusExtension on TimetableStatus {
  String get label => switch (this) {
        TimetableStatus.draft => 'Draft',
        TimetableStatus.generated => 'Generated',
        TimetableStatus.validated => 'Validated',
        TimetableStatus.underReview => 'Under Review',
        TimetableStatus.approved => 'Approved',
        TimetableStatus.published => 'Published',
        TimetableStatus.archived => 'Archived',
      };

  Color get color => switch (this) {
        TimetableStatus.draft => Colors.grey.shade700,
        TimetableStatus.generated => Colors.blue.shade700,
        TimetableStatus.validated => Colors.amber.shade800,
        TimetableStatus.underReview => Colors.purple.shade700,
        TimetableStatus.approved => Colors.teal.shade700,
        TimetableStatus.published => const Color(0xFF2E7D32),
        TimetableStatus.archived => Colors.brown.shade600,
      };
}

class AcademicContext {
  const AcademicContext({
    required this.academicYear,
    required this.semester,
    required this.department,
    required this.programme,
    required this.batchSection,
  });

  final String academicYear;
  final String semester;
  final String department;
  final String programme;
  final String batchSection;
}

class TimetableConfig {
  const TimetableConfig({
    required this.academicYear,
    required this.semester,
    required this.batchSection,
    required this.workingDays,
    required this.collegeStartTime,
    required this.collegeEndTime,
    required this.periodsPerDay,
    required this.periodDurationMinutes,
    required this.breakSlots,
    this.teaBreakDurationMinutes = 15,
    this.teaBreakPosition = 2,
    this.lunchBreakDurationMinutes = 45,
    this.lunchBreakPosition = 4,
    this.workingDaysOption = 'Mon-Fri',
  });

  final String academicYear;
  final String semester;
  final String batchSection;
  final List<String> workingDays;
  final String collegeStartTime;
  final String collegeEndTime;
  final int periodsPerDay;
  final int periodDurationMinutes;
  final List<String> breakSlots;
  final int teaBreakDurationMinutes;
  final int teaBreakPosition;
  final int lunchBreakDurationMinutes;
  final int lunchBreakPosition;
  final String workingDaysOption;

  TimetableConfig copyWith({
    String? academicYear,
    String? semester,
    String? batchSection,
    List<String>? workingDays,
    String? collegeStartTime,
    String? collegeEndTime,
    int? periodsPerDay,
    int? periodDurationMinutes,
    List<String>? breakSlots,
    int? teaBreakDurationMinutes,
    int? teaBreakPosition,
    int? lunchBreakDurationMinutes,
    int? lunchBreakPosition,
    String? workingDaysOption,
  }) {
    return TimetableConfig(
      academicYear: academicYear ?? this.academicYear,
      semester: semester ?? this.semester,
      batchSection: batchSection ?? this.batchSection,
      workingDays: workingDays ?? this.workingDays,
      collegeStartTime: collegeStartTime ?? this.collegeStartTime,
      collegeEndTime: collegeEndTime ?? this.collegeEndTime,
      periodsPerDay: periodsPerDay ?? this.periodsPerDay,
      periodDurationMinutes: periodDurationMinutes ?? this.periodDurationMinutes,
      breakSlots: breakSlots ?? this.breakSlots,
      teaBreakDurationMinutes:
          teaBreakDurationMinutes ?? this.teaBreakDurationMinutes,
      teaBreakPosition: teaBreakPosition ?? this.teaBreakPosition,
      lunchBreakDurationMinutes:
          lunchBreakDurationMinutes ?? this.lunchBreakDurationMinutes,
      lunchBreakPosition: lunchBreakPosition ?? this.lunchBreakPosition,
      workingDaysOption: workingDaysOption ?? this.workingDaysOption,
    );
  }
}

enum PeriodType {
  classType,
  examType,
}

extension PeriodTypeExtension on PeriodType {
  String get label => switch (this) {
        PeriodType.classType => 'CLASS',
        PeriodType.examType => 'EXAM',
      };
}

/// TimetableEntry represents a specific scheduled period for a class or an exam.
/// NOTE: Room field is intentionally removed across all models per specifications.
class TimetableEntry {
  const TimetableEntry({
    required this.id,
    required this.subjectCode,
    required this.subjectName,
    required this.facultyId,
    required this.facultyName,
    required this.className,
    required this.dayOfWeek,
    required this.timeSlot,
    required this.periodIndex,
    this.isLab = false,
    this.categoryColorValue = 0xFF1976D2,
    this.periodType = PeriodType.classType,
    this.examTitle,
    this.maxMarks,
    this.hallNumber,
    this.seatNumber,
    this.invigilatorName,
    this.startPeriodIndex,
    this.endPeriodIndex,
    this.examDate,
    this.duration,
    this.syllabus,
    this.permittedItems,
  });

  final String id;
  final String subjectCode;
  final String subjectName;
  final String facultyId;
  final String facultyName;
  final String className; // e.g. "CS-3A"
  final String dayOfWeek; // e.g. "Monday"
  final String timeSlot; // e.g. "08:30 - 09:20"
  final int periodIndex; // 1-indexed
  final bool isLab;
  final int categoryColorValue;

  // EXAM Specific Fields
  final PeriodType periodType;
  final String? examTitle; // e.g. "Midterm Exam"
  final int? maxMarks; // e.g. 50, 100
  final String? hallNumber; // e.g. "Hall 3B"
  final String? seatNumber; // e.g. "Desk #24"
  final String? invigilatorName; // e.g. "Prof. Sarah Jenkins"
  final int? startPeriodIndex; // e.g. 1
  final int? endPeriodIndex; // e.g. 2
  final DateTime? examDate;
  final String? duration; // e.g. "1h 40m"
  final String? syllabus; // e.g. "Units 1 & 2"
  final String? permittedItems; // e.g. "Non-programmable calculator"

  bool get isExam => periodType == PeriodType.examType;

  Color get categoryColor => isExam ? const Color(0xFFC62828) : Color(categoryColorValue);

  TimetableEntry copyWith({
    String? id,
    String? subjectCode,
    String? subjectName,
    String? facultyId,
    String? facultyName,
    String? className,
    String? dayOfWeek,
    String? timeSlot,
    int? periodIndex,
    bool? isLab,
    int? categoryColorValue,
    PeriodType? periodType,
    String? examTitle,
    int? maxMarks,
    String? hallNumber,
    String? seatNumber,
    String? invigilatorName,
    int? startPeriodIndex,
    int? endPeriodIndex,
    DateTime? examDate,
    String? duration,
    String? syllabus,
    String? permittedItems,
  }) {
    return TimetableEntry(
      id: id ?? this.id,
      subjectCode: subjectCode ?? this.subjectCode,
      subjectName: subjectName ?? this.subjectName,
      facultyId: facultyId ?? this.facultyId,
      facultyName: facultyName ?? this.facultyName,
      className: className ?? this.className,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      timeSlot: timeSlot ?? this.timeSlot,
      periodIndex: periodIndex ?? this.periodIndex,
      isLab: isLab ?? this.isLab,
      categoryColorValue: categoryColorValue ?? this.categoryColorValue,
      periodType: periodType ?? this.periodType,
      examTitle: examTitle ?? this.examTitle,
      maxMarks: maxMarks ?? this.maxMarks,
      hallNumber: hallNumber ?? this.hallNumber,
      seatNumber: seatNumber ?? this.seatNumber,
      invigilatorName: invigilatorName ?? this.invigilatorName,
      startPeriodIndex: startPeriodIndex ?? this.startPeriodIndex,
      endPeriodIndex: endPeriodIndex ?? this.endPeriodIndex,
      examDate: examDate ?? this.examDate,
      duration: duration ?? this.duration,
      syllabus: syllabus ?? this.syllabus,
      permittedItems: permittedItems ?? this.permittedItems,
    );
  }
}

enum ConflictType {
  facultyConflict,
  classConflict,
  timeOverlap,
  workloadExceeded,
  weeklyHoursMismatch,
}

extension ConflictTypeExtension on ConflictType {
  String get label => switch (this) {
        ConflictType.facultyConflict => 'Faculty Double-Booking',
        ConflictType.classConflict => 'Class Schedule Overlap',
        ConflictType.timeOverlap => 'Time Slot Contention',
        ConflictType.workloadExceeded => 'Faculty Workload Exceeded',
        ConflictType.weeklyHoursMismatch => 'Weekly Subject Hours Deficit',
      };
}

class ConflictItem {
  ConflictItem({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.affectedEntryIds,
    this.isResolved = false,
    this.severity = 'High',
  });

  final String id;
  final ConflictType type;
  final String title;
  final String description;
  final List<String> affectedEntryIds;
  bool isResolved;
  final String severity;
}

enum SubstitutionTriggerType {
  allocatorAbsence,
  facultyInitiated,
}

extension SubstitutionTriggerTypeExtension on SubstitutionTriggerType {
  String get label => switch (this) {
        SubstitutionTriggerType.allocatorAbsence => 'ALLOCATOR_ABSENCE',
        SubstitutionTriggerType.facultyInitiated => 'FACULTY_INITIATED',
      };
}

class FacultySubstitution {
  FacultySubstitution({
    required this.id,
    required this.date,
    required this.originalFaculty,
    required this.substituteFaculty,
    required this.className,
    required this.subjectCode,
    required this.subjectName,
    required this.timeSlot,
    required this.dayOfWeek,
    required this.reason,
    this.status = 'Pending',
    this.triggerType = SubstitutionTriggerType.facultyInitiated,
    this.isPoolBroadcast = false,
    this.note = '',
  });

  final String id;
  final DateTime date;
  final String originalFaculty;
  final String substituteFaculty;
  final String className;
  final String subjectCode;
  final String subjectName;
  final String timeSlot;
  final String dayOfWeek;
  final String reason;
  String status;
  final SubstitutionTriggerType triggerType;
  final bool isPoolBroadcast;
  final String note;
}

class TimetableVersion {
  const TimetableVersion({
    required this.id,
    required this.versionNumber,
    required this.title,
    required this.createdAt,
    this.publishedAt,
    required this.status,
    required this.entries,
    required this.className,
  });

  final String id;
  final int versionNumber;
  final String title;
  final DateTime createdAt;
  final DateTime? publishedAt;
  final TimetableStatus status;
  final List<TimetableEntry> entries;
  final String className;
}

class FacultyMember {
  const FacultyMember({
    required this.id,
    required this.name,
    required this.department,
    required this.subjectsHandled,
    this.isAvailable = true,
    this.onLeave = false,
    this.leaveReason,
  });

  final String id;
  final String name;
  final String department;
  final List<String> subjectsHandled;
  final bool isAvailable;
  final bool onLeave;
  final String? leaveReason;
}

class DisruptionAlert {
  DisruptionAlert({
    required this.id,
    required this.absentFacultyName,
    required this.className,
    required this.subjectCode,
    required this.subjectName,
    required this.dayOfWeek,
    required this.timeSlot,
    required this.periodIndex,
    required this.suggestedSubstitutes,
    this.isResolved = false,
  });

  final String id;
  final String absentFacultyName;
  final String className;
  final String subjectCode;
  final String subjectName;
  final String dayOfWeek;
  final String timeSlot;
  final int periodIndex;
  final List<String> suggestedSubstitutes;
  bool isResolved;
}

class FacultySubjectQuota {
  const FacultySubjectQuota({
    required this.id,
    required this.facultyName,
    required this.department,
    required this.subjectCode,
    required this.subjectName,
    required this.minWeeklyPeriods,
    this.isLab = false,
  });

  final String id;
  final String facultyName;
  final String department;
  final String subjectCode;
  final String subjectName;
  final int minWeeklyPeriods;
  final bool isLab;
}

/// ---------------------------------------------------------------------------
/// ATTENDANCE ENGINE & REAL-TIME LOG MODELS
/// ---------------------------------------------------------------------------
enum PeriodAttendanceStatus {
  present,
  absent,
  onDuty,
  upcoming,
  cancelled,
}

extension PeriodAttendanceStatusExtension on PeriodAttendanceStatus {
  String get label => switch (this) {
        PeriodAttendanceStatus.present => 'PRESENT',
        PeriodAttendanceStatus.absent => 'ABSENT',
        PeriodAttendanceStatus.onDuty => 'ON_DUTY',
        PeriodAttendanceStatus.upcoming => 'UPCOMING',
        PeriodAttendanceStatus.cancelled => 'CANCELLED',
      };

  Color get color => switch (this) {
        PeriodAttendanceStatus.present => const Color(0xFF2E7D32),
        PeriodAttendanceStatus.absent => const Color(0xFFC62828),
        PeriodAttendanceStatus.onDuty => const Color(0xFF6A1B9A),
        PeriodAttendanceStatus.upcoming => const Color(0xFF1565C0),
        PeriodAttendanceStatus.cancelled => Colors.grey.shade600,
      };
}

class PeriodAttendanceRecord {
  PeriodAttendanceRecord({
    required this.id,
    required this.date,
    required this.className,
    required this.subjectCode,
    required this.subjectName,
    required this.periodIndex,
    required this.timeSlot,
    required this.status,
    required this.markedByFaculty,
    this.proxyFaculty,
    required this.timestamp,
  });

  final String id;
  final DateTime date;
  final String className;
  final String subjectCode;
  final String subjectName;
  final int periodIndex;
  final String timeSlot;
  PeriodAttendanceStatus status;
  final String markedByFaculty;
  final String? proxyFaculty;
  final DateTime timestamp;
}

/// ---------------------------------------------------------------------------
/// LEAVE & ON-DUTY (OD) MANAGEMENT MODELS
/// ---------------------------------------------------------------------------
class FacultyLeaveRequest {
  FacultyLeaveRequest({
    required this.id,
    required this.facultyId,
    required this.facultyName,
    required this.department,
    required this.startDate,
    required this.endDate,
    required this.reason,
    this.status = 'Pending',
    required this.createdAt,
  });

  final String id;
  final String facultyId;
  final String facultyName;
  final String department;
  final DateTime startDate;
  final DateTime endDate;
  final String reason;
  String status;
  final DateTime createdAt;
}

class StudentOdRequest {
  StudentOdRequest({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.className,
    required this.date,
    required this.periodIndexes,
    required this.reason,
    this.status = 'Pending',
    required this.createdAt,
  });

  final String id;
  final String studentId;
  final String studentName;
  final String className;
  final DateTime date;
  final List<int> periodIndexes;
  final String reason;
  String status;
  final DateTime createdAt;
}

/// ---------------------------------------------------------------------------
/// NOTIFICATION & COMMUNICATION ENGINE MODELS
/// ---------------------------------------------------------------------------
enum NotificationType {
  peerInvite,
  allocatorApproval,
  studentClassUpdate,
  leaveDisruption,
}

class AppNotification {
  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.recipientUser,
    required this.timestamp,
    this.isRead = false,
    this.deepLinkRoute,
    this.metadata,
  });

  final String id;
  final String title;
  final String body;
  final NotificationType type;
  final String recipientUser; // Email or Name or "ALL_STUDENTS_CS-3A"
  final DateTime timestamp;
  bool isRead;
  final String? deepLinkRoute;
  final Map<String, dynamic>? metadata;
}

/// ---------------------------------------------------------------------------
/// AUDIT & ACTIVITY LOGGING MODELS
/// ---------------------------------------------------------------------------
class AuditLogEntry {
  AuditLogEntry({
    required this.id,
    required this.timestamp,
    required this.actionType,
    required this.performedBy,
    required this.details,
    required this.affectedClass,
    this.affectedFaculty,
  });

  final String id;
  final DateTime timestamp;
  final String actionType;
  final String performedBy;
  final String details;
  final String affectedClass;
  final String? affectedFaculty;
}



