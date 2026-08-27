import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/core/access/academic_presentation.dart';
import 'package:supercampus_mobile/src/core/access/effective_permissions.dart';
import 'package:supercampus_mobile/src/core/access/module_catalog.dart';

/// /api/v1/bootstrap sends `permissionScopes` keyed by permission, never by
/// module — `access.scopes` on the Rust side is a map of permission key to the
/// broadest scope granted for it. `scopeFor` is asked about a module, so the
/// two have to be reconciled somewhere. They were not, and every lookup missed
/// and fell back to `own`, which presented faculty as learners.
void main() {
  group('scopes keyed by permission fold down to the module', () {
    test('a module takes the broadest scope among its permissions', () {
      final permissions = EffectivePermissions.fromJson(const {
        'grants': ['attendance.roster.read', 'attendance.records.update'],
        'scopes': {
          'attendance.roster.read': 'own',
          'attendance.records.update': 'department',
        },
      });

      expect(
        permissions.scopeFor(ModuleCatalog.attendance),
        PermissionScope.department,
      );
    });

    test('the real faculty payload reads as staff, not as a learner', () {
      // Exactly the shape faculty01@mec.local receives: section scope
      // throughout and not one approve or publish anywhere, so the scope is
      // the only thing that can separate them from a student.
      final faculty = EffectivePermissions.fromJson(const {
        'grants': [
          'academics.marks.read',
          'academics.records.update',
          'attendance.roster.read',
          'attendance.roster.update',
          'attendance.session.create',
        ],
        'scopes': {
          'academics.marks.read': 'assigned',
          'academics.records.update': 'assigned',
          'attendance.roster.read': 'assigned',
          'attendance.roster.update': 'assigned',
          'attendance.session.create': 'assigned',
        },
      });

      expect(faculty.scopeFor(ModuleCatalog.attendance), PermissionScope.section);
      expect(faculty.scopeFor(ModuleCatalog.academics), PermissionScope.section);
      expect(academicPresentationFor(faculty), AcademicPresentation.staff);
    });

    test('a student stays a learner', () {
      final student = EffectivePermissions.fromJson(const {
        'grants': ['academics.marks.read', 'attendance.leave.create'],
        'scopes': {
          'academics.marks.read': 'own',
          'attendance.leave.create': 'own',
        },
      });

      expect(academicPresentationFor(student), AcademicPresentation.learner);
    });

    test('an explicit module scope still wins over a derived one', () {
      // The flat module-keyed form is documented on fromJson and used across
      // the other tests; folding must not quietly override it.
      final permissions = EffectivePermissions.fromJson(const {
        'grants': ['timetable.schedule.read'],
        'scopes': {'timetable': 'own', 'timetable.schedule.read': 'institution'},
      });

      expect(permissions.scopeFor(ModuleCatalog.timetable), PermissionScope.own);
    });

    test('a bare module key is still read as a module scope', () {
      final permissions = EffectivePermissions.fromJson(const {
        'grants': ['timetable.schedule.read'],
        'scopes': {'timetable': 'department'},
      });

      expect(
        permissions.scopeFor(ModuleCatalog.timetable),
        PermissionScope.department,
      );
    });
  });
}
