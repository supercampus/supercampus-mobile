/// The institution's academic structure as the backend holds it
/// (`/api/v1/academic-structure/catalog`). Every picker that asks for a
/// department, programme, class or subject reads these, so there is one list
/// to keep right instead of one per screen.
library;

String _text(Object? value, [String fallback = '']) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

int? _int(Object? value) => switch (value) {
  final int number => number,
  final num number => number.toInt(),
  final String text => int.tryParse(text.trim()),
  _ => null,
};

double? _double(Object? value) => switch (value) {
  final num number => number.toDouble(),
  final String text => double.tryParse(text.trim()),
  _ => null,
};

bool _bool(Object? value, {bool fallback = true}) =>
    value is bool ? value : fallback;

List<Map<String, dynamic>> _rows(Object? value) =>
    (value as List? ?? const []).whereType<Map<String, dynamic>>().toList();

class AcademicDepartment {
  const AcademicDepartment({
    required this.id,
    required this.code,
    required this.name,
    this.active = true,
    this.programmeCount = 0,
    this.studentCount = 0,
  });

  factory AcademicDepartment.fromJson(Map<String, dynamic> json) =>
      AcademicDepartment(
        id: _text(json['id']),
        code: _text(json['code']),
        name: _text(json['name'], 'Department'),
        active: _bool(json['active']),
        programmeCount: _int(json['programmeCount']) ?? 0,
        studentCount: _int(json['studentCount']) ?? 0,
      );

  final String id;
  final String code;
  final String name;
  final bool active;
  final int programmeCount;
  final int studentCount;
}

class AcademicProgramme {
  const AcademicProgramme({
    required this.id,
    required this.code,
    required this.name,
    required this.departmentId,
    this.departmentCode = '',
    this.departmentName = '',
    this.durationTerms,
    this.active = true,
    this.classCount = 0,
    this.studentCount = 0,
  });

  factory AcademicProgramme.fromJson(Map<String, dynamic> json) =>
      AcademicProgramme(
        id: _text(json['id']),
        code: _text(json['code']),
        name: _text(json['name'], 'Programme'),
        departmentId: _text(json['departmentId']),
        departmentCode: _text(json['departmentCode']),
        departmentName: _text(json['departmentName']),
        durationTerms: _int(json['durationTerms']),
        active: _bool(json['active']),
        classCount: _int(json['classCount']) ?? 0,
        studentCount: _int(json['studentCount']) ?? 0,
      );

  final String id;
  final String code;
  final String name;
  final String departmentId;
  final String departmentCode;
  final String departmentName;

  /// Semesters; two to a year.
  final int? durationTerms;
  final bool active;
  final int classCount;
  final int studentCount;

  int? get durationYears =>
      durationTerms == null ? null : (durationTerms! + 1) ~/ 2;

  /// "4 years · 8 semesters", or empty when the duration is not on record.
  String get durationLabel {
    final terms = durationTerms;
    if (terms == null) return '';
    final years = durationYears!;
    return '$years ${years == 1 ? 'year' : 'years'} · '
        '$terms ${terms == 1 ? 'semester' : 'semesters'}';
  }
}

/// A class is one section of a programme's yearly batch ("CSBS · Year 1 ·
/// Section A"). Its year of study moves up each academic year by itself.
class AcademicClass {
  const AcademicClass({
    required this.id,
    required this.code,
    required this.name,
    required this.programmeId,
    this.programmeCode = '',
    this.programmeName = '',
    this.departmentId = '',
    this.departmentCode = '',
    this.departmentName = '',
    this.batchName = '',
    this.yearOfStudy,
    this.startYear,
    this.capacity,
    this.active = true,
    this.studentCount = 0,
  });

  factory AcademicClass.fromJson(Map<String, dynamic> json) => AcademicClass(
    id: _text(json['id']),
    code: _text(json['code']),
    name: _text(json['name'], 'Class'),
    programmeId: _text(json['programmeId']),
    programmeCode: _text(json['programmeCode']),
    programmeName: _text(json['programmeName']),
    departmentId: _text(json['departmentId']),
    departmentCode: _text(json['departmentCode']),
    departmentName: _text(json['departmentName']),
    batchName: _text(json['batchName']),
    yearOfStudy: _int(json['yearOfStudy']),
    startYear: _int(json['startYear']),
    capacity: _int(json['capacity']),
    active: _bool(json['active']),
    studentCount: _int(json['studentCount']) ?? 0,
  );

  final String id;

  /// The section letter or code ("A").
  final String code;
  final String name;
  final String programmeId;
  final String programmeCode;
  final String programmeName;
  final String departmentId;
  final String departmentCode;
  final String departmentName;
  final String batchName;
  final int? yearOfStudy;
  final int? startYear;
  final int? capacity;
  final bool active;
  final int studentCount;

