class DemoAccessAssignment {
  DemoAccessAssignment({
    required this.userEmail,
    required this.surface,
    required this.moduleId,
    required this.featureId,
    required Set<String> actions,
  }) : actions = {...actions};
  final String userEmail;
  final String surface;
  final String moduleId;
  final String featureId;
  final Set<String> actions;
}

/// Local stand-in for the shared database used by the web admin portal.
/// Replace this store with the web API once the backend endpoint is available.
class DemoAccessControlStore {
  DemoAccessControlStore._();
  static final instance = DemoAccessControlStore._();

  final users = <String>{'abc@example.com'};
  final assignments = <DemoAccessAssignment>[];

  List<DemoAccessAssignment> forUser(String email, {String surface = 'app'}) =>
      assignments
          .where((a) => a.userEmail == email && a.surface == surface)
          .toList();

  void save({
    required String userEmail,
    required String surface,
    required String moduleId,
    required String featureId,
    required Set<String> actions,
  }) {
    users.add(userEmail);
    assignments.removeWhere(
      (a) =>
          a.userEmail == userEmail &&
          a.surface == surface &&
          a.moduleId == moduleId &&
          a.featureId == featureId,
    );
    if (actions.isNotEmpty) {
      assignments.add(
        DemoAccessAssignment(
          userEmail: userEmail,
          surface: surface,
          moduleId: moduleId,
          featureId: featureId,
          actions: actions,
        ),
      );
    }
  }

  void remove(DemoAccessAssignment assignment) =>
      assignments.remove(assignment);

  Map<String, dynamic> effectiveAppPayload(String email) {
    final modules = <String, dynamic>{};
    for (final assignment in forUser(email)) {
      final module =
          modules.putIfAbsent(
                assignment.moduleId,
                () => {'scope': 'own', 'features': <String, dynamic>{}},
              )
              as Map<String, dynamic>;
      final features = module['features'] as Map<String, dynamic>;
      features[assignment.featureId] = [...assignment.actions];
    }
    return {'surface': 'app', 'user': email, 'modules': modules};
  }
}
