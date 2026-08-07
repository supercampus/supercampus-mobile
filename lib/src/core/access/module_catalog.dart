import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Canonical action codes. Workflow transitions are deliberately their own
/// actions — `update` must never imply `publish`.
abstract final class ModuleActions {
  static const create = 'create';
  static const read = 'read';
  static const update = 'update';
  static const delete = 'delete';
  static const approve = 'approve';
  static const publish = 'publish';
}

/// How much of the data inside a module a grant reaches. Orthogonal to the
/// action codes — faculty and a principal may both hold `read`, over very
/// different row sets.
enum PermissionScope { own, section, department, institution }

extension PermissionScopeX on PermissionScope {
  String get label => switch (this) {
    PermissionScope.own => 'Own records',
    PermissionScope.section => 'Assigned section',
    PermissionScope.department => 'Department',
    PermissionScope.institution => 'Institution',
  };

  static PermissionScope parse(String? raw) => switch (raw) {
    'section' => PermissionScope.section,
    'department' => PermissionScope.department,
    'institution' => PermissionScope.institution,
    _ => PermissionScope.own,
  };
}

/// Whether the client actually has screens for a catalogued module.
/// A grant on a `planned` module renders a "Coming soon" card instead of a
/// dead link — the admin can enable anything without breaking navigation.
enum ModuleStatus { available, preview, planned }

class FeatureDescriptor {
  const FeatureDescriptor({
    required this.id,
    required this.label,
    required this.actions,
  });

  final String id;
  final String label;

  /// The actions this feature *supports*. Grants are a subset of these.
  final Set<String> actions;
}

class ModuleDescriptor {
  const ModuleDescriptor({
    required this.id,
    required this.title,
    required this.tagline,
    required this.icon,
    required this.color,
    required this.features,
    this.shortTitle,
    this.status = ModuleStatus.available,
  });

  final String id;
  final String title;

  /// Set where [title] is too long to read as a single upper-case label.
  final String? shortTitle;

  final String tagline;
  final IconData icon;
  final Color color;
  final List<FeatureDescriptor> features;
  final ModuleStatus status;

  /// What the module is called on compact surfaces.
  String get displayName => shortTitle ?? title;

  FeatureDescriptor? feature(String id) {
    for (final f in features) {
      if (f.id == id) return f;
    }
    return null;
  }
}

/// The catalog ships with the app and describes what SuperCampus *can* do.
/// It is never edited at runtime. Grants — what is actually turned on, per
/// tenant / role / user — arrive from the admin web console and are matched
/// against this list by id.
abstract final class ModuleCatalog {
  static const timetable = 'timetable';
  static const attendance = 'attendance';
  static const canteen = 'canteen';
  static const gatepass = 'gatepass';
  static const tuitionFee = 'tuition_fee';
  static const academics = 'academics';