  /// "CSBS · Year 1 · Section A".
  String get label => [
    if (departmentCode.isNotEmpty) departmentCode,
    if (yearOfStudy != null) 'Year $yearOfStudy',
    'Section $code',
  ].join(' · ');
}

class AcademicSubject {
  const AcademicSubject({
    required this.id,
    required this.code,
    required this.name,
    required this.departmentId,
    this.departmentCode = '',
    this.departmentName = '',
    this.credits,
    this.active = true,
    this.offeringCount = 0,
  });

  factory AcademicSubject.fromJson(Map<String, dynamic> json) =>
      AcademicSubject(
        id: _text(json['id']),
        code: _text(json['code']),
        name: _text(json['name'], 'Subject'),
        departmentId: _text(json['departmentId']),
        departmentCode: _text(json['departmentCode']),
        departmentName: _text(json['departmentName']),
        credits: _double(json['credits']),
        active: _bool(json['active']),
        offeringCount: _int(json['offeringCount']) ?? 0,
      );

  final String id;
  final String code;
  final String name;
  final String departmentId;
  final String departmentCode;
  final String departmentName;
  final double? credits;
  final bool active;
  final int offeringCount;

  /// "4 credits", "2.5 credits", or empty.
  String get creditsLabel {
    final value = credits;
    if (value == null) return '';
    final number = value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toString();
    return '$number ${value == 1 ? 'credit' : 'credits'}';
  }
}

/// What the signed-in person may change, as the server decided it.
class AcademicStructureAccess {
  const AcademicStructureAccess({
    this.createProgrammes = false,
    this.updateProgrammes = false,
    this.createSubjects = false,
    this.updateSubjects = false,
  });

  factory AcademicStructureAccess.fromJson(Map<String, dynamic> json) =>
      AcademicStructureAccess(
        createProgrammes: json['createProgrammes'] == true,
        updateProgrammes: json['updateProgrammes'] == true,
        createSubjects: json['createSubjects'] == true,
        updateSubjects: json['updateSubjects'] == true,
      );

  final bool createProgrammes;
  final bool updateProgrammes;
  final bool createSubjects;
  final bool updateSubjects;
}

class AcademicCatalog {
  const AcademicCatalog({
    this.academicYearName = '',
    this.departments = const [],
    this.programmes = const [],
    this.classes = const [],
    this.subjects = const [],
    this.unlinkedStudentCount = 0,
    this.access = const AcademicStructureAccess(),
  });

  factory AcademicCatalog.fromJson(Map<String, dynamic> json) {
    final year = json['academicYear'];
    final can = json['can'];
    return AcademicCatalog(
      academicYearName: year is Map<String, dynamic>
          ? _text(year['name'], _text(year['code']))
          : '',
      departments: _rows(
        json['departments'],
      ).map(AcademicDepartment.fromJson).toList(),
      programmes: _rows(
        json['programmes'],
      ).map(AcademicProgramme.fromJson).toList(),
      classes: _rows(json['classes']).map(AcademicClass.fromJson).toList(),
      subjects: _rows(json['subjects']).map(AcademicSubject.fromJson).toList(),
      unlinkedStudentCount: _int(json['unlinkedStudentCount']) ?? 0,
      access: can is Map<String, dynamic>
          ? AcademicStructureAccess.fromJson(can)
          : const AcademicStructureAccess(),
    );
  }

  final String academicYearName;
  final List<AcademicDepartment> departments;
  final List<AcademicProgramme> programmes;
  final List<AcademicClass> classes;
  final List<AcademicSubject> subjects;

  /// Active students whose record points at no department yet.
  final int unlinkedStudentCount;
  final AcademicStructureAccess access;

  List<AcademicDepartment> get activeDepartments =>
      departments.where((item) => item.active).toList();
  List<AcademicProgramme> get activeProgrammes =>
      programmes.where((item) => item.active).toList();
  List<AcademicClass> get activeClasses =>
      classes.where((item) => item.active).toList();

  AcademicDepartment? departmentById(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final item in departments) {
      if (item.id == id) return item;
    }
    return null;
  }

  AcademicProgramme? programmeById(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final item in programmes) {
      if (item.id == id) return item;
    }
    return null;
  }

  /// The programme a student belongs to, from the department link the
  /// Student Master holds. A department normally runs one programme; when it
  /// runs several, the one whose name matches [departmentLabel] wins.
  AcademicProgramme? programmeForDepartment(
    String? departmentId, {
    String departmentLabel = '',
  }) {
    final candidates = programmes
        .where((item) => item.departmentId == departmentId)
        .toList();
    if (candidates.isEmpty) return null;
    final label = departmentLabel.trim().toLowerCase();
    for (final item in candidates) {
      if (label.isNotEmpty && item.name.toLowerCase() == label) return item;
    }
    return candidates.firstWhere(
      (item) => item.active,
      orElse: () => candidates.first,
    );
  }

  List<AcademicClass> classesForProgramme(String programmeId) =>
      classes.where((item) => item.programmeId == programmeId).toList();
}
