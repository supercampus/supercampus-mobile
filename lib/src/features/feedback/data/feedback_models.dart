enum FeedbackStakeholder {
  student,
  hosteller,
  parent,
  faculty,
  staff,
  alumni,
  employer,
}

extension FeedbackStakeholderLabel on FeedbackStakeholder {
  String get label => switch (this) {
    FeedbackStakeholder.student => 'Student',
    FeedbackStakeholder.hosteller => 'Hosteller',
    FeedbackStakeholder.parent => 'Parent',
    FeedbackStakeholder.faculty => 'Faculty',
    FeedbackStakeholder.staff => 'Staff',
    FeedbackStakeholder.alumni => 'Alumni',
    FeedbackStakeholder.employer => 'Employer',
  };
}

enum FeedbackCategory {
  service,
  generalGrievance,
  academicGrievance,
  statutory,
  institutional,
}

extension FeedbackCategoryLabel on FeedbackCategory {
  String get label => switch (this) {
    FeedbackCategory.service => 'Service feedback',
    FeedbackCategory.generalGrievance => 'General grievance',
    FeedbackCategory.academicGrievance => 'Academic grievance',
    FeedbackCategory.statutory => 'Statutory',
    FeedbackCategory.institutional => 'Institutional feedback',
  };

  String get defaultOwner => switch (this) {
    FeedbackCategory.service => 'Department Head',
    FeedbackCategory.generalGrievance => 'Grievance Cell',
    FeedbackCategory.academicGrievance => 'HOD',
    FeedbackCategory.statutory => 'ICC / Anti-Ragging Committee',
    FeedbackCategory.institutional => 'IQAC',
  };

  String get escalationOwner => switch (this) {
    FeedbackCategory.service => 'Admin',
    FeedbackCategory.generalGrievance => 'Admin / Principal',
    FeedbackCategory.academicGrievance => 'Dean / Principal',
    FeedbackCategory.statutory => 'External statutory body',
    FeedbackCategory.institutional => 'IQAC',
  };

  bool get allowsAnonymity => switch (this) {
    FeedbackCategory.service => false,
    FeedbackCategory.generalGrievance => true,
    FeedbackCategory.academicGrievance => false,
    FeedbackCategory.statutory => true,
    FeedbackCategory.institutional => true,
  };

  bool get requiresAnonymity => this == FeedbackCategory.statutory;

  bool get createsTicket =>
      this != FeedbackCategory.service &&
      this != FeedbackCategory.institutional;

  bool get naacRelevant =>
      this == FeedbackCategory.service ||
      this == FeedbackCategory.institutional ||
      this == FeedbackCategory.academicGrievance;

  Duration? get sla => switch (this) {
    FeedbackCategory.service => const Duration(days: 5),
    FeedbackCategory.generalGrievance => const Duration(hours: 48),
    FeedbackCategory.academicGrievance => const Duration(hours: 72),
    FeedbackCategory.statutory => const Duration(hours: 24),
    FeedbackCategory.institutional => null,
  };
}

enum FeedbackTarget {
  faculty,
  hod,
  serviceDepartment,
  adminPrincipal,
  statutoryCommittee,
  warden,
  student,
  hr,
  institution,
  placementCell,
}

extension FeedbackTargetLabel on FeedbackTarget {
  String get label => switch (this) {
    FeedbackTarget.faculty => 'Faculty',
    FeedbackTarget.hod => 'HOD',
    FeedbackTarget.serviceDepartment => 'Service department',
    FeedbackTarget.adminPrincipal => 'Admin / Principal',
    FeedbackTarget.statutoryCommittee => 'ICC / Anti-Ragging Committee',
    FeedbackTarget.warden => 'Warden',
    FeedbackTarget.student => 'Student',
    FeedbackTarget.hr => 'HR',
    FeedbackTarget.institution => 'Institution / IQAC',
    FeedbackTarget.placementCell => 'Placement Cell',
  };
}

enum FeedbackStatus {
  logged,
  open,
  acknowledged,
  inProgress,
  escalated,
  resolved,
  reopened,
  closed,
}

extension FeedbackStatusLabel on FeedbackStatus {
  String get label => switch (this) {
    FeedbackStatus.logged => 'Logged',
    FeedbackStatus.open => 'Open',
    FeedbackStatus.acknowledged => 'Acknowledged',
    FeedbackStatus.inProgress => 'In progress',
    FeedbackStatus.escalated => 'Escalated',
    FeedbackStatus.resolved => 'Resolved',
    FeedbackStatus.reopened => 'Reopened',
    FeedbackStatus.closed => 'Closed',
  };
}

class FeedbackSubmitter {
  const FeedbackSubmitter({
    required this.name,
    required this.email,
    required this.role,
    required this.department,
  });

  final String name;
  final String email;
  final FeedbackStakeholder role;
  final String department;

  String get initials {
    final parts = name.split(' ').where((part) => part.isNotEmpty).toList();
    if (parts.isEmpty) return 'SC';
    return parts.take(2).map((part) => part[0].toUpperCase()).join();
  }
}

