class AcademicProgramme {
  const AcademicProgramme({
    required this.code,
    required this.name,
    required this.duration,
    required this.status,
  });
  final String code;
  final String name;
  final String duration;
  final String status;
}

class AcademicSubject {
  const AcademicSubject({
    required this.code,
    required this.name,
    required this.credits,
    required this.programme,
  });
  final String code;
  final String name;
  final int credits;
  final String programme;
}

class AcademicBatch {
  const AcademicBatch({
    required this.name,
    required this.programme,
    required this.section,
    required this.students,
  });
  final String name;
  final String programme;
  final String section;
  final int students;
}
