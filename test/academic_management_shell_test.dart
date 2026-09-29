import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/core/theme/app_theme.dart';
import 'package:supercampus_mobile/src/features/academics/data/academic_models.dart';
import 'package:supercampus_mobile/src/features/academics/data/academic_structure_repository.dart';
import 'package:supercampus_mobile/src/features/academics/presentation/academic_management_shell.dart';
import 'package:supercampus_mobile/src/features/academics/presentation/academic_programme_field.dart';
import 'package:supercampus_mobile/src/features/authentication/data/auth_repository.dart';

const _session = UserSession(
  email: 'admin@mec.local',
  displayName: 'MEC Admin',
  role: UserRole.admin,
  roleId: 'tenant_admin',
  roleIds: ['tenant_admin'],
);

/// The catalog JSON the backend returns for MEC, trimmed to two departments.
Map<String, dynamic> _catalogJson({bool canEdit = true}) => {
  'academicYear': {'code': '2026-27', 'name': 'Academic Year 2026-27'},
  'departments': [
    {
      'id': 'd-csbs',
      'code': 'CSBS',
      'name': 'Computer Science and Business Systems',
      'active': true,
      'programmeCount': 1,
      'studentCount': 34,
    },
    {
      'id': 'd-it',
      'code': 'IT',
      'name': 'Information Technology',
      'active': true,
      'programmeCount': 1,
      'studentCount': 33,
    },
  ],
  'programmes': [
    {
      'id': 'p-csbs',
      'code': 'BE-CSBS',
      'name': 'B.E. Computer Science and Business Systems',
      'departmentId': 'd-csbs',
      'departmentCode': 'CSBS',
      'durationTerms': 8,
      'active': true,
      'studentCount': 34,
    },
    {
      'id': 'p-it',
      'code': 'BE-IT',
      'name': 'B.E. Information Technology',
      'departmentId': 'd-it',
      'departmentCode': 'IT',
      'durationTerms': 8,
      'active': true,
      'studentCount': 33,
    },
  ],
  'classes': [
    {
      'id': 's-csbs-a',
      'code': 'A',
      'name': 'CSBS - Section A',
      'capacity': 60,
      'active': true,
      'batchName': 'CSBS Batch of 2026-2030',
      'yearOfStudy': 1,
      'programmeId': 'p-csbs',
      'programmeName': 'B.E. Computer Science and Business Systems',
      'departmentId': 'd-csbs',
      'departmentCode': 'CSBS',
      'studentCount': 34,
    },
  ],
  'subjects': [
    {
      'id': 'sub-1',
      'code': 'CSBS101',
      'name': 'Data Structures',
      'credits': 4.0,
      'departmentId': 'd-csbs',
      'departmentCode': 'CSBS',
      'active': true,
    },
  ],
  'unlinkedStudentCount': 0,
  'can': {
    'createProgrammes': canEdit,
    'updateProgrammes': canEdit,
    'createSubjects': canEdit,
    'updateSubjects': canEdit,
  },
};

class _FakeRepository implements AcademicStructureRepository {
  _FakeRepository({this.canEdit = true});

  final bool canEdit;
  final calls = <String>[];
  int loads = 0;

  @override
  Future<AcademicCatalog> loadCatalog({bool includeInactive = false}) async {
    loads++;
    return AcademicCatalog.fromJson(_catalogJson(canEdit: canEdit));
  }

  @override
  Future<void> createClass({
    required String programmeId,
    required int yearOfStudy,
    required String sectionCode,
    int? capacity,
  }) async => calls.add('class $programmeId $yearOfStudy $sectionCode');

  @override
  Future<void> createDepartment({
    required String code,
    required String name,
  }) async => calls.add('department $code $name');

  @override
  Future<void> createProgramme({
    required String departmentId,
    required String code,
    required String name,
    int? durationTerms,
  }) async => calls.add('programme $departmentId $code $durationTerms');

  @override
  Future<void> createSubject({
    required String departmentId,
    required String code,
    required String name,
    double? credits,
  }) async => calls.add('subject $departmentId $code');

  @override
  Future<void> updateClass(
    String id, {
    required String sectionCode,
    int? capacity,
    bool? active,
  }) async => calls.add('update class $id $sectionCode $active');

