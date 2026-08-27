import 'effective_permissions.dart';
import 'module_catalog.dart';

/// The modules whose presentation is decided together.
///
/// A learner does not think of attendance, marks, results and the timetable as
/// four places — they are four things they look up about their own studies. So
/// for a learner these fold into one entry, and for anyone with authority over
/// other people's records they stay four separate modules with four names.
const List<String> academicModules = [
  ModuleCatalog.academics,
  ModuleCatalog.attendance,
  ModuleCatalog.examination,
  ModuleCatalog.timetable,
];

/// How the academic modules are shown to one person.
enum AcademicPresentation {
  /// Nothing academic is granted; no entry at all.
  none,

  /// One merged **Academics** entry, with attendance, marks, results and the
  /// timetable inside it.
  learner,

  /// Attendance, Mark records, Time Table and Examinations listed separately.
  staff,
}

/// Which of those a person gets — derived from what they may do, never from
/// what their role is called.
///
/// The test is authority over other people's records, not identity:
///
///  * `own` scope everywhere, no approvals — a learner. Their parent lands here
///    too, holding a far smaller set of grants, which is why a parent needs no
///    branch of its own: the same screen renders the subset they hold.
///  * anything wider, or any `approve`/`publish` — staff.
///
/// A student who is also a lab assistant, with `section` scope on attendance,
/// correctly gets the staff view. The presentation follows the authority.
AcademicPresentation academicPresentationFor(EffectivePermissions permissions) {
  final visible = [
    for (final module in academicModules)
      if (permissions.canSeeModule(module)) module,
  ];
  if (visible.isEmpty) return AcademicPresentation.none;

  // A tenant that grants a module but forgets its scope gets `own` back from
  // `scopeFor` — deliberately, so a misconfiguration under-reaches rather than
  // over-reaches. That default is safe for data and wrong for presentation, so
  // two markers of authority override it. Both mean "acts on other people's
  // records", which no learner ever does.
  if (permissions.canSeeModule('*')) return AcademicPresentation.staff;
  for (final module in visible) {
    final descriptor = ModuleCatalog.byId(module);
    if (descriptor == null) continue;
    for (final feature in descriptor.features) {
      if (permissions.can(module, feature.id, ModuleActions.approve) ||
          permissions.can(module, feature.id, ModuleActions.publish)) {
        return AcademicPresentation.staff;
      }
    }
  }

  final everywhereOwn = visible.every(
    (module) => permissions.scopeFor(module) == PermissionScope.own,
  );
  return everywhereOwn
      ? AcademicPresentation.learner
      : AcademicPresentation.staff;
}

/// The modules to list, with the academic ones folded into a single entry for
/// a learner and left separate for everyone else.
///
/// The folded entry takes the place of the first academic module in catalog
/// order, so the list keeps the order the catalog declares.
List<ModuleDescriptor> presentedModules(EffectivePermissions permissions) {
  final visible = permissions.visibleModules();
  if (academicPresentationFor(permissions) != AcademicPresentation.learner) {
    return visible;
  }

  final presented = <ModuleDescriptor>[];
  var folded = false;
  for (final module in visible) {
    if (!academicModules.contains(module.id)) {
      presented.add(module);
      continue;
    }
    if (folded) continue;
    folded = true;
    presented.add(_learnerEntry(visible));
  }
  return presented;
}

/// Which descriptor stands in for the folded entry: the academics workspace
/// when the learner has it, otherwise whichever academic module they do hold —
/// so the entry always opens somewhere they are allowed to be.
ModuleDescriptor _learnerEntry(List<ModuleDescriptor> visible) {
  for (final module in visible) {
    if (module.id == ModuleCatalog.academics) return module;
  }
  return visible.firstWhere((m) => academicModules.contains(m.id));
}

/// What a module is called for this viewer, resolved from their permissions.
String moduleLabelFor(
  ModuleDescriptor module,
  EffectivePermissions permissions,
) => academicModuleLabel(module, academicPresentationFor(permissions));

/// What a module is called for this viewer.
///
/// A learner never sees a module named Attendance, because attendance is not a
/// place they go — it is one thing they look up inside Academics. Staff keep
/// the individual names, which is what they navigate by.
String academicModuleLabel(
  ModuleDescriptor module,
  AcademicPresentation presentation,
) {
  if (presentation != AcademicPresentation.staff &&
      academicModules.contains(module.id)) {
    return 'Academics';
  }
  return switch (module.id) {
    ModuleCatalog.attendance => 'Attendance',
    ModuleCatalog.examination => 'Examinations',
    ModuleCatalog.timetable => 'Time Table',
    _ => module.displayName,
  };
}
