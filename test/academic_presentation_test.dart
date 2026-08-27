import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/core/access/academic_presentation.dart';
import 'package:supercampus_mobile/src/core/access/effective_permissions.dart';
import 'package:supercampus_mobile/src/core/access/module_catalog.dart';
import 'package:supercampus_mobile/src/features/modules/presentation/module_stack.dart';

EffectivePermissions grants(
  Set<String> grants, {
  Map<String, PermissionScope> scopes = const {},
}) => EffectivePermissions(grants: grants, scopes: scopes);

void main() {
  group('academic presentation', () {
    test('nothing academic granted shows no academic entry', () {
      expect(
        academicPresentationFor(grants({'canteen.menu.read'})),
        AcademicPresentation.none,
      );
    });

    test('a student — own scope, no approvals — gets the merged view', () {
      final student = grants(
        {
          'academics.attendance.read',
          'academics.marks.read',
          'attendance.leave.create',
          'attendance.leave.read',
          'timetable.schedule.read',
        },
        scopes: {
          ModuleCatalog.academics: PermissionScope.own,
          ModuleCatalog.attendance: PermissionScope.own,
          ModuleCatalog.timetable: PermissionScope.own,
        },
      );
      expect(academicPresentationFor(student), AcademicPresentation.learner);
    });

    test('creating a request does not make someone staff', () {
      // A learner writes — leave, electives, revaluation. Only authority over
      // other people's records separates the two views.
      final student = grants(
        {'attendance.leave.create', 'examination.revaluation.create'},
        scopes: {
          ModuleCatalog.attendance: PermissionScope.own,
          ModuleCatalog.examination: PermissionScope.own,
        },
      );
      expect(academicPresentationFor(student), AcademicPresentation.learner);
    });

    test('a parent holds fewer grants but the same shape as a student', () {
      // Parents are minimal in-app by design; most of what reaches them goes
      // out over push and WhatsApp. That is a smaller grant bundle, not a
      // different code path — which is why no parent branch exists.
      final parent = grants(
        {'academics.attendance.read'},
        scopes: {ModuleCatalog.academics: PermissionScope.own},
      );
      expect(academicPresentationFor(parent), AcademicPresentation.learner);
    });

    test('faculty at section scope get the modules listed separately', () {
      final faculty = grants(
        {'attendance.roster.update', 'academics.marks.update'},
        scopes: {
          ModuleCatalog.attendance: PermissionScope.section,
          ModuleCatalog.academics: PermissionScope.section,
        },
      );
      expect(academicPresentationFor(faculty), AcademicPresentation.staff);
    });

    test('one module above own scope is enough to be staff', () {
      // A student who is also a lab assistant. The presentation follows the
      // authority, not the person.
      final labAssistant = grants(
        {'academics.marks.read', 'attendance.roster.update'},
        scopes: {
          ModuleCatalog.academics: PermissionScope.own,
          ModuleCatalog.attendance: PermissionScope.section,
        },
      );
      expect(academicPresentationFor(labAssistant), AcademicPresentation.staff);
    });

    for (final scope in [
      PermissionScope.department,
      PermissionScope.institution,
    ]) {
      test('$scope scope is staff', () {
        expect(
          academicPresentationFor(
            grants(
              {'academics.marks.read'},
              scopes: {ModuleCatalog.academics: scope},
            ),
          ),
          AcademicPresentation.staff,
        );
      });
    }

    test('an approver is staff even at own scope', () {
      // `scopeFor` answers `own` when a tenant grants a module and forgets its
      // scope. That default is right for data and wrong for presentation, so an
      // approval — which is only ever about someone else's record — overrides
      // it.
      final advisor = grants({'attendance.leave.approve'});
      expect(
        advisor.scopeFor(ModuleCatalog.attendance),
        PermissionScope.own,
        reason: 'unset scope falls back to own',
      );
      expect(academicPresentationFor(advisor), AcademicPresentation.staff);
    });

    test('a publisher is staff even at own scope', () {
      expect(
        academicPresentationFor(grants({'examination.publishing.publish'})),
        AcademicPresentation.staff,
      );
    });

    test('a superadmin wildcard is staff, not a learner', () {
      // `*` sees every module and has no explicit scopes, so the scope test
      // alone would have called the most privileged account in the tenant a
      // student.
      final superadmin = grants({'*'});
      expect(superadmin.scopeFor(ModuleCatalog.academics), PermissionScope.own);
      expect(academicPresentationFor(superadmin), AcademicPresentation.staff);
    });
  });

  group('presented module list', () {
    test('a learner sees one academic entry, not four', () {
      final student = grants(
        {
          'academics.attendance.read',
          'attendance.leave.create',
          'timetable.schedule.read',
          'examination.grades.read',
          'canteen.menu.read',
        },
        scopes: {for (final m in academicModules) m: PermissionScope.own},
      );
      final presented = presentedModules(student).map((m) => m.id).toList();

      expect(
        presented.where(academicModules.contains).length,
        1,
        reason: 'the four academic modules fold into one entry',
      );
      // The folded entry opens the learner workspace, and unrelated modules are
      // untouched by any of this.
      expect(presented, contains(ModuleCatalog.academics));
      expect(presented, contains(ModuleCatalog.canteen));
    });

    test('the folded entry opens somewhere the learner is allowed to be', () {
      // No `academics` grant, so the entry must stand in for one they do hold
      // rather than pointing at a module they cannot open.
      final student = grants(
        {'attendance.leave.create'},
        scopes: {ModuleCatalog.attendance: PermissionScope.own},
      );
      final presented = presentedModules(student).map((m) => m.id).toList();

      expect(presented, [ModuleCatalog.attendance]);
    });

    test('staff keep every academic module as its own entry', () {
      final faculty = grants(
        {
          'attendance.roster.update',
          'timetable.schedule.read',
          'examination.marks.create',
        },
        scopes: {for (final m in academicModules) m: PermissionScope.section},
      );
      final presented = presentedModules(faculty).map((m) => m.id).toSet();

      expect(
        presented,
        containsAll(<String>[
          ModuleCatalog.attendance,
          ModuleCatalog.timetable,
          ModuleCatalog.examination,
        ]),
      );
    });

    test('the list keeps catalog order', () {
      final student = grants(
        {'academics.marks.read', 'canteen.menu.read', 'gatepass.outpass.read'},
        scopes: {ModuleCatalog.academics: PermissionScope.own},
      );
      final catalogOrder = [for (final m in ModuleCatalog.all) m.id];
      final presented = presentedModules(student).map((m) => m.id).toList();
      final positions = [for (final id in presented) catalogOrder.indexOf(id)];

      expect(
        positions,
        orderedEquals(List<int>.from(positions)..sort()),
        reason: 'presented modules follow the catalog',
      );
    });
  });

  _cardNamingTests();

  group('module labels', () {
    ModuleDescriptor module(String id) => ModuleCatalog.byId(id)!;

    test('a learner sees one name for all of them', () {
      for (final id in academicModules) {
        expect(
          academicModuleLabel(module(id), AcademicPresentation.learner),
          'Academics',
        );
      }
    });

    test('staff see each module under its own name', () {
      expect(
        academicModuleLabel(
          module(ModuleCatalog.attendance),
          AcademicPresentation.staff,
        ),
        'Attendance',
      );
      expect(
        academicModuleLabel(
          module(ModuleCatalog.timetable),
          AcademicPresentation.staff,
        ),
        'Time Table',
      );
      expect(
        academicModuleLabel(
          module(ModuleCatalog.examination),
          AcademicPresentation.staff,
        ),
        'Examinations',
      );
    });

    test('a non-academic module keeps its catalog name either way', () {
      for (final presentation in AcademicPresentation.values) {
        expect(
          academicModuleLabel(module(ModuleCatalog.canteen), presentation),
          module(ModuleCatalog.canteen).displayName,
        );
      }
    });
  });
}

