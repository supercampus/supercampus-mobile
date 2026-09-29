import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supercampus_mobile/src/core/theme/app_theme.dart';
import 'package:supercampus_mobile/src/features/admin_portal/data/admin_student_repository.dart';
import 'package:supercampus_mobile/src/features/admin_portal/presentation/admin_portal_shell.dart';
import 'package:supercampus_mobile/src/features/admin_portal/presentation/admin_student_directory.dart';

ManagedStudent _student(
  String id,
  String name, {
  int? year,
  String department = 'B.E in Computer Science & Engineering',
  ManagedStudentResidency residency = ManagedStudentResidency.dayScholar,
  String? roll,
}) => ManagedStudent(
  id: id,
  name: name,
  rollNumber: roll ?? 'MEC$id',
  department: department,
  residency: residency,
  mobileNumber: '',
  email: '$id@mec.local',
  status: 'active',
  yearOfStudy: year,
  section: 'A',
);

final _students = [
  _student('1', 'Zara Khan', year: 1),
  _student(
    '2',
    'Arun Kumar',
    year: 1,
    department: 'B.Tech in Information Technology',
    residency: ManagedStudentResidency.hosteller,
  ),
  _student('3', 'Meena S', year: 3, department: 'B.E in Computer Science & Business Systems'),
  _student('4', 'Bala R', year: 3, department: 'B.E in Computer Science & Business Systems'),
  _student('5', 'Kavin P'),
];

Widget _host(Widget child) =>
    MaterialApp(theme: AppTheme.light, home: Scaffold(body: child));