  @override
  Future<void> updateDepartment(
    String id, {
    required String code,
    required String name,
    bool? active,
  }) async => calls.add('update department $id $active');

  @override
  Future<void> updateProgramme(
    String id, {
    required String departmentId,
    required String code,
    required String name,
    int? durationTerms,
    bool? active,
  }) async => calls.add('update programme $id $name $active');

  @override
  Future<void> updateSubject(
    String id, {
    required String departmentId,
    required String code,
    required String name,
    double? credits,
    bool? active,
  }) async => calls.add('update subject $id $active');
}

Future<void> _pump(WidgetTester tester, AcademicStructureRepository? repo) async {
  tester.view.physicalSize = const Size(430, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: AcademicManagementShell(
        session: _session,
        onExitModule: () {},
        repository: repo,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lists the programmes the backend holds, not sample data', (
    tester,
  ) async {
    await _pump(tester, _FakeRepository());

    expect(
      find.text('B.E. Computer Science and Business Systems'),
      findsOneWidget,
    );
    expect(find.text('BE-CSBS · 4 years · 8 semesters'), findsOneWidget);
    expect(find.text('Academic Year 2026-27'), findsOneWidget);
    expect(find.text('B.Tech Computer Science'), findsNothing);
    expect(find.text('Bachelor of Business Administration'), findsNothing);
  });

  testWidgets('subjects and classes come from the same catalog', (
    tester,
  ) async {
    await _pump(tester, _FakeRepository());

    await tester.tap(find.text('Subjects'));
    await tester.pumpAndSettle();
    expect(find.text('Data Structures'), findsOneWidget);
    expect(find.text('4 credits'), findsOneWidget);

    await tester.tap(find.text('Classes'));
    await tester.pumpAndSettle();
    expect(find.text('Year 1 · Section A'), findsOneWidget);
    expect(find.text('34 students'), findsOneWidget);
  });

  testWidgets('editing a programme saves through the repository', (
    tester,
  ) async {
    final repo = _FakeRepository();
    await _pump(tester, repo);

    await tester.tap(find.text('B.E. Information Technology'));
    await tester.pumpAndSettle();
    expect(find.text('Edit programme'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Programme name'),
      'B.Tech Information Technology',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repo.calls, ['update programme p-it B.Tech Information Technology null']);
    expect(repo.loads, 2, reason: 'the list reloads after a save');
  });

  testWidgets('adding a class places it by programme, year and section', (
    tester,
  ) async {
    final repo = _FakeRepository();
    await _pump(tester, repo);
    await tester.tap(find.text('Classes'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('academic-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(DropdownButtonFormField<String>, 'Programme'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('B.E. Information Technology').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Section'), 'B');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repo.calls, ['class p-it 1 B']);
  });

  testWidgets('without edit grants the page is read-only', (tester) async {
    await _pump(tester, _FakeRepository(canEdit: false));

    expect(find.byKey(const ValueKey('academic-add')), findsNothing);
    expect(find.text('Edit'), findsNothing);
    await tester.tap(find.text('B.E. Information Technology'));
    await tester.pumpAndSettle();
    expect(find.text('Edit programme'), findsNothing);
  });

  testWidgets('without a backend it says so instead of inventing data', (
    tester,
  ) async {
    await _pump(tester, null);

    expect(find.text('Not connected'), findsOneWidget);
    expect(find.textContaining('B.E.'), findsNothing);
  });

  group('catalog lookups', () {
    final catalog = AcademicCatalog.fromJson(_catalogJson());

    test('a student department link resolves to its programme', () {
      expect(catalog.programmeForDepartment('d-it')?.id, 'p-it');
      expect(catalog.programmeForDepartment('missing'), isNull);
      expect(
        AcademicProgrammeField.initialFor(catalog, departmentId: 'd-csbs')?.name,
        'B.E. Computer Science and Business Systems',
      );
    });

    test('labels read naturally', () {
      expect(catalog.classes.single.label, 'CSBS · Year 1 · Section A');
      expect(catalog.subjects.single.creditsLabel, '4 credits');
      expect(catalog.access.createProgrammes, isTrue);
    });
  });
}
