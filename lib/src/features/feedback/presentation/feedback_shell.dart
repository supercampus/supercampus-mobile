import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/module_navigation_buttons.dart';
import '../../../core/widgets/skeleton_loading.dart';
import '../../authentication/data/auth_repository.dart';
import '../data/feedback_models.dart';
import '../data/feedback_repository.dart';
import '../data/mock_feedback_repository.dart';

class FeedbackShell extends StatefulWidget {
  const FeedbackShell({
    super.key,
    required this.session,
    required this.onExitModule,
    this.repository,
  });

  final UserSession session;
  final VoidCallback onExitModule;
  final FeedbackRepository? repository;

  @override
  State<FeedbackShell> createState() => _FeedbackShellState();
}

class _FeedbackShellState extends State<FeedbackShell> {
  late final FeedbackRepository _repository;
  FeedbackStore? _store;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository =
        widget.repository ??
        MockFeedbackRepository(
          submitterName: widget.session.displayName,
          email: widget.session.email,
        );
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final store = await _repository.loadStore();
      if (mounted) setState(() => _store = store);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Feedback services are unavailable.');
      }
    }
  }

  Future<void> _openCreateSheet() async {
    final ticket = await showModalBottomSheet<FeedbackTicket>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.88,
        child: _FeedbackCreateSheet(onSubmit: _submit),
      ),
    );
    if (ticket == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${ticket.id} submitted anonymously.')),
    );
  }

  Future<FeedbackTicket> _submit(FeedbackDraft draft) async {
    final ticket = await _repository.submitFeedback(draft);
    final store = await _repository.loadStore();
    if (mounted) setState(() => _store = store);
    return ticket;
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 40),
              const SizedBox(height: 12),
              Text(_error!),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final store = _store;
    if (store == null) {
      return const Scaffold(body: SkeletonList(rows: 6, rowHeight: 76));
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 100),
              children: [
                _FeedbackHeader(
                  onBack: widget.onExitModule,
                  onHome: widget.onExitModule,
                  onCreate: _openCreateSheet,
                ),
                const SizedBox(height: 18),
                const _AnonymousNotice(),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Text(
                      'Recent intake',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Spacer(),
                    Text('${store.tickets.length} total'),
                  ],
                ),
                const SizedBox(height: 10),
                if (store.tickets.isEmpty)
                  const _EmptyHistory()
                else
                  ...store.tickets.map(
                    (ticket) => _HistoryTile(ticket: ticket),
                  ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateSheet,
        icon: const Icon(Icons.add_comment_outlined),
        label: const Text('Create feedback'),
      ),
    );
  }
}

class _FeedbackHeader extends StatelessWidget {
  const _FeedbackHeader({
    required this.onBack,
    required this.onHome,
    required this.onCreate,
  });

  final VoidCallback onBack;
  final VoidCallback onHome;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ModuleBackButton(onPressed: onBack),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Feedback',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const Text('Create and track anonymous submissions'),
            ],
          ),
        ),
        IconButton.filled(
          tooltip: 'Create feedback',
          onPressed: onCreate,
          icon: const Icon(Icons.add),
        ),
        ModuleHomeButton(onPressed: onHome),
      ],
    );
  }
}

class _AnonymousNotice extends StatelessWidget {
  const _AnonymousNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.visibility_off_outlined, color: AppColors.primary),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Anonymous submission is mandatory. Your identity is hidden from the owner and retained only in the secure audit log.',
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedbackCreateSheet extends StatefulWidget {
  const _FeedbackCreateSheet({required this.onSubmit});

  final Future<FeedbackTicket> Function(FeedbackDraft draft) onSubmit;

  @override
  State<_FeedbackCreateSheet> createState() => _FeedbackCreateSheetState();
}