void main() {
  group('buildStudentDirectory', () {
    test('groups by year (unset last) then department, names sorted', () {
      final sections = buildStudentDirectory(_students);
      expect(sections.map((s) => s.title), [
        '1st Year',
        '3rd Year',
        'Year not set',
      ]);
      final third = sections[1].items;
      expect(third.first, isA<StudentDirectorySubheader>());
      expect(
        (third.first as StudentDirectorySubheader).label,
        'B.E in Computer Science & Business Systems',
      );
      final rows = third.whereType<StudentDirectoryRow>().toList();
      expect(rows.map((r) => r.student.name), ['Bala R', 'Meena S']);
      expect(rows.first.isFirst, isTrue);
      expect(rows.last.isLast, isTrue);
      expect(sections.fold<int>(0, (sum, s) => sum + s.count), 5);
    });

    test('search is one flat alphabetical list across years', () {
      final sections = buildStudentDirectory(_students, query: 'computer');
      expect(sections, hasLength(1));
      expect(sections.single.items.whereType<StudentDirectorySubheader>(), isEmpty);
      expect(
        sections.single.items.cast<StudentDirectoryRow>().map((r) => r.student.name),
        ['Bala R', 'Kavin P', 'Meena S', 'Zara Khan'],
      );
    });

    test('filters combine', () {
      expect(
        buildStudentDirectory(
          _students,
          year: 1,
          residency: ManagedStudentResidency.hosteller,
        ).single.count,
        1,
      );
      expect(
        buildStudentDirectory(
          _students,
          department: 'b.e in computer science & business systems',
        ).single.count,
        2,
      );
      expect(buildStudentDirectory(_students, query: 'nobody'), isEmpty);
    });

    test('initials and course label', () {
      expect(studentInitials('Meena S'), 'MS');
      expect(studentInitials(' arun '), 'A');
      expect(studentCourseLabel('B.E in Computer Science'), 'Computer Science');
      expect(studentCourseLabel('Mechanical'), 'Mechanical');
    });
  });

  group('StudentDirectoryView', () {
    testWidgets('shows count, sticky year headers and rows without helper text', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(StudentDirectoryView(students: _students, onOpen: (_) {})),
      );
      expect(find.text('Students'), findsOneWidget);
      expect(find.text('5 students'), findsOneWidget);
      expect(find.text('1st Year'), findsOneWidget);
      expect(find.text('3rd Year'), findsOneWidget);
      expect(find.text('Meena S'), findsOneWidget);
      expect(find.text('MS'), findsOneWidget);
      expect(find.text('Hosteller'), findsOneWidget);
      expect(find.textContaining('Tap dropdown'), findsNothing);
    });

    testWidgets('search narrows to a flat result list', (tester) async {
      await tester.pumpWidget(
        _host(StudentDirectoryView(students: _students, onOpen: (_) {})),
      );
      await tester.enterText(find.byKey(const Key('student-search')), 'meena');
      await tester.pump();
      expect(find.text('1 of 5 students'), findsOneWidget);
      expect(find.text('1 Result'), findsOneWidget);
      expect(find.text('Meena S'), findsOneWidget);
      expect(find.text('Bala R'), findsNothing);
      expect(find.text('3rd Year'), findsNothing);

      await tester.tap(find.byKey(const Key('student-filter-clear')));
      await tester.pump();
      expect(find.text('5 students'), findsOneWidget);
    });

    testWidgets('year, department and residency menus filter the list', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(StudentDirectoryView(students: _students, onOpen: (_) {})),
      );

      await tester.tap(find.byKey(const Key('student-filter-year')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('3rd Year').last);
      await tester.pumpAndSettle();
      expect(find.text('2 of 5 students'), findsOneWidget);
      expect(find.text('Zara Khan'), findsNothing);

      await tester.tap(find.byKey(const Key('student-filter-year')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('All years'));
      await tester.pumpAndSettle();
      expect(find.text('5 students'), findsOneWidget);

      await tester.tap(find.byKey(const Key('student-filter-residency')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hostellers').last);
      await tester.pumpAndSettle();
      expect(find.text('1 of 5 students'), findsOneWidget);
      expect(find.text('Arun Kumar'), findsOneWidget);

      await tester.tap(find.byKey(const Key('student-filter-residency')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Everyone'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('student-filter-department')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('B.Tech in Information Technology').last);
      await tester.pumpAndSettle();
      expect(find.text('1 of 5 students'), findsOneWidget);
      expect(find.text('Arun Kumar'), findsOneWidget);
    });

    testWidgets('tap opens and long press edits', (tester) async {
      ManagedStudent? opened;
      ManagedStudent? edited;
      await tester.pumpWidget(
        _host(
          StudentDirectoryView(
            students: _students,
            onOpen: (student) => opened = student,
            onEdit: (student) => edited = student,
          ),
        ),
      );
      await tester.tap(find.text('Meena S'));
      expect(opened?.id, '3');
      await tester.longPress(find.text('Bala R'));
      expect(edited?.id, '4');
    });

    testWidgets('builds lazily for a large campus', (tester) async {
      final many = [
        for (var i = 0; i < 600; i++)
          _student('s$i', 'Student ${i.toString().padLeft(3, '0')}', year: i % 4 + 1),
      ];
      await tester.pumpWidget(
        _host(StudentDirectoryView(students: many, onOpen: (_) {})),
      );
      expect(find.text('600 students'), findsOneWidget);
      expect(
        find.byType(CircleAvatar).evaluate().length,
        lessThan(60),
      );
    });
  });

  testWidgets('tapping a student opens the profile, and Edit saves the student', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Map<String, dynamic>? saved;
    final record = {
      'id': 'student-3',
      'name': 'Meena S',
      'rollNo': 'MEC26CB003',
      'department': 'B.E in Computer Science & Business Systems',
      'residency': 'day_scholar',
      'mobileNumber': '',
      'email': 'meena@mec.local',
      'status': 'active',
      'yearOfStudy': 3,
      'section': 'A',
      'guardianName': 'Meena Mother',
      'guardianPhone': '+919000000086',
      'guardianRelationship': 'Mother',
    };
    final repository = AdminStudentRepository(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: ({bool forceRefresh = false}) async => 'token',
      client: MockClient((request) async {
        if (request.method == 'GET') {
          return http.Response(jsonEncode({'data': [record]}), 200);
        }
        saved = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'data': {...record, ...saved!, 'id': 'student-3'},
          }),
          200,
        );
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AdminStudentsPage(repository: repository),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('1 student'), findsOneWidget);

    await tester.tap(find.text('Meena S'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit student'));
    await tester.pumpAndSettle();
    expect(find.text('Save changes'), findsOneWidget);
    // No catalog from this server: the built-in programme lists remain.
    expect(
      find.text('Saved as: B.E in Computer Science & Business Systems'),
      findsOneWidget,
    );

    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!['department'], 'B.E in Computer Science & Business Systems');
    expect(saved!['yearOfStudy'], 3);
    expect(saved!['guardianPhone'], '+919000000086');
    expect(saved!['guardianRelationship'], 'Mother');
    expect(find.text('Meena S was updated.'), findsOneWidget);
  });

  testWidgets('the edit form picks programme and class from the academic catalog', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const aidsDept = '11111111-1111-1111-1111-111111111111';
    const csbsDept = '22222222-2222-2222-2222-222222222222';
    const aidsProgramme = '33333333-3333-3333-3333-333333333333';
    const csbsProgramme = '44444444-4444-4444-4444-444444444444';
    const aidsClass = '55555555-5555-5555-5555-555555555555';
    const csbsClass = '66666666-6666-6666-6666-666666666666';
    Map<String, dynamic>? saved;
    final record = {
      'id': 'student-3',
      'name': 'Meena S',
      'rollNo': 'MEC26AI003',
      'department': 'Artificial Intelligence and Data Science',
      'departmentId': aidsDept,
      'sectionId': aidsClass,
      'residency': 'day_scholar',
      'email': 'meena@mec.local',
      'status': 'active',
      'yearOfStudy': 1,
      'section': 'A',
    };
    final catalog = {
      'departments': [
        {'id': aidsDept, 'code': 'AIDS', 'name': 'AI & Data Science', 'active': true},
        {'id': csbsDept, 'code': 'CSBS', 'name': 'CS & Business Systems', 'active': true},
      ],
      'programmes': [
        {
          'id': aidsProgramme,
          'code': 'BE-AIDS',
          'name': 'B.E. Artificial Intelligence and Data Science',
          'departmentId': aidsDept,
          'active': true,
        },
        {
          'id': csbsProgramme,
          'code': 'BE-CSBS',
          'name': 'B.E. Computer Science and Business Systems',
          'departmentId': csbsDept,
          'active': true,
        },
      ],
      'classes': [
        {
          'id': aidsClass,
          'code': 'A',
          'name': 'AIDS - Section A',
          'programmeId': aidsProgramme,
          'departmentId': aidsDept,
          'departmentCode': 'AIDS',
          'yearOfStudy': 1,
          'active': true,
        },
        {
          'id': csbsClass,
          'code': 'B',
          'name': 'CSBS - Section B',
          'programmeId': csbsProgramme,
          'departmentId': csbsDept,
          'departmentCode': 'CSBS',
          'yearOfStudy': 3,
          'active': true,
        },
      ],
      'subjects': <Object>[],
    };
    final repository = AdminStudentRepository(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: ({bool forceRefresh = false}) async => 'token',
      client: MockClient((request) async {
        if (request.url.path.endsWith('/academic-structure/catalog')) {
          return http.Response(jsonEncode({'data': catalog}), 200);
        }
        if (request.method == 'GET') {
          return http.Response(jsonEncode({'data': [record]}), 200);
        }
        saved = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'data': {...record, ...saved!, 'id': 'student-3'},
          }),
          200,
        );
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AdminStudentsPage(repository: repository),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Meena S'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit student'));
    await tester.pumpAndSettle();

    // The current department link selects the catalog programme; the
    // built-in lists are not shown.
    expect(
      find.text('B.E. Artificial Intelligence and Data Science'),
      findsOneWidget,
    );
    expect(find.textContaining('Saved as:'), findsNothing);
    expect(find.text('AIDS · Year 1 · Section A'), findsOneWidget);

    await tester.tap(find.byKey(const Key('student-programme-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('B.E. Computer Science and Business Systems').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Not assigned'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CSBS · Year 3 · Section B').last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!['programmeId'], csbsProgramme);
    expect(saved!['departmentId'], csbsDept);
    expect(saved!['department'], 'B.E. Computer Science and Business Systems');
    expect(saved!['sectionId'], csbsClass);
    expect(saved!['section'], 'B');
    expect(saved!['yearOfStudy'], 3);
  });
}
