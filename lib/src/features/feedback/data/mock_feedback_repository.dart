import 'feedback_models.dart';
import 'feedback_repository.dart';

class MockFeedbackRepository implements FeedbackRepository {
  MockFeedbackRepository({required String submitterName, required String email})
    : _submitterName = submitterName,
      _email = email;

  final String _submitterName;
  final String _email;
  FeedbackStore? _store;

  static const _statutoryTerms = [
    'ragging',
    'harassment',
    'posh',
    'sexual',
    'threat',
    'assault',
  ];

  @override
  Future<FeedbackStore> loadStore() async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return _store ??= _seedStore();
  }

  @override
  Future<FeedbackTicket> submitFeedback(FeedbackDraft draft) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    final normalized = _normalizeDraft(draft);
    _validateDraft(normalized);

    final store = await loadStore();
    final submittedAt = DateTime.now();
    final ticket = FeedbackTicket(
      id: 'FB-${submittedAt.millisecondsSinceEpoch.toString().substring(7)}',
      from: normalized.from,
      to: normalized.to,
      category: normalized.category,
      subject: normalized.subject.trim(),
      description: normalized.description.trim(),
      isAnonymous: normalized.isAnonymous,
      status: normalized.category.createsTicket
          ? FeedbackStatus.open
          : FeedbackStatus.logged,
      owner: _resolveOwner(normalized),
      escalationOwner: _resolveEscalation(normalized),
      submittedAt: submittedAt,
      slaDueAt: normalized.category.sla == null
          ? null
          : submittedAt.add(normalized.category.sla!),
      resolvedAt: normalized.category.createsTicket ? null : submittedAt,
      rating: normalized.rating,
      naacRelevant: normalized.category.naacRelevant,
      auditIdentity: normalized.isAnonymous ? _email : null,
      parentNotify: normalized.parentNotify,
    );

    final tickets = _withPatternRisk([ticket, ...store.tickets]);
    _store = store.copyWith(tickets: tickets);
    return ticket;
  }

  @override
  Future<FeedbackTicket> acknowledgeTicket(String ticketId) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final store = await loadStore();
    final ticket = _findTicket(store, ticketId);
    if (ticket.status == FeedbackStatus.closed ||
        ticket.status == FeedbackStatus.logged) {
      throw const FeedbackException('This item does not need acknowledgement.');
    }
    final updated = ticket.copyWith(
      status: FeedbackStatus.inProgress,
      acknowledgedAt: DateTime.now(),
    );
    _replace(updated);
    return updated;
  }

  @override
  Future<FeedbackTicket> resolveTicket(
    String ticketId, {
    required int rating,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 360));
    if (rating < 1 || rating > 5) {
      throw const FeedbackException('Rating must be between 1 and 5.');
    }
    final store = await loadStore();
    final ticket = _findTicket(store, ticketId);
    if (ticket.isStatutory && rating < 5) {
      throw const FeedbackException(
        'Statutory closure requires committee sign-off.',
      );
    }
    final updated = ticket.copyWith(
      status: rating < 3 ? FeedbackStatus.reopened : FeedbackStatus.closed,
      resolvedAt: DateTime.now(),
      rating: rating,
    );
    _replace(updated);
    return updated;
  }

  @override
  Future<FeedbackTicket> reopenTicket(String ticketId) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final store = await loadStore();
    final ticket = _findTicket(store, ticketId);
    if (ticket.status != FeedbackStatus.resolved &&
        ticket.status != FeedbackStatus.closed) {
      throw const FeedbackException('Only resolved tickets can be reopened.');
    }
    final updated = ticket.copyWith(
      status: FeedbackStatus.reopened,
      owner: ticket.escalationOwner,
    );
    _replace(updated);
    return updated;
  }

  FeedbackDraft _normalizeDraft(FeedbackDraft draft) {
    final content = '${draft.subject} ${draft.description}'.toLowerCase();
    final statutory = _statutoryTerms.any(content.contains);
    if (statutory) {
      return FeedbackDraft(
        from: draft.from,
        to: FeedbackTarget.statutoryCommittee,
        category: FeedbackCategory.statutory,
        subject: draft.subject,
        description: draft.description,
        isAnonymous: true,
        rating: draft.rating,
        parentNotify: draft.parentNotify,
        aboutOwner: draft.aboutOwner,
      );
    }
    return draft;
  }

  void _validateDraft(FeedbackDraft draft) {
    if (draft.subject.trim().length < 5) {
      throw const FeedbackException('Add a clear subject.');
    }
    if (draft.description.trim().length < 12) {
      throw const FeedbackException('Add more detail before submitting.');
    }
    if (draft.isAnonymous && !draft.category.allowsAnonymity) {
      throw FeedbackException(
        '${draft.category.label} cannot be submitted anonymously.',
      );
    }
  }

  String _resolveOwner(FeedbackDraft draft) {
    if (draft.category == FeedbackCategory.statutory) {
      return FeedbackCategory.statutory.defaultOwner;
    }
    if (draft.aboutOwner) {
      return draft.category.escalationOwner;
    }
    if (draft.from == FeedbackStakeholder.student &&
        draft.to == FeedbackTarget.faculty) {
      return 'HOD - aggregated faculty feedback';
    }
    if (draft.from == FeedbackStakeholder.hosteller &&
        draft.to == FeedbackTarget.warden) {
      return 'Warden';
    }
    if (draft.from == FeedbackStakeholder.faculty &&
        draft.to == FeedbackTarget.student) {
      return draft.parentNotify ? 'Student + Parent' : 'Student';
    }
    return draft.category.defaultOwner;
  }

  String _resolveEscalation(FeedbackDraft draft) {
    if (draft.category == FeedbackCategory.statutory) {
      return FeedbackCategory.statutory.escalationOwner;
    }
    return draft.category.escalationOwner;
  }

  FeedbackTicket _findTicket(FeedbackStore store, String ticketId) {
    return store.tickets.firstWhere(
      (ticket) => ticket.id == ticketId,
      orElse: () => throw const FeedbackException('Ticket not found.'),
    );
  }

  void _replace(FeedbackTicket updated) {
    final store = _store;
    if (store == null) return;
    final tickets = store.tickets
        .map((ticket) => ticket.id == updated.id ? updated : ticket)
        .toList();
    _store = store.copyWith(tickets: _withPatternRisk(tickets));
  }

  List<FeedbackTicket> _withPatternRisk(List<FeedbackTicket> tickets) {
    final now = DateTime.now();
    return tickets.map((ticket) {
      final similarCount = tickets
          .where(
            (item) =>
                item.category == ticket.category &&
                item.to == ticket.to &&
                now.difference(item.submittedAt).inDays <= 30,
          )
          .length;
      return ticket.copyWith(patternRisk: similarCount >= 3);
    }).toList();
  }

  FeedbackStore _seedStore() {
    final now = DateTime.now();
    final tickets = [
      FeedbackTicket(
        id: 'FB-240810',
        from: FeedbackStakeholder.student,
        to: FeedbackTarget.serviceDepartment,
        category: FeedbackCategory.service,
        subject: 'Library counter response time',
        description: 'The issue desk response was prompt during exam week.',
        isAnonymous: true,
        status: FeedbackStatus.logged,
        owner: 'Library Head',
        escalationOwner: 'Admin',
        submittedAt: now.subtract(const Duration(days: 1)),
        resolvedAt: now.subtract(const Duration(days: 1)),
        rating: 4,
        naacRelevant: true,
        auditIdentity: _email,
      ),
      FeedbackTicket(
        id: 'FB-240806',
        from: FeedbackStakeholder.hosteller,
        to: FeedbackTarget.warden,
        category: FeedbackCategory.generalGrievance,
        subject: 'Repeated water outage in B block',
        description: 'Bathrooms on floors two and three lose water nightly.',
        isAnonymous: true,
        status: FeedbackStatus.inProgress,
        owner: 'Warden',
        escalationOwner: 'Hostel Admin / Principal',
        submittedAt: now.subtract(const Duration(hours: 20)),
        slaDueAt: now.add(const Duration(hours: 28)),
        acknowledgedAt: now.subtract(const Duration(hours: 18)),
        auditIdentity: _email,
        naacRelevant: false,
      ),
      FeedbackTicket(
        id: 'FB-240801',
        from: FeedbackStakeholder.student,
        to: FeedbackTarget.hod,
        category: FeedbackCategory.academicGrievance,
        subject: 'Internal marks correction pending',
        description: 'Lab internal marks uploaded for batch C need review.',
        isAnonymous: true,
        status: FeedbackStatus.escalated,
        owner: 'Dean / Principal',
        escalationOwner: 'Dean / Principal',
        submittedAt: now.subtract(const Duration(days: 5)),
        slaDueAt: now.subtract(const Duration(days: 2)),
        acknowledgedAt: now.subtract(const Duration(days: 4)),
        naacRelevant: true,
        auditIdentity: _email,
      ),
      FeedbackTicket(
        id: 'FB-240728',
        from: FeedbackStakeholder.employer,
        to: FeedbackTarget.placementCell,
        category: FeedbackCategory.institutional,
        subject: 'Curriculum analytics gap',
        description: 'Graduates need stronger dashboard storytelling practice.',
        isAnonymous: true,
        status: FeedbackStatus.logged,
        owner: 'IQAC',
        escalationOwner: 'IQAC',
        submittedAt: now.subtract(const Duration(days: 12)),
        resolvedAt: now.subtract(const Duration(days: 12)),
        rating: 3,
        naacRelevant: true,
        auditIdentity: _email,
      ),
      FeedbackTicket(
        id: 'FB-240725',
        from: FeedbackStakeholder.student,
        to: FeedbackTarget.statutoryCommittee,
        category: FeedbackCategory.statutory,
        subject: 'Confidential harassment report',
        description: 'Committee-only confidential intake record.',
        isAnonymous: true,
        status: FeedbackStatus.open,
        owner: 'ICC / Anti-Ragging Committee',
        escalationOwner: 'External statutory body',
        submittedAt: now.subtract(const Duration(hours: 8)),
        slaDueAt: now.add(const Duration(hours: 16)),
        auditIdentity: _email,
        naacRelevant: false,
      ),
    ];
    return FeedbackStore(
      submitter: FeedbackSubmitter(
        name: _submitterName,
        email: _email,
        role: FeedbackStakeholder.student,
        department: 'AIDS',
      ),
      tickets: _withPatternRisk(tickets),
      routingRules: const [
        FeedbackRoutingRule(
          from: FeedbackStakeholder.student,
          to: FeedbackTarget.faculty,
          category: FeedbackCategory.service,
          owner: 'HOD',
          escalation: 'IQAC / Dean',
        ),
        FeedbackRoutingRule(
          from: FeedbackStakeholder.hosteller,
          to: FeedbackTarget.warden,
          category: FeedbackCategory.generalGrievance,
          owner: 'Warden',
          escalation: 'Hostel Admin / Principal',
        ),
        FeedbackRoutingRule(
          from: FeedbackStakeholder.parent,
          to: FeedbackTarget.faculty,
          category: FeedbackCategory.academicGrievance,
          owner: 'Class Advisor',
          escalation: 'HOD',
        ),
        FeedbackRoutingRule(
          from: FeedbackStakeholder.staff,
          to: FeedbackTarget.hr,
          category: FeedbackCategory.generalGrievance,
          owner: 'HR',
          escalation: 'Management',
        ),
        FeedbackRoutingRule(
          from: FeedbackStakeholder.alumni,
          to: FeedbackTarget.institution,
          category: FeedbackCategory.institutional,
          owner: 'IQAC',
          escalation: 'Principal',
        ),
      ],
      analytics: const FeedbackAnalytics(
        totalSubmissions: 0,
        openTickets: 0,
        escalatedTickets: 0,
        statutoryTickets: 0,
        averageRating: 0,
        naacExportable: 0,
        patternRisks: 0,
      ),
    ).copyWith(tickets: tickets);
  }
}
