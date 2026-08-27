import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/core/access/academic_presentation.dart';
import 'package:supercampus_mobile/src/core/access/effective_permissions.dart';
import 'package:supercampus_mobile/src/core/access/module_catalog.dart';

/// The personas of ACADEMIC_MANAGEMENT_REQUIREMENTS.md §3, written as the grant
/// bundles a tenant would seed. None of these names exists in the application —
/// they are descriptions of a set of grants, and these tests exist to prove the
/// permission model can tell them apart without ever asking who someone is.
EffectivePermissions persona(
  Set<String> grants, {
  Map<String, PermissionScope> scopes = const {},
}) => EffectivePermissions(grants: grants, scopes: scopes);

const _academics = ModuleCatalog.academics;
const _attendance = ModuleCatalog.attendance;

final faculty = persona(
  {
    'academics.marks.read',
    'academics.marks.update',
    'academics.progress.read',
    'attendance.roster.read',
    'attendance.roster.update',
    'attendance.swipe.create',
  },
  scopes: {
    _academics: PermissionScope.section,
    _attendance: PermissionScope.section,
  },
);

/// An advisor is a faculty role with more on it — §3.2. Not a separate role,
/// which is the entire point of the answer that shaped this.
final classAdvisor = persona(
  {
    ...{
      'academics.marks.read',
      'academics.marks.update',
      'academics.progress.read',
      'attendance.roster.read',
      'attendance.roster.update',
      'attendance.swipe.create',
    },
    'academics.mentoring.create',
    'academics.mentoring.read',
    'academics.mentoring.update',
    'academics.warning.create',
    'academics.warning.read',
    'academics.registration.approve',
    'attendance.leave.approve',
  },
  scopes: {
    _academics: PermissionScope.section,
    _attendance: PermissionScope.section,
  },
);

final accountant = persona(
  {'academics.eligibility.read'},
  scopes: {_academics: PermissionScope.institution},
);

void main() {
  group('the catalog can express every persona', () {
    test('academics declares the features the personas need', () {
      final declared = ModuleCatalog.byId(
        _academics,
      )!.features.map((f) => f.id).toSet();
      expect(
        declared,
        containsAll(<String>[
          'attendance',
          'marks',
          'analysis',
          'programme',
          'subject',
          'elective',
          'registration',
          'mentoring',
          'warning',
          'progress',
          'eligibility',
        ]),
      );
    });

    test('attendance reporting has a key of its own', () {
      final declared = ModuleCatalog.byId(
        _attendance,
      )!.features.map((f) => f.id).toSet();
      // `reports`, matching authz.permission_definitions. The audit caught this
      // as `report` — a key nothing could ever grant.
      expect(declared, contains('reports'));
    });

    test('catalog feature ids match the authz spelling', () {
      // The keys below are the ones authz.permission_definitions actually
      // holds for these two modules. A catalog feature that shares a module
      // with them but differs by a letter is unreachable, silently.
      const authzAttendance = {
        'leave',
        'parent',
        'records',
        'reports',
        'roster',
        'session',
        'swipe',
      };
      final declared = ModuleCatalog.byId(
        _attendance,
      )!.features.map((f) => f.id).toSet();
      expect(
        declared.difference(authzAttendance),
        isEmpty,
        reason: 'attendance features must exist in authz',
      );
    });
  });

  group('class advisor is faculty plus grants, not another role', () {
    test('both read the same subject data at the same reach', () {
      for (final who in [faculty, classAdvisor]) {
        expect(who.can(_academics, 'marks', ModuleActions.update), isTrue);
        expect(who.scopeFor(_academics), PermissionScope.section);
        expect(academicPresentationFor(who), AcademicPresentation.staff);
      }
    });

    test('only the advisor may mentor and warn', () {
      expect(
        faculty.can(_academics, 'mentoring', ModuleActions.create),
        isFalse,
      );
      expect(faculty.can(_academics, 'warning', ModuleActions.create), isFalse);
      expect(faculty.can(_attendance, 'leave', ModuleActions.approve), isFalse);

      expect(
        classAdvisor.can(_academics, 'mentoring', ModuleActions.create),
        isTrue,
      );
      expect(
        classAdvisor.can(_academics, 'warning', ModuleActions.create),
        isTrue,
      );
      expect(
        classAdvisor.can(_attendance, 'leave', ModuleActions.approve),
        isTrue,
      );
    });

    test('the difference is visible as granted features, not as a name', () {
      final module = ModuleCatalog.byId(_academics)!;
      final facultyFeatures = faculty
          .grantedFeatures(module)
          .map((f) => f.id)
          .toSet();
      final advisorFeatures = classAdvisor
          .grantedFeatures(module)
          .map((f) => f.id)
          .toSet();

      expect(advisorFeatures.difference(facultyFeatures), {
        'mentoring',
        'warning',
        'registration',
      });
    });
  });

  group('accountant reads eligibility and nothing behind it', () {
    test('the eligibility signal is readable', () {
      expect(
        accountant.can(_academics, 'eligibility', ModuleActions.read),
        isTrue,
      );
    });

    test('the records the signal is derived from are not', () {
      // §3.7 and §6.3: finance needs to know whether a student is eligible, not
      // every session they missed. Granting `academics.attendance.read` at
      // institution scope would have handed over the whole log.
      expect(
        accountant.can(_academics, 'attendance', ModuleActions.read),
        isFalse,
      );
      expect(accountant.can(_academics, 'marks', ModuleActions.read), isFalse);
      expect(accountant.can(_attendance, 'swipe', ModuleActions.read), isFalse);
    });

    test('institution reach does not make them a learner', () {
      expect(academicPresentationFor(accountant), AcademicPresentation.staff);
    });
  });

  group('a student may ask but not decide', () {
    final student = persona(
      {
        'academics.elective.create',
        'academics.elective.read',
        'academics.registration.create',
        'academics.progress.read',
        'attendance.leave.create',
      },
      scopes: {
        _academics: PermissionScope.own,
        _attendance: PermissionScope.own,
      },
    );

    test('they can raise an elective choice and a leave request', () {
      expect(student.can(_academics, 'elective', ModuleActions.create), isTrue);
      expect(student.can(_attendance, 'leave', ModuleActions.create), isTrue);
    });

    test('they cannot approve either of them', () {
      expect(
        student.can(_academics, 'elective', ModuleActions.approve),
        isFalse,
      );
      expect(
        student.can(_academics, 'registration', ModuleActions.approve),
        isFalse,
      );
      expect(student.can(_attendance, 'leave', ModuleActions.approve), isFalse);
    });

    test('writing a request keeps them a learner', () {
      expect(academicPresentationFor(student), AcademicPresentation.learner);
    });
  });
}
