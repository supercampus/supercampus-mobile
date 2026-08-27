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
    'all' => PermissionScope.institution,
    'assigned' => PermissionScope.section,
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
    this.keywords = const [],
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

  /// Other names people search for this module by.
  ///
  /// A module can be renamed without the people using it renaming it too — the
  /// shops were the canteen for years — so search keeps answering to the old
  /// word as well as the new one.
  final List<String> keywords;

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
  static const examination = 'examination';
  static const timetable = 'timetable';
  static const attendance = 'attendance';
  static const canteen = 'canteen';
  static const gatepass = 'gatepass';
  static const library = 'library';
  static const vendorManagement = 'vendor_management';
  static const tuitionFee = 'tuition_fee';
  static const academics = 'academics';
  static const hostel = 'hostel';

  static const List<ModuleDescriptor> all = [
    ModuleDescriptor(
      id: examination,
      title: 'Examination System',
      shortTitle: 'Examinations',
      tagline:
          'End-to-end exam lifecycle, marks entry, moderation & transcripts',
      icon: Icons.assignment_outlined,
      color: Color(0xFF1B5E20),
      features: [
        FeatureDescriptor(
          id: 'dashboard',
          label: 'Dashboard',
          actions: {ModuleActions.read},
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
          id: 'scheduling',
          label: 'Scheduling',
          actions: {
            ModuleActions.create,
            ModuleActions.read,
            ModuleActions.update,
            ModuleActions.publish,
          },
        ),
        FeatureDescriptor(
          id: 'eligibility',
          label: 'Eligibility',
          actions: {ModuleActions.read, ModuleActions.approve},
        ),
        FeatureDescriptor(
          id: 'conduct',
          label: 'Conduct & Incident',
          actions: {
            ModuleActions.create,
            ModuleActions.read,
            ModuleActions.update,
          },
        ),
        FeatureDescriptor(
          id: 'marks',
          label: 'Marks Entry',
          actions: {
            ModuleActions.create,
            ModuleActions.read,
            ModuleActions.update,
          },
        ),
        FeatureDescriptor(
          id: 'moderation',
          label: 'Moderation',
          actions: {
            ModuleActions.read,
            ModuleActions.approve,
            ModuleActions.update,
          },
        ),
        FeatureDescriptor(
          id: 'grades',
          label: 'Grades & GPA',
          actions: {ModuleActions.read, ModuleActions.approve},
        ),
        FeatureDescriptor(
          id: 'degree_audit',
          label: 'Degree Audit',
          actions: {ModuleActions.read, ModuleActions.approve},
        ),
        FeatureDescriptor(
          id: 'publishing',
          label: 'Result Publishing',
          actions: {
            ModuleActions.read,
            ModuleActions.approve,
            ModuleActions.publish,
          },
        ),
        FeatureDescriptor(
          id: 'revaluation',
          label: 'Revaluation',
          actions: {
            ModuleActions.create,
            ModuleActions.read,
            ModuleActions.update,
          },
        ),
        FeatureDescriptor(
          id: 'transcript',
          label: 'Transcripts',
          actions: {ModuleActions.read, ModuleActions.create},
        ),
        FeatureDescriptor(
          id: 'ai_insights',
          label: 'AI Exam Insights',
          actions: {ModuleActions.read},
        ),
        FeatureDescriptor(
          id: 'reports',
          label: 'Reports & Analytics',
          actions: {ModuleActions.read},
        ),
      ],
    ),
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
        // `reports`, plural, and no `read`: these are the keys that actually
        // exist in authz.permission_definitions. A feature id the authorization
        // tables have never heard of can never be granted, so it would have
        // hidden the button forever without anyone seeing an error.
        FeatureDescriptor(
          id: 'reports',
          label: 'Reports',
          actions: {ModuleActions.create, ModuleActions.publish},
        ),
      ],
    ),
    ModuleDescriptor(
      id: canteen,
      title: 'Shops',
      tagline: 'Classic, Bites and Stationery — browse, pay and track orders',
      keywords: ['canteen', 'food', 'mess', 'snacks', 'stationery', 'store'],
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
      id: library,
      title: 'Library',
      tagline: 'Time-bound QR passes, capacity and library visit history',
      icon: Icons.local_library_outlined,
      color: Color(0xFF7B3F98),
      status: ModuleStatus.available,
      features: [
        FeatureDescriptor(
          id: 'visit_pass',
          label: 'Visit pass booking',
          actions: {ModuleActions.create, ModuleActions.read},
        ),
        FeatureDescriptor(
          id: 'qr_pass',
          label: 'Library QR pass',
          actions: {ModuleActions.read},
        ),
        FeatureDescriptor(
          id: 'visit_history',
          label: 'Visit history',
          actions: {ModuleActions.read},
        ),
        FeatureDescriptor(
          id: 'occupancy',
          label: 'Occupancy and capacity',
          actions: {ModuleActions.read},
        ),
      ],
    ),
    ModuleDescriptor(
      id: vendorManagement,
      title: 'Vendor Management',
      shortTitle: 'Vendors',
      tagline: 'Vendors, contracts, purchase orders, payments and work orders',
      icon: Icons.handshake_outlined,
      color: Color(0xFF8A4B20),
      status: ModuleStatus.available,
      features: [
        FeatureDescriptor(
          id: 'vendors',
          label: 'Vendor directory',
          actions: {
            ModuleActions.create,
            ModuleActions.read,
            ModuleActions.update,
          },
        ),
        FeatureDescriptor(
          id: 'contracts',
          label: 'Contracts and AMCs',
          actions: {
            ModuleActions.create,
            ModuleActions.read,
            ModuleActions.update,
          },
        ),
        FeatureDescriptor(
          id: 'purchase_orders',
          label: 'Purchase orders',
          actions: {
            ModuleActions.create,
            ModuleActions.read,
            ModuleActions.approve,
          },
        ),
        FeatureDescriptor(
          id: 'payments',
          label: 'Payments and history',
          actions: {
            ModuleActions.create,
            ModuleActions.read,
            ModuleActions.approve,
          },
        ),
        FeatureDescriptor(
          id: 'work_orders',
          label: 'Work orders',
          actions: {
            ModuleActions.create,
            ModuleActions.read,
            ModuleActions.update,
          },
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
      status: ModuleStatus.available,
      features: [
        FeatureDescriptor(
          id: 'attendance',
          label: 'Attendance',
          actions: {ModuleActions.read},
        ),
        FeatureDescriptor(
          id: 'marks',
          label: 'Marks',
          actions: {ModuleActions.read},
        ),
        FeatureDescriptor(
          id: 'analysis',
          label: 'Analysis',
          actions: {ModuleActions.read},
        ),
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
        // A learner picks; an advisor sees the section's picks; a head settles
        // the ones that contend for the same seat.
        FeatureDescriptor(
          id: 'elective',
          label: 'Electives',
          actions: {
            ModuleActions.create,
            ModuleActions.read,
            ModuleActions.update,
            ModuleActions.approve,
          },
        ),
        FeatureDescriptor(
          id: 'registration',
          label: 'Registration',
          actions: {
            ModuleActions.create,
            ModuleActions.read,
            ModuleActions.update,
            ModuleActions.approve,
          },
        ),
        // What makes a class advisor an advisor rather than another lecturer:
        // notes kept about the students in their section, and the formal
        // warnings that follow when attendance or marks fall short.
        FeatureDescriptor(
          id: 'mentoring',
          label: 'Mentoring',
          actions: {
            ModuleActions.create,
            ModuleActions.read,
            ModuleActions.update,
          },
        ),
        FeatureDescriptor(
          id: 'warning',
          label: 'Warnings',
          actions: {
            ModuleActions.create,
            ModuleActions.read,
            ModuleActions.approve,
          },
        ),
        FeatureDescriptor(
          id: 'progress',
          label: 'Progress',
          actions: {ModuleActions.read},
        ),
        // Deliberately narrow, and the only academic feature finance holds: the
        // derived signals a fee decision needs — attendance percentage, arrears,
        // result status — and never the per-session log behind them.
        FeatureDescriptor(
          id: 'eligibility',
          label: 'Eligibility',
          actions: {ModuleActions.read},
        ),
      ],
    ),
    ModuleDescriptor(
      id: hostel,
      title: 'Hostel Management',
      shortTitle: 'Hostel',
      tagline:
          'Residency lifecycle, outpass, room allotment, mess and clearance',
      icon: Icons.night_shelter_outlined,
      color: Color(0xFF2E4057),
      status: ModuleStatus.available,
      features: [
        FeatureDescriptor(
          id: 'residency',
          label: 'Hostel Residency',
          actions: {
            ModuleActions.read,
            ModuleActions.create,
            ModuleActions.update,
          },
        ),
        FeatureDescriptor(
          id: 'application',
          label: 'Accommodation Application',
          actions: {
            ModuleActions.create,
            ModuleActions.read,
            ModuleActions.approve,
          },
        ),
        FeatureDescriptor(
          id: 'inventory',
          label: 'Inventory & Bed Allotment',
          actions: {
            ModuleActions.read,
            ModuleActions.update,
            ModuleActions.create,
          },
        ),
        FeatureDescriptor(
          id: 'outpass',
          label: 'Leave & Outpass',
          actions: {
            ModuleActions.create,
            ModuleActions.read,
            ModuleActions.approve,
            ModuleActions.update,
          },
        ),
        FeatureDescriptor(
          id: 'movement',
          label: 'Movement & Gate Logging',
          actions: {
            ModuleActions.create,
            ModuleActions.read,
            ModuleActions.update,
          },
        ),
        FeatureDescriptor(
          id: 'mess',
          label: 'Mess & Meal Pass',
          actions: {ModuleActions.read, ModuleActions.update},
        ),
        FeatureDescriptor(
          id: 'complaints',
          label: 'Complaints & Maintenance',
          actions: {
            ModuleActions.create,
            ModuleActions.read,
            ModuleActions.update,
          },
        ),
        FeatureDescriptor(
          id: 'room_change',
          label: 'Room Change',
          actions: {
            ModuleActions.create,
            ModuleActions.read,
            ModuleActions.approve,
          },
        ),
        FeatureDescriptor(
          id: 'visitors',
          label: 'Visitor Pass',
          actions: {
            ModuleActions.create,
            ModuleActions.read,
            ModuleActions.approve,
          },
        ),
        FeatureDescriptor(
          id: 'clearance',
          label: 'Vacating & Clearance',
          actions: {
            ModuleActions.create,
            ModuleActions.read,
            ModuleActions.approve,
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
