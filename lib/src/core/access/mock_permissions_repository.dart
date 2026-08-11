import '../../features/authentication/data/auth_repository.dart';
import 'effective_permissions.dart';
import 'module_catalog.dart';
import 'demo_access_control_store.dart';
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
    final store = DemoAccessControlStore.instance;
    if (store.users.contains(session.email)) {
      return EffectivePermissions.fromJson(
        store.effectiveAppPayload(session.email),
      );
    }
    return EffectivePermissions.fromJson(_payloadFor(session.role));
  }

  Map<String, dynamic> _payloadFor(UserRole role) => switch (role) {
    UserRole.admin => _payloadFor(UserRole.timetableAllocator),
    UserRole.student => {
      'modules': {
        ModuleCatalog.timetable: {
          'scope': 'own',
          'features': {
            'schedule': ['read'],
            'publication': ['read'],
          },
        },
        ModuleCatalog.academics: {
          'scope': 'own',
          'features': {
            'attendance': ['read'],
            'marks': ['read'],
            'analysis': ['read'],
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
        ModuleCatalog.library: {
          'scope': 'own',
          'features': {
            'visit_pass': ['create', 'read'],
            'qr_pass': ['read'],
            'visit_history': ['read'],
          },
        },
        ModuleCatalog.examination: {
          'scope': 'own',
          'features': {
            'dashboard': ['read'],
            'eligibility': ['read'],
            'publishing': ['read'],
            'revaluation': ['create', 'read'],
            'transcript': ['read'],
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
        ModuleCatalog.examination: {
          'scope': 'department',
          'features': {
            'dashboard': ['read'],
            'marks': ['create', 'read', 'update'],
            'moderation': ['read', 'approve'],
            'conduct': ['create', 'read', 'update'],
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
        ModuleCatalog.examination: {
          'scope': 'institution',
          'features': {
            'dashboard': ['read'],
            'config': ['create', 'read', 'update'],
            'scheduling': ['create', 'read', 'update', 'publish'],
            'eligibility': ['read', 'approve'],
            'conduct': ['create', 'read', 'update'],
            'marks': ['create', 'read', 'update'],
            'moderation': ['read', 'approve', 'update'],
            'grades': ['read', 'approve'],
            'degree_audit': ['read', 'approve'],
            'publishing': ['read', 'approve', 'publish'],
            'revaluation': ['create', 'read', 'update'],
            'transcript': ['read', 'create'],
            'ai_insights': ['read'],
            'reports': ['read'],
          },
        },
        ModuleCatalog.academics: {
          'scope': 'institution',
          'features': {
            'programme': ['create', 'read', 'update'],
            'subject': ['create', 'read', 'update'],
          },
        },
        ModuleCatalog.vendorManagement: {
          'scope': 'institution',
          'features': {
            'vendors': ['create', 'read', 'update'],
            'contracts': ['create', 'read', 'update'],
            'purchase_orders': ['create', 'read', 'approve'],
            'payments': ['create', 'read', 'approve'],
            'work_orders': ['create', 'read', 'update'],
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