class _FeedbackCreateSheetState extends State<_FeedbackCreateSheet> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _detailsController = TextEditingController();
  var _category = FeedbackCategory.generalGrievance;
  var _target = FeedbackTarget.serviceDepartment;
  var _submitting = false;

  @override
  void dispose() {
    _subjectController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _submitting) return;
    setState(() => _submitting = true);
    try {
      final ticket = await widget.onSubmit(
        FeedbackDraft(
          from: FeedbackStakeholder.student,
          to: _target,
          category: _category,
          subject: _subjectController.text,
          description: _detailsController.text,
          isAnonymous: true,
        ),
      );
      if (mounted) Navigator.of(context).pop(ticket);
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottom + 20),
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            Row(
              children: [
                Text(
                  'Create feedback',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const _LockedAnonymousField(),
            const SizedBox(height: 14),
            DropdownButtonFormField<FeedbackCategory>(
              value: _category,
              decoration: const InputDecoration(labelText: 'Type'),
              items: const [
                DropdownMenuItem(
                  value: FeedbackCategory.generalGrievance,
                  child: Text('General grievance'),
                ),
                DropdownMenuItem(
                  value: FeedbackCategory.statutory,
                  child: Text('Statutory / harassment'),
                ),
                DropdownMenuItem(
                  value: FeedbackCategory.institutional,
                  child: Text('Suggestion / institutional feedback'),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _category = value;
                  if (value == FeedbackCategory.statutory) {
                    _target = FeedbackTarget.statutoryCommittee;
                  }
                });
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<FeedbackTarget>(
              value: _target,
              decoration: const InputDecoration(labelText: 'Concerned area'),
              items: const [
                DropdownMenuItem(
                  value: FeedbackTarget.serviceDepartment,
                  child: Text('Service department'),
                ),
                DropdownMenuItem(
                  value: FeedbackTarget.faculty,
                  child: Text('Faculty / teaching'),
                ),
                DropdownMenuItem(
                  value: FeedbackTarget.warden,
                  child: Text('Hostel / warden'),
                ),
                DropdownMenuItem(
                  value: FeedbackTarget.adminPrincipal,
                  child: Text('Admin / principal'),
                ),
                DropdownMenuItem(
                  value: FeedbackTarget.statutoryCommittee,
                  child: Text('Statutory committee'),
                ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _target = value);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _subjectController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Subject'),
              validator: (value) => value == null || value.trim().length < 5
                  ? 'Add a short subject.'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _detailsController,
              minLines: 4,
              maxLines: 7,
              decoration: const InputDecoration(labelText: 'Details'),
              validator: (value) => value == null || value.trim().length < 12
                  ? 'Add a few more details.'
                  : null,
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_outlined),
              label: Text(
                _submitting ? 'Submitting' : 'Submit anonymous feedback',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LockedAnonymousField extends StatelessWidget {
  const _LockedAnonymousField();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: const Row(
        children: [
          Icon(Icons.lock_outline, color: AppColors.primary),
          SizedBox(width: 10),
          Expanded(child: Text('Anonymous is mandatory and always enabled')),
          Icon(Icons.check_circle, color: AppColors.success),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.ticket});

  final FeedbackTicket ticket;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _categoryIcon(ticket.category),
                  color: _categoryColor(ticket.category),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    ticket.subject,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _StatusPill(status: ticket.status),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              ticket.description,
              style: Theme.of(context).textTheme.bodyMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoPill(text: ticket.id),
                const _InfoPill(text: 'Anonymous'),
                _InfoPill(text: ticket.category.label),
                _InfoPill(
                  text:
                      '${formatShortDate(ticket.submittedAt)} ${formatTime(ticket.submittedAt)}',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        children: [
          Icon(Icons.history, color: AppColors.muted),
          SizedBox(height: 10),
          Text('No feedback submitted yet.'),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final FeedbackStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      FeedbackStatus.closed => AppColors.success,
      FeedbackStatus.escalated ||
      FeedbackStatus.reopened => const Color(0xFFB42318),
      FeedbackStatus.inProgress ||
      FeedbackStatus.acknowledged => AppColors.primary,
      FeedbackStatus.logged ||
      FeedbackStatus.open ||
      FeedbackStatus.resolved => AppColors.muted,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(text, style: const TextStyle(fontSize: 12)),
    );
  }
}

IconData _categoryIcon(FeedbackCategory category) => switch (category) {
  FeedbackCategory.service => Icons.star_border,
  FeedbackCategory.generalGrievance => Icons.report_problem_outlined,
  FeedbackCategory.academicGrievance => Icons.school_outlined,
  FeedbackCategory.statutory => Icons.gpp_maybe_outlined,
  FeedbackCategory.institutional => Icons.lightbulb_outline,
};

Color _categoryColor(FeedbackCategory category) => switch (category) {
  FeedbackCategory.service => AppColors.amber,
  FeedbackCategory.generalGrievance => AppColors.primary,
  FeedbackCategory.academicGrievance => AppColors.gateLavender,
  FeedbackCategory.statutory => const Color(0xFFB42318),
  FeedbackCategory.institutional => const Color(0xFF087A4B),
};