/// What the person actually reads on the card in front of them — the point of
/// the whole exercise, and the one thing the unit tests above cannot show.
void _cardNamingTests() {
  Future<void> pumpDeck(
    WidgetTester tester,
    EffectivePermissions permissions,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            child: ModuleStack(
              modules: presentedModules(permissions),
              permissions: permissions,
              onOpenModule: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('a learner reads Academics on the card', (tester) async {
    await pumpDeck(
      tester,
      grants(
        {'academics.marks.read', 'attendance.leave.create'},
        scopes: {for (final m in academicModules) m: PermissionScope.own},
      ),
    );

    expect(find.text('Academics'), findsOneWidget);
    expect(find.text('Attendance'), findsNothing);
  });

  testWidgets('faculty read the module its own name', (tester) async {
    await pumpDeck(
      tester,
      grants(
        {'attendance.roster.update'},
        scopes: {ModuleCatalog.attendance: PermissionScope.section},
      ),
    );

    expect(find.text('Attendance'), findsOneWidget);
    expect(find.text('Academics'), findsNothing);
  });

  testWidgets('the timetable is Time Table for staff', (tester) async {
    await pumpDeck(
      tester,
      grants(
        {'timetable.schedule.update'},
        scopes: {ModuleCatalog.timetable: PermissionScope.department},
      ),
    );

    expect(find.text('Time Table'), findsOneWidget);
  });
}