class FeedbackDraft {
  const FeedbackDraft({
    required this.from,
    required this.to,
    required this.category,
    required this.subject,
    required this.description,
    required this.isAnonymous,
    this.rating,
    this.parentNotify = false,
    this.aboutOwner = false,
  });

  final FeedbackStakeholder from;
  final FeedbackTarget to;
  final FeedbackCategory category;
  final String subject;
  final String description;
  final bool isAnonymous;
  final int? rating;
  final bool parentNotify;
  final bool aboutOwner;
}

class FeedbackTicket {
  const FeedbackTicket({
    required this.id,
    required this.from,
    required this.to,
    required this.category,
    required this.subject,
    required this.description,
    required this.isAnonymous,
    required this.status,
    required this.owner,
    required this.escalationOwner,
    required this.submittedAt,
    required this.naacRelevant,
    this.slaDueAt,
    this.acknowledgedAt,
    this.resolvedAt,
    this.rating,
    this.patternRisk = false,
    this.auditIdentity,
    this.parentNotify = false,
  });

  final String id;
  final FeedbackStakeholder from;
  final FeedbackTarget to;
  final FeedbackCategory category;
  final String subject;
  final String description;
  final bool isAnonymous;
  final FeedbackStatus status;
  final String owner;
  final String escalationOwner;
  final DateTime submittedAt;
  final DateTime? slaDueAt;
  final DateTime? acknowledgedAt;
  final DateTime? resolvedAt;
  final int? rating;
  final bool patternRisk;
  final bool naacRelevant;
  final String? auditIdentity;
  final bool parentNotify;

  bool get isStatutory => category == FeedbackCategory.statutory;

  bool get isOverdue {
    final dueAt = slaDueAt;
    if (dueAt == null || status == FeedbackStatus.closed) return false;
    return DateTime.now().isAfter(dueAt);
  }

  FeedbackTicket copyWith({
    FeedbackStatus? status,
    String? owner,
    DateTime? acknowledgedAt,
    DateTime? resolvedAt,
    int? rating,
    bool? patternRisk,
  }) {
    return FeedbackTicket(
      id: id,
      from: from,
      to: to,
      category: category,
      subject: subject,
      description: description,
      isAnonymous: isAnonymous,
      status: status ?? this.status,
      owner: owner ?? this.owner,
      escalationOwner: escalationOwner,
      submittedAt: submittedAt,
      slaDueAt: slaDueAt,
      acknowledgedAt: acknowledgedAt ?? this.acknowledgedAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      rating: rating ?? this.rating,
      patternRisk: patternRisk ?? this.patternRisk,
      naacRelevant: naacRelevant,
      auditIdentity: auditIdentity,
      parentNotify: this.parentNotify,
    );
  }
}

class FeedbackRoutingRule {
  const FeedbackRoutingRule({
    required this.from,
    required this.to,
    required this.category,
    required this.owner,
    required this.escalation,
  });

  final FeedbackStakeholder from;
  final FeedbackTarget to;
  final FeedbackCategory category;
  final String owner;
  final String escalation;
}

class FeedbackAnalytics {
  const FeedbackAnalytics({
    required this.totalSubmissions,
    required this.openTickets,
    required this.escalatedTickets,
    required this.statutoryTickets,
    required this.averageRating,
    required this.naacExportable,
    required this.patternRisks,
  });

  final int totalSubmissions;
  final int openTickets;
  final int escalatedTickets;
  final int statutoryTickets;
  final double averageRating;
  final int naacExportable;
  final int patternRisks;
}

class FeedbackStore {
  const FeedbackStore({
    required this.submitter,
    required this.tickets,
    required this.routingRules,
    required this.analytics,
  });

  final FeedbackSubmitter submitter;
  final List<FeedbackTicket> tickets;
  final List<FeedbackRoutingRule> routingRules;
  final FeedbackAnalytics analytics;

  FeedbackStore copyWith({List<FeedbackTicket>? tickets}) {
    final nextTickets = tickets ?? this.tickets;
    return FeedbackStore(
      submitter: submitter,
      tickets: nextTickets,
      routingRules: routingRules,
      analytics: FeedbackAnalytics(
        totalSubmissions: nextTickets.length,
        openTickets: nextTickets
            .where(
              (ticket) =>
                  ticket.status != FeedbackStatus.closed &&
                  ticket.status != FeedbackStatus.logged,
            )
            .length,
        escalatedTickets: nextTickets
            .where((ticket) => ticket.status == FeedbackStatus.escalated)
            .length,
        statutoryTickets: nextTickets
            .where((ticket) => ticket.category == FeedbackCategory.statutory)
            .length,
        averageRating: _averageRating(nextTickets),
        naacExportable: nextTickets
            .where((ticket) => ticket.naacRelevant)
            .length,
        patternRisks: nextTickets.where((ticket) => ticket.patternRisk).length,
      ),
    );
  }

  static double _averageRating(List<FeedbackTicket> tickets) {
    final ratings = tickets
        .map((ticket) => ticket.rating)
        .whereType<int>()
        .toList();
    if (ratings.isEmpty) return 0;
    return ratings.reduce((left, right) => left + right) / ratings.length;
  }
}
