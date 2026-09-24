class StudentYearGroup<T> {
  const StudentYearGroup({required this.year, required this.students});

  final int? year;
  final List<T> students;

  String get label => studentYearLabel(year);
}

int? parseStudentYear(Object? value) {
  if (value is num) {
    final year = value.toInt();
    return year > 0 && year < 7 ? year : null;
  }

  final text = value?.toString().trim().toLowerCase() ?? '';
  if (text.isEmpty) return null;
  final numeric = int.tryParse(text);
  if (numeric != null && numeric > 0 && numeric < 7) return numeric;

  final digit = RegExp(r'\b([1-6])(?:st|nd|rd|th)?\b').firstMatch(text);
  if (digit != null) return int.parse(digit.group(1)!);

  const words = {
    'first': 1,
    'second': 2,
    'third': 3,
    'fourth': 4,
    'fifth': 5,
    'sixth': 6,
  };
  for (final entry in words.entries) {
    if (text.contains(entry.key)) return entry.value;
  }

  const romanNumerals = {'i': 1, 'ii': 2, 'iii': 3, 'iv': 4, 'v': 5, 'vi': 6};
  final romanMatch = RegExp(
    r'^(?:year\s+)?(vi|iv|v|iii|ii|i)(?:\s+year)?$',
  ).firstMatch(text);
  final romanYear = romanNumerals[romanMatch?.group(1)];
  if (romanYear != null) return romanYear;
  return null;
}

String studentYearLabel(int? year) {
  final assignedYear = year ?? 2;
  final suffix = switch (assignedYear) {
    1 => 'st',
    2 => 'nd',
    3 => 'rd',
    _ => 'th',
  };
  return '$assignedYear$suffix year students';
}

List<StudentYearGroup<T>> groupStudentsByYear<T>(
  Iterable<T> students,
  int? Function(T student) yearOf,
) {
  final grouped = <int?, List<T>>{};
  for (final student in students) {
    final year = yearOf(student) ?? 2;
    grouped.putIfAbsent(year, () => <T>[]).add(student);
  }
  final years = grouped.keys.toList()
    ..sort((left, right) {
      if (left == null) return 1;
      if (right == null) return -1;
      return left.compareTo(right);
    });
  return [
    for (final year in years)
      StudentYearGroup(year: year, students: grouped[year]!),
  ];
}

class StudentDepartmentGroup<T> {
  const StudentDepartmentGroup({
    required this.department,
    required this.students,
  });

  final String department;
  final List<T> students;

  String get label {
    final trimmed = department.trim();
    return trimmed.isEmpty ? 'General / Unassigned' : trimmed;
  }
}

class StudentYearDepartmentGroup<T> {
  const StudentYearDepartmentGroup({
    required this.year,
    required this.departments,
    required this.students,
  });

  final int? year;
  final List<StudentDepartmentGroup<T>> departments;
  final List<T> students;

  String get label => studentYearLabel(year);
}

List<StudentYearDepartmentGroup<T>> groupStudentsByYearAndDepartment<T>(
  Iterable<T> students, {
  required int? Function(T student) yearOf,
  required String Function(T student) departmentOf,
}) {
  final yearGroups = groupStudentsByYear(students, yearOf);
  return [
    for (final yearGroup in yearGroups) ...[
      () {
        final deptMap = <String, List<T>>{};
        for (final student in yearGroup.students) {
          final dept = departmentOf(student).trim();
          deptMap.putIfAbsent(dept.isEmpty ? 'General' : dept, () => <T>[]).add(student);
        }
        final sortedDepts = deptMap.keys.toList()..sort();
        final deptGroups = [
          for (final dept in sortedDepts)
            StudentDepartmentGroup(department: dept, students: deptMap[dept]!),
        ];
        return StudentYearDepartmentGroup(
          year: yearGroup.year,
          departments: deptGroups,
          students: yearGroup.students,
        );
      }(),
    ],
  ];
}

