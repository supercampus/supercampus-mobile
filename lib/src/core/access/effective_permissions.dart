import 'module_catalog.dart';

/// Coarse summary of what a user can do inside a module, derived from the
/// granted action codes. Drives the badge on each dashboard card.
enum AccessLevel { none, readOnly, contribute, full }

extension AccessLevelX on AccessLevel {
  String get label => switch (this) {
    AccessLevel.none => 'No access',
    AccessLevel.readOnly => 'Read only',
    AccessLevel.contribute => 'Create & edit',
    AccessLevel.full => 'Full access',
  };
}

/// The flattened result of resolving tenant enablement, role grants and
/// per-user overrides — §20 of the workflow doc. Built once at sign-in and
/// read synchronously everywhere else; every check is a set lookup.
///
/// Grant keys are `module.feature.action`, e.g. `timetable.schedule.update`.
class EffectivePermissions {
  const EffectivePermissions({
    required Set<String> grants,
    Map<String, PermissionScope> scopes = const {},
    this.tenantBrand = const {},
  }) : _grants = grants,
       _scopes = scopes;

  const EffectivePermissions.empty()
    : _grants = const {},
      _scopes = const {},
      tenantBrand = const {};

  final Set<String> _grants;
  final Map<String, PermissionScope> _scopes;
  final Map<String, dynamic> tenantBrand;

  /// Accepts either shape the admin console may emit.
  ///
  /// Nested (role > module > feature > actions):
  /// ```json
  /// {"modules": {"timetable": {"scope": "institution",
  ///              "features": {"schedule": ["read", "update"]}}}}
  /// ```
  ///
  /// Flat:
  /// ```json
  /// {"grants": ["timetable.schedule.read"], "scopes": {"timetable": "own"}}
  /// ```
  factory EffectivePermissions.fromJson(Map<String, dynamic> json) {
    final grants = <String>{};
    final scopes = <String, PermissionScope>{};

    final modules = json['modules'];
    if (modules is Map) {
      for (final entry in modules.entries) {
        final moduleId = entry.key.toString();
        final body = entry.value;
        if (body is! Map) continue;

        scopes[moduleId] = PermissionScopeX.parse(body['scope'] as String?);

        final features = body['features'];
        if (features is! Map) continue;
        for (final f in features.entries) {
          final featureId = f.key.toString();
          final actions = f.value;
          if (actions is! List) continue;
          for (final action in actions) {
            grants.add('$moduleId.$featureId.$action');
          }
        }
      }
    }

    final flat = json['grants'];
    if (flat is List) {
      for (final g in flat) {
        grants.add(g.toString());
      }
    }

    final flatScopes = json['scopes'];
    if (flatScopes is Map) {
      for (final entry in flatScopes.entries) {
        scopes[entry.key.toString()] = PermissionScopeX.parse(
          entry.value as String?,
        );
      }
    }

    final rawBrand = json['tenantBrand'];
    return EffectivePermissions(
      grants: grants,
      scopes: scopes,
      tenantBrand: rawBrand is Map
          ? Map<String, dynamic>.from(rawBrand)
          : const {},
    );
  }

  /// The single authorization predicate. Everything else is sugar over it.
  bool can(String moduleId, String featureId, String action) {
    final permission = '$moduleId.$featureId.$action';
    return _grants.contains('*') ||
        _grants.contains(permission) ||
        _grants.contains('$moduleId.*') ||
        _grants.contains('$moduleId.$featureId.*');
  }

  bool canSeeModule(String moduleId) =>
      _grants.contains('*') ||
      _grants.contains('$moduleId.*') ||
      _grants.any((g) => g.startsWith('$moduleId.'));

  PermissionScope scopeFor(String moduleId) =>
      _scopes[moduleId] ?? PermissionScope.own;

  /// Actions granted on one feature, ordered as the catalog declares them so
  /// the chips read consistently across roles.
  List<String> grantedActions(String moduleId, FeatureDescriptor feature) {
    final granted = <String>[];
    for (final action in _orderedActions) {
      if (!feature.actions.contains(action)) continue;
      if (can(moduleId, feature.id, action)) granted.add(action);
    }
    return granted;
  }

  /// Features of a module the user holds at least one action on.
  List<FeatureDescriptor> grantedFeatures(ModuleDescriptor module) => [
    for (final f in module.features)
      if (grantedActions(module.id, f).isNotEmpty) f,
  ];

  AccessLevel accessLevel(String moduleId) {
    final prefix = '$moduleId.';
    var writes = false;
    var any = false;
    for (final g in _grants) {
      if (g == '*' || g == '$moduleId.*') return AccessLevel.full;
      if (!g.startsWith(prefix)) continue;
      any = true;
      final action = g.split('.').last;
      if (action == ModuleActions.delete) return AccessLevel.full;
      if (action == ModuleActions.create ||
          action == ModuleActions.update ||
          action == ModuleActions.publish ||
          action == ModuleActions.approve) {
        writes = true;
      }
    }
    if (!any) return AccessLevel.none;
    return writes ? AccessLevel.contribute : AccessLevel.readOnly;
  }

  /// Catalog modules this user may see, in catalog order.
  List<ModuleDescriptor> visibleModules() => [
    for (final m in ModuleCatalog.all)
      if (canSeeModule(m.id)) m,
  ];

  static const _orderedActions = [
    ModuleActions.read,
    ModuleActions.create,
    ModuleActions.update,
    ModuleActions.delete,
    ModuleActions.approve,
    ModuleActions.publish,
  ];
}