  static const List<ModuleDescriptor> all = [
    ModuleDescriptor(
      id: timetable,
      title: 'Timetable Management',
      shortTitle: 'Timetable',
      tagline: 'Class schedules, teaching periods and substitutions',
      icon: Icons.table_chart_outlined,
      color: Color(0xFF00695C),
      features: [
        FeatureDescriptor(
          id: 'schedule',
          label: 'Schedule',
          actions: {
            ModuleActions.create,
            ModuleActions.read,
            ModuleActions.update,
            ModuleActions.delete,
          },
        ),
        FeatureDescriptor(
          id: 'config',
          label: 'Configuration',
          actions: {
            ModuleActions.create,
            ModuleActions.read,
            ModuleActions.update,
          },
        ),
        FeatureDescriptor(
          id: 'substitution',
          label: 'Substitutions',
          actions: {
            ModuleActions.create,
            ModuleActions.read,
            ModuleActions.approve,
          },
        ),
        FeatureDescriptor(
          id: 'publication',
          label: 'Publishing',
          actions: {
            ModuleActions.read,
            ModuleActions.approve,
            ModuleActions.publish,
          },
        ),
      ],
    ),
    ModuleDescriptor(
      id: attendance,
      title: 'Attendance',
      tagline: 'Digital swipe attendance, rosters and leave approvals',
      icon: Icons.badge_outlined,
      color: Color(0xFF6A1B9A),
      features: [
        FeatureDescriptor(
          id: 'roster',
          label: 'Roster',
          actions: {ModuleActions.read, ModuleActions.update},
        ),
        FeatureDescriptor(
          id: 'swipe',
          label: 'Swipe log',
          actions: {ModuleActions.create, ModuleActions.read},
        ),
        FeatureDescriptor(
          id: 'leave',
          label: 'Leave',
          actions: {
            ModuleActions.create,
            ModuleActions.read,
            ModuleActions.approve,
          },
        ),
      ],
    ),
    ModuleDescriptor(
      id: canteen,
      title: 'Canteen',
      tagline: 'Browse the menu, pay and track pickup orders',
      icon: Icons.restaurant_outlined,
      color: AppColors.primary,
      features: [
        FeatureDescriptor(
          id: 'menu',
          label: 'Menu',
          actions: {ModuleActions.read, ModuleActions.update},
        ),
        FeatureDescriptor(
          id: 'order',
          label: 'Orders',
          actions: {
            ModuleActions.create,
            ModuleActions.read,
            ModuleActions.update,
          },
        ),
        FeatureDescriptor(
          id: 'wallet',
          label: 'Wallet',
          actions: {ModuleActions.read, ModuleActions.update},
        ),
      ],
    ),
    ModuleDescriptor(
      id: gatepass,
      title: 'Gatepass',
      tagline: 'Outpasses, campus access and visitor invitations',
      icon: Icons.qr_code_2_outlined,
      color: Color(0xFF2455A4),
      features: [
        FeatureDescriptor(
          id: 'outpass',
          label: 'Outpass',
          actions: {
            ModuleActions.create,
            ModuleActions.read,
            ModuleActions.update,
            ModuleActions.approve,
          },
        ),
        FeatureDescriptor(
          id: 'visitor',
          label: 'Visitors',
          actions: {ModuleActions.create, ModuleActions.read},
        ),
        FeatureDescriptor(
          id: 'access',
          label: 'Gate access',
          actions: {ModuleActions.read, ModuleActions.update},
        ),
      ],
    ),
    ModuleDescriptor(
      id: tuitionFee,
      title: 'Tuition Fee',
      tagline: 'Fee structure, dues and payment receipts',
      icon: Icons.account_balance_outlined,
      color: Color(0xFFB25400),
      status: ModuleStatus.planned,
      features: [
        FeatureDescriptor(
          id: 'invoice',
          label: 'Invoices',
          actions: {ModuleActions.read, ModuleActions.create},
        ),
        FeatureDescriptor(
          id: 'payment',
          label: 'Payments',
          actions: {ModuleActions.create, ModuleActions.read},
        ),
      ],
    ),
    ModuleDescriptor(
      id: academics,
      title: 'Academics',
      tagline: 'Programmes, subjects, batches and weekly hours',
      icon: Icons.school_outlined,
      color: Color(0xFF4A4E9C),
      status: ModuleStatus.planned,
      features: [
        FeatureDescriptor(
          id: 'programme',
          label: 'Programmes',
          actions: {
            ModuleActions.create,
            ModuleActions.read,
            ModuleActions.update,
          },
        ),
        FeatureDescriptor(
          id: 'subject',
          label: 'Subjects',
          actions: {
            ModuleActions.create,
            ModuleActions.read,
            ModuleActions.update,
          },
        ),
      ],
    ),
  ];

  static ModuleDescriptor? byId(String id) {
    for (final m in all) {
      if (m.id == id) return m;
    }
    return null;
  }
}
