import '../../features/authentication/data/auth_repository.dart';
import 'effective_permissions.dart';
import 'module_catalog.dart';
import 'permissions_repository.dart';

/// Stand-in for the admin console's permissions endpoint.
///
/// The payloads below are written in the same nested shape the console
/// emits (role > module > feature > actions, plus scope), so swapping this
/// for an HTTP call is a one-line change in `app.dart` — nothing downstream
/// knows the difference.
class MockPermissionsRepository implements PermissionsRepository {
  const MockPermissionsRepository();

  @override
  Future<EffectivePermissions> loadFor(UserSession session) async {
    await Future<void>.delayed(const Duration(milliseconds: 260));
    return EffectivePermissions.fromJson(_payloadFor(session.role));
  }

  Map<String, dynamic> _payloadFor(UserRole role) => switch (role) {
    UserRole.student => {
      'modules': {
        ModuleCatalog.timetable: {
          'scope': 'own',
          'features': {
            'schedule': ['read'],
            'publication': ['read'],
          },
        },
        ModuleCatalog.attendance: {
          'scope': 'own',
          'features': {
            'swipe': ['read'],
            'leave': ['create', 'read'],
          },
        },
        ModuleCatalog.canteen: {
          'scope': 'own',
          'features': {
            'menu': ['read'],
            'order': ['create', 'read', 'update'],
            'wallet': ['read', 'update'],
          },
        },
        ModuleCatalog.gatepass: {
          'scope': 'own',
          'features': {
            'outpass': ['create', 'read'],
            'visitor': ['create', 'read'],
          },
        },
        ModuleCatalog.tuitionFee: {
          'scope': 'own',
          'features': {
            'invoice': ['read'],
            'payment': ['create', 'read'],
          },
        },
      },
    },
    UserRole.staff => {
      'modules': {
        ModuleCatalog.timetable: {
          'scope': 'section',
          'features': {
            'schedule': ['read'],
            'substitution': ['create', 'read'],
          },
        },
        ModuleCatalog.attendance: {
          'scope': 'section',
          'features': {
            'roster': ['read', 'update'],
            'swipe': ['create', 'read'],
            'leave': ['read', 'approve'],
          },
        },
        ModuleCatalog.canteen: {
          'scope': 'own',
          'features': {
            'menu': ['read'],
            'order': ['create', 'read'],
            'wallet': ['read', 'update'],
          },
        },
      },
    },
    UserRole.timetableAllocator => {
      'modules': {
        ModuleCatalog.timetable: {
          'scope': 'institution',
          'features': {
            'schedule': ['create', 'read', 'update', 'delete'],
            'config': ['create', 'read', 'update'],
            'substitution': ['create', 'read', 'approve'],
            'publication': ['read', 'approve', 'publish'],
          },
        },
        ModuleCatalog.attendance: {
          'scope': 'institution',
          'features': {
            'roster': ['read'],
            'leave': ['read', 'approve'],
          },
        },
        ModuleCatalog.academics: {
          'scope': 'institution',
          'features': {
            'programme': ['create', 'read', 'update'],
            'subject': ['create', 'read', 'update'],
          },
        },
      },
    },
    UserRole.security => {
      'modules': {
        ModuleCatalog.gatepass: {
          'scope': 'institution',
          'features': {
            'outpass': ['read', 'update'],
            'visitor': ['create', 'read'],
            'access': ['read', 'update'],
          },
        },
      },
    },
    UserRole.parent => {
      'modules': {
        ModuleCatalog.timetable: {
          'scope': 'own',
          'features': {
            'schedule': ['read'],
          },
        },
        ModuleCatalog.gatepass: {
          'scope': 'own',
          'features': {
            'outpass': ['read', 'approve'],
            'visitor': ['create', 'read'],
          },
        },
        ModuleCatalog.attendance: {
          'scope': 'own',
          'features': {
            'swipe': ['read'],
            'leave': ['read'],
          },
        },
      },
    },
  };
}
