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

    _disruptions.addAll([
      DisruptionAlert(
        id: 'DIS-101',
        absentFacultyName: 'Prof. Alan Turing',
        className: 'CS-3A',
        subjectCode: 'CS302',
        subjectName: 'Operating Systems',
        dayOfWeek: 'Monday',
        timeSlot: '09:30 - 10:20 AM',
        periodIndex: 2,
        suggestedSubstitutes: ['Prof. Donald Knuth', 'Dr. Marcus Vance'],
      ),
      DisruptionAlert(
        id: 'DIS-102',
        absentFacultyName: 'Prof. Tim Berners-Lee',
        className: 'CS-3A',
        subjectCode: 'CS305',
        subjectName: 'Web Development',
        dayOfWeek: 'Friday',
        timeSlot: '08:30 - 09:20 AM',
        periodIndex: 1,
        suggestedSubstitutes: ['Prof. Barbara Liskov', 'Prof. Grace Hopper'],
      ),
    ]);

    // Seed Entries for CS-3A
    _entries.addAll([
      // Monday
      const TimetableEntry(
        id: 'ENT-101',
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
        id: 'ENT-102',
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
        id: 'ENT-103',
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
        id: 'ENT-104',
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
        id: 'ENT-105',
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
      const TimetableEntry(
        id: 'ENT-106',
        subjectCode: 'CS305L',
        subjectName: 'Web Dev Lab',
        facultyId: 'FAC-105',
        facultyName: 'Prof. Tim Berners-Lee',
        className: 'CS-3A',
        dayOfWeek: 'Monday',
        timeSlot: '02:50 - 03:40 PM',
        periodIndex: 6,
        isLab: true,
        categoryColorValue: 0xFF00ACC1,
      ),

      // Tuesday
      const TimetableEntry(
        id: 'ENT-107',
        subjectCode: 'CS303',
        subjectName: 'Computer Networks',
        facultyId: 'FAC-103',
        facultyName: 'Prof. Grace Hopper',
        className: 'CS-3A',
        dayOfWeek: 'Tuesday',
        timeSlot: '08:30 - 09:20 AM',
        periodIndex: 1,
        categoryColorValue: 0xFFFB8C00,
      ),
      const TimetableEntry(
        id: 'ENT-108',
        subjectCode: 'CS301',
        subjectName: 'Database Systems',
        facultyId: 'FAC-101',
        facultyName: 'Prof. Sarah Jenkins',
        className: 'CS-3A',
        dayOfWeek: 'Tuesday',
        timeSlot: '09:30 - 10:20 AM',
        periodIndex: 2,
        categoryColorValue: 0xFF1E88E5,
      ),
      const TimetableEntry(
        id: 'ENT-109',
        subjectCode: 'CS306',
        subjectName: 'AI & Machine Learning',
        facultyId: 'ALLOC-9012',
        facultyName: 'Dr. Marcus Vance',
        className: 'CS-3A',
        dayOfWeek: 'Tuesday',
        timeSlot: '10:20 - 11:10 AM',
        periodIndex: 3,
        categoryColorValue: 0xFFD81B60,
      ),
      const TimetableEntry(
        id: 'ENT-110',
        subjectCode: 'CS302',
        subjectName: 'Operating Systems',
        facultyId: 'FAC-102',
        facultyName: 'Prof. Alan Turing',
        className: 'CS-3A',
        dayOfWeek: 'Tuesday',
        timeSlot: '11:30 - 12:20 PM',
        periodIndex: 4,
        categoryColorValue: 0xFF43A047,
      ),
      const TimetableEntry(
        id: 'ENT-111',
        subjectCode: 'CS307L',
        subjectName: 'OS Lab',
        facultyId: 'FAC-102',
        facultyName: 'Prof. Alan Turing',
        className: 'CS-3A',
        dayOfWeek: 'Tuesday',
        timeSlot: '02:00 - 02:50 PM',
        periodIndex: 5,
        isLab: true,
        categoryColorValue: 0xFF43A047,
      ),

      // Wednesday
      const TimetableEntry(
        id: 'ENT-112',
        subjectCode: 'CS306',
        subjectName: 'AI & Machine Learning',
        facultyId: 'ALLOC-9012',
        facultyName: 'Dr. Marcus Vance',
        className: 'CS-3A',
        dayOfWeek: 'Wednesday',
        timeSlot: '08:30 - 09:20 AM',
        periodIndex: 1,
        categoryColorValue: 0xFFD81B60,
      ),
      const TimetableEntry(
        id: 'ENT-113',
        subjectCode: 'CS304',
        subjectName: 'Software Engineering',
        facultyId: 'FAC-104',
        facultyName: 'Prof. Donald Knuth',
        className: 'CS-3A',
        dayOfWeek: 'Wednesday',
        timeSlot: '09:30 - 10:20 AM',
        periodIndex: 2,
        categoryColorValue: 0xFF8E24AA,
      ),
      const TimetableEntry(
        id: 'ENT-114',
        subjectCode: 'CS301',
        subjectName: 'Database Systems',
        facultyId: 'FAC-101',
        facultyName: 'Prof. Sarah Jenkins',
        className: 'CS-3A',
        dayOfWeek: 'Wednesday',
        timeSlot: '10:20 - 11:10 AM',
        periodIndex: 3,
        categoryColorValue: 0xFF1E88E5,
      ),
      const TimetableEntry(
        id: 'ENT-115',
        subjectCode: 'CS308',
        subjectName: 'Cloud Computing Elective',
        facultyId: 'FAC-108',
        facultyName: 'Prof. Barbara Liskov',
        className: 'CS-3A',
        dayOfWeek: 'Wednesday',
        timeSlot: '11:30 - 12:20 PM',
        periodIndex: 4,
        categoryColorValue: 0xFF3949AB,
      ),

      // Thursday
      const TimetableEntry(
        id: 'ENT-116',
        subjectCode: 'CS302',
        subjectName: 'Operating Systems',
        facultyId: 'FAC-102',
        facultyName: 'Prof. Alan Turing',
        className: 'CS-3A',
        dayOfWeek: 'Thursday',
        timeSlot: '08:30 - 09:20 AM',
        periodIndex: 1,
        categoryColorValue: 0xFF43A047,
      ),
      const TimetableEntry(
        id: 'ENT-117',
        subjectCode: 'CS303',
        subjectName: 'Computer Networks',
        facultyId: 'FAC-103',
        facultyName: 'Prof. Grace Hopper',
        className: 'CS-3A',
        dayOfWeek: 'Thursday',
        timeSlot: '09:30 - 10:20 AM',
        periodIndex: 2,
        categoryColorValue: 0xFFFB8C00,
      ),
      const TimetableEntry(
        id: 'ENT-118',
        subjectCode: 'CS304',
        subjectName: 'Software Engineering',
        facultyId: 'FAC-104',
        facultyName: 'Prof. Donald Knuth',
        className: 'CS-3A',
        dayOfWeek: 'Thursday',
        timeSlot: '10:20 - 11:10 AM',
        periodIndex: 3,
        categoryColorValue: 0xFF8E24AA,
      ),

      // Friday
      const TimetableEntry(
        id: 'ENT-119',
        subjectCode: 'CS305',
        subjectName: 'Web Development',
        facultyId: 'FAC-105',
        facultyName: 'Prof. Tim Berners-Lee',
        className: 'CS-3A',
        dayOfWeek: 'Friday',
        timeSlot: '08:30 - 09:20 AM',
        periodIndex: 1,
        categoryColorValue: 0xFF00ACC1,
      ),
      const TimetableEntry(
        id: 'ENT-120',
        subjectCode: 'CS306',
        subjectName: 'AI & Machine Learning',
        facultyId: 'ALLOC-9012',
        facultyName: 'Dr. Marcus Vance',
        className: 'CS-3A',
        dayOfWeek: 'Friday',
        timeSlot: '09:30 - 10:20 AM',
        periodIndex: 2,
        categoryColorValue: 0xFFD81B60,
      ),
      const TimetableEntry(
        id: 'ENT-121',
        subjectCode: 'CS308',
        subjectName: 'Cloud Computing Elective',
        facultyId: 'FAC-108',
        facultyName: 'Prof. Barbara Liskov',
        className: 'CS-3A',
        dayOfWeek: 'Friday',
        timeSlot: '10:20 - 11:10 AM',
        periodIndex: 3,
        categoryColorValue: 0xFF3949AB,
      ),

      // CS-3B Seed Entries
      const TimetableEntry(
        id: 'ENT-201',
        subjectCode: 'CS301',
        subjectName: 'Database Systems',
        facultyId: 'FAC-101',
        facultyName: 'Prof. Sarah Jenkins',
        className: 'CS-3B',
        dayOfWeek: 'Monday',
        timeSlot: '09:30 - 10:20 AM',
        periodIndex: 2,
        categoryColorValue: 0xFF1E88E5,
      ),
      const TimetableEntry(
        id: 'ENT-202',
        subjectCode: 'CS303',
        subjectName: 'Computer Networks',
        facultyId: 'FAC-103',
        facultyName: 'Prof. Grace Hopper',
        className: 'CS-3B',
        dayOfWeek: 'Monday',
        timeSlot: '10:20 - 11:10 AM',
        periodIndex: 3,
        categoryColorValue: 0xFFFB8C00,
      ),

      // ECE-2A Seed Entries
      const TimetableEntry(
        id: 'ENT-301',
        subjectCode: 'EC201',
        subjectName: 'Digital Signal Processing',
        facultyId: 'FAC-108',
        facultyName: 'Prof. Barbara Liskov',
        className: 'ECE-2A',
        dayOfWeek: 'Monday',
        timeSlot: '08:30 - 09:20 AM',
        periodIndex: 1,
        categoryColorValue: 0xFF3949AB,
      ),
    ]);

    _conflicts.addAll([
      ConflictItem(
        id: 'CONF-101',
        type: ConflictType.facultyConflict,
        title: 'Faculty Schedule Conflict',
        description:
            'Prof. Grace Hopper is assigned to both CS-3A and CS-3B on Monday 10:20 - 11:10 AM.',
        affectedEntryIds: ['ENT-103', 'ENT-202'],
        severity: 'High',
      ),
    ]);

    _substitutions.addAll([
      FacultySubstitution(
        id: 'SUB-301',
        date: DateTime.now(),
        originalFaculty: 'Prof. Alan Turing',
        substituteFaculty: 'Prof. Donald Knuth',
        className: 'CS-3A',
        subjectCode: 'CS302',
        subjectName: 'Operating Systems',
        timeSlot: '09:30 - 10:20 AM',
        dayOfWeek: 'Monday',
        reason: 'Attending International CS Conference',
        status: 'Approved',
      ),
    ]);

    _versions.addAll([
      TimetableVersion(
        id: 'VER-v1.0',
        versionNumber: 1,
        title: 'Odd Sem 2026-27 Initial Published Draft',
        createdAt: DateTime.now().subtract(const Duration(days: 14)),
        publishedAt: DateTime.now().subtract(const Duration(days: 7)),
        status: TimetableStatus.published,
        entries: List.from(_entries),
        className: 'CS-3A',
      ),
    ]);
  }

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
      return _versions.isNotEmpty ? _versions.last : null;
    }
  }

  @override
  List<TimetableEntry> getEntriesForClass(String className) {
    return _entries.where((e) => e.className == className).toList();
  }

  @override
  List<TimetableEntry> getEntriesForFaculty(String facultyName) {
    return _entries
        .where(
          (e) => e.facultyName.toLowerCase().contains(facultyName.toLowerCase()),
        )
        .toList();
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
    final Map<String, List<TimetableEntry>> facultySlots = {};
    final Map<String, List<TimetableEntry>> classSlots = {};

    for (final e in entries) {
      final facKey = '${e.facultyName}_${e.dayOfWeek}_${e.timeSlot}';
      facultySlots.putIfAbsent(facKey, () => []).add(e);

      final classKey = '${e.className}_${e.dayOfWeek}_${e.timeSlot}';
      classSlots.putIfAbsent(classKey, () => []).add(e);
    }

    facultySlots.forEach((key, list) {
      if (list.length > 1) {
        detected.add(
          ConflictItem(
            id: 'CONF-FAC-${list.first.id}',
            type: ConflictType.facultyConflict,
            title: 'Faculty Double Booking Detected',
            description:
                '${list.first.facultyName} is scheduled for multiple classes (${list.map((e) => e.className).join(', ')}) on ${list.first.dayOfWeek} during ${list.first.timeSlot}.',
            affectedEntryIds: list.map((e) => e.id).toList(),
            severity: 'High',
          ),
        );
      }
    });

    classSlots.forEach((key, list) {
      if (list.length > 1) {
        detected.add(
          ConflictItem(
            id: 'CONF-CLS-${list.first.id}',
            type: ConflictType.classConflict,
            title: 'Class Schedule Conflict',
            description:
                'Class ${list.first.className} has overlapping subjects (${list.map((e) => e.subjectCode).join(', ')}) on ${list.first.dayOfWeek} at ${list.first.timeSlot}.',
            affectedEntryIds: list.map((e) => e.id).toList(),
            severity: 'High',
          ),
        );
      }
    });

    return detected;
  }

  @override
  void resolveConflict(String conflictId) {
    final conflict = _conflicts.firstWhere(
      (c) => c.id == conflictId,
      orElse: () => ConflictItem(
        id: conflictId,
        type: ConflictType.timeOverlap,
        title: 'Resolved',
        description: '',
        affectedEntryIds: [],
      ),
    );
    conflict.isResolved = true;
  }

  @override
  TimetableVersion publishTimetable(String versionId) {
    final newVersion = TimetableVersion(
      id: 'VER-v${_versions.length + 1}.0',
      versionNumber: _versions.length + 1,
      title: '${_config.batchSection} Active Timetable',
      createdAt: DateTime.now(),
      publishedAt: DateTime.now(),
      status: TimetableStatus.published,
      entries: List.from(_entries),
      className: _config.batchSection,
    );
    _versions.add(newVersion);
    return newVersion;
  }

  @override
  TimetableVersion saveNewVersion(String title, List<TimetableEntry> entries) {
    final v = TimetableVersion(
      id: 'VER-v${_versions.length + 1}.0',
      versionNumber: _versions.length + 1,
      title: title,
      createdAt: DateTime.now(),
      status: TimetableStatus.draft,
      entries: entries,
      className: _config.batchSection,
    );
    _versions.add(v);
    return v;
  }

  @override
  List<DisruptionAlert> getDisruptionAlerts() =>
      List.unmodifiable(_disruptions);

  @override
  void resolveDisruptionAlert(String alertId, String chosenSubstitute) {
    final index = _disruptions.indexWhere((d) => d.id == alertId);
    if (index != -1) {
      final alert = _disruptions[index];
      alert.isResolved = true;

      // Add to approved substitutions
      requestSubstitution(
        FacultySubstitution(
          id: 'SUB-${DateTime.now().millisecondsSinceEpoch % 10000}',
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
        ),
      );
    }
  }

  @override
  List<FacultySubstitution> getSubstitutions() =>
      List.unmodifiable(_substitutions);

  @override
  void requestSubstitution(FacultySubstitution sub) {
    _substitutions.insert(0, sub);
  }

  @override
  void approveSubstitution(String subId) {
    final index = _substitutions.indexWhere((s) => s.id == subId);
    if (index != -1) {
      _substitutions[index].status = 'Approved';
    }
  }

  @override
  void rejectSubstitution(String subId) {
    final index = _substitutions.indexWhere((s) => s.id == subId);
    if (index != -1) {
      _substitutions[index].status = 'Rejected';
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
      (
        'CS305L',
        'Web Dev Lab',
        'Prof. Tim Berners-Lee',
        0xFF00ACC1,
        true
      ),
      (
        'CS308',
        'Cloud Computing Elective',
        'Prof. Barbara Liskov',
        0xFF3949AB,
        false
      ),
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
}
