import 'academic_presentation.dart';
import 'effective_permissions.dart';
import 'module_catalog.dart';
import '../../features/authentication/data/auth_repository.dart';

/// The one module projection used by every app portal.
///
/// Access is always decided first by [EffectivePermissions]. Role assignments
/// may only rename an already-granted module so its card describes the work
/// surface the user will open. They never add a module or broaden a scope.
List<ModuleDescriptor> portalModules(
  UserSession session,
  EffectivePermissions permissions,
) {
  final roles = <String>{
    session.roleKey,
    ...session.roleIds,
  }.map((role) => role.trim().toLowerCase()).toSet();

  return [
    for (final module in presentedModules(permissions))
      _portalDescriptor(module, roles),
  ];
}

/// Applies a user's preferred sequence without changing which modules their
/// grants allow. Unknown ids are ignored and newly granted modules are placed
/// after the saved sequence so they can never disappear.
List<ModuleDescriptor> orderModules(
  List<ModuleDescriptor> modules,
  List<String> preferredOrder,
) {
  if (preferredOrder.isEmpty || modules.length < 2) return modules;
  final remaining = {for (final module in modules) module.id: module};
  return [
    for (final id in preferredOrder)
      if (remaining.containsKey(id)) remaining.remove(id)!,
    ...remaining.values,
  ];
}

ModuleDescriptor _portalDescriptor(ModuleDescriptor module, Set<String> roles) {
  if (module.id == ModuleCatalog.canteen) {
    if (roles.contains('accountant')) {
      return _copy(
        module,
        title: 'Student Wallets',
        shortTitle: 'Accounts',
        tagline: 'Wallet credits, balances and transaction records',
      );
    }
    if (roles.contains('stationery_operator')) {
      return _copy(
        module,
        title: 'Stationery Shop',
        shortTitle: 'Stationery',
        tagline: 'Inventory, availability, prices and stationery orders',
      );
    }
    if (roles.any(_isCanteenOperator)) {
      return _copy(
        module,
        title: 'Canteen',
        shortTitle: 'Canteen',
        tagline: 'Menu, live orders and counter operations',
      );
    }
  }

  if (module.id == ModuleCatalog.gatepass) {
    if (roles.contains('security')) {
      return _copy(
        module,
        title: 'Gate Security',
        shortTitle: 'Gate Security',
        tagline: 'Scan passes, verify movement and review gate logs',
      );
    }
    if (roles.any(_isGatepassApprover)) {
      return _copy(
        module,
        title: 'Gatepass Approvals',
        shortTitle: 'Approvals',
        tagline: 'Review only the pass requests assigned to you',
      );
    }
  }

  return module;
}

bool _isCanteenOperator(String role) => const {
  'owner',
  'captain',
  'manager',
  'canteen_owner',
  'canteen_captain',
}.contains(role);

bool _isGatepassApprover(String role) => const {
  'parent',
  'warden',
  'principal',
  'class_advisor',
  'hod',
  'head_of_department',
}.contains(role);

ModuleDescriptor _copy(
  ModuleDescriptor source, {
  required String title,
  required String shortTitle,
  required String tagline,
}) => ModuleDescriptor(
  id: source.id,
  title: title,
  shortTitle: shortTitle,
  tagline: tagline,
  icon: source.icon,
  color: source.color,
  features: source.features,
  keywords: source.keywords,
  status: source.status,
);
