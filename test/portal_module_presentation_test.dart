import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/core/access/effective_permissions.dart';
import 'package:supercampus_mobile/src/core/access/module_catalog.dart';
import 'package:supercampus_mobile/src/core/access/portal_module_presentation.dart';
import 'package:supercampus_mobile/src/features/authentication/data/auth_repository.dart';

const _canteenAccess = EffectivePermissions(
  grants: {'canteen.menu.read', 'canteen.order.read'},
);

const _gateAccess = EffectivePermissions(
  grants: {'gatepass.access.read', 'gatepass.scan.create'},
);

void main() {
  test(
    'stationery assignment renames only its already-granted shop module',
    () {
      const session = UserSession(
        email: 'stationary@mec.local',
        displayName: 'MEC Stationery',
        role: UserRole.staff,
        roleId: 'stationery_operator',
        roleIds: ['stationery_operator'],
      );

      final modules = portalModules(session, _canteenAccess);

      expect(modules, hasLength(1));
      expect(modules.single.id, ModuleCatalog.canteen);
      expect(modules.single.displayName, 'Stationery');
      expect(
        modules.any((module) => module.id == ModuleCatalog.gatepass),
        false,
      );
    },
  );

  test('canteen operator gets a distinct canteen card from student shops', () {
    const operator = UserSession(
      email: 'akhil@gmail.com',
      displayName: 'Akhil',
      role: UserRole.staff,
      roleId: 'owner',
      roleIds: ['owner'],
    );
    const student = UserSession(
      email: 'student@mec.local',
      displayName: 'Student',
      role: UserRole.student,
    );

    expect(
      portalModules(operator, _canteenAccess).single.displayName,
      'Canteen',
    );
    expect(portalModules(student, _canteenAccess).single.displayName, 'Shops');
  });

  test('security assignment receives only its granted gate module', () {
    const session = UserSession(
      email: 'security@mec.local',
      displayName: 'Gate Security',
      role: UserRole.security,
      roleId: 'security',
      roleIds: ['security'],
    );

    final modules = portalModules(session, _gateAccess);

    expect(modules, hasLength(1));
    expect(modules.single.id, ModuleCatalog.gatepass);
    expect(modules.single.displayName, 'Gate Security');
  });

  test('role labels never create access without a permission grant', () {
    const session = UserSession(
      email: 'librarian@mec.local',
      displayName: 'Librarian',
      role: UserRole.staff,
      roleId: 'librarian',
      roleIds: ['librarian'],
    );

    expect(portalModules(session, const EffectivePermissions.empty()), isEmpty);
  });
}
