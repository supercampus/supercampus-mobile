import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/access/effective_permissions.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/user_facing_error.dart';
import '../../modules/presentation/widgets/status_cards/payment_request_card.dart';
import '../../settings/presentation/settings_ui.dart';
import '../data/payment_request_models.dart';
import '../data/payment_request_repository.dart';
import 'payment_request_sheet.dart';

/// Whoever may see payment requests (and who has paid).
bool canViewPaymentRequests(EffectivePermissions permissions) =>
    permissions.can('fees', 'payment_requests', 'read') ||
    canManagePaymentRequests(permissions);

/// Whoever may raise and cancel requests and mark students paid.
bool canManagePaymentRequests(EffectivePermissions permissions) =>
    permissions.can('fees', 'payment_requests', 'manage');

/// The accounts office's list of payment requests, newest active first.
class AdminPaymentRequestsPage extends StatefulWidget {
  const AdminPaymentRequestsPage({
    super.key,
    required this.repository,
    required this.canManage,
  });

  final PaymentRequestAdminRepository repository;
  final bool canManage;

  @override
  State<AdminPaymentRequestsPage> createState() =>
      _AdminPaymentRequestsPageState();
}

class _AdminPaymentRequestsPageState extends State<AdminPaymentRequestsPage> {
  static const _filters = [
    ('active', 'Active'),
    ('closed', 'Closed'),
    ('cancelled', 'Cancelled'),
    ('all', 'All'),
  ];

  String _status = 'active';
  List<PaymentRequestSummary>? _requests;
  String? _error;
  int _loadToken = 0;

  @override
  void initState() {
    super.initState();
    paymentRequestRevision.addListener(_reload);
    _load();
  }

  @override
  void dispose() {
    paymentRequestRevision.removeListener(_reload);
    super.dispose();
  }

  void _reload() => _load(quiet: true);

  Future<void> _load({bool quiet = false}) async {
    final token = ++_loadToken;
    if (!quiet) {
      setState(() {
        _requests = null;
        _error = null;
      });
    }
    try {
      final requests = await widget.repository.list(status: _status);
      if (!mounted || token != _loadToken) return;
      setState(() {
        _requests = requests;
        _error = null;
      });
    } catch (error) {
      if (!mounted || token != _loadToken) return;
      setState(() => _error = userFacingError(error));
    }
  }

  Future<void> _create() async {
    final created = await Navigator.of(context).push<PaymentRequestSummary>(
      MaterialPageRoute(
        builder: (_) =>
            CreatePaymentRequestPage(repository: widget.repository),
      ),
    );
    if (created == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Request sent to ${created.payerCount} '
          '${created.payerCount == 1 ? 'student' : 'students'}',
        ),
      ),
    );
    await _load(quiet: true);
  }

  void _open(PaymentRequestSummary request) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PaymentRequestDetailPage(
          repository: widget.repository,
          requestId: request.id,
          canManage: widget.canManage,
          initial: request,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final requests = _requests;
    return SettingsPageScaffold(
      title: 'Payment requests',
      actions: [
        if (widget.canManage)
          IconButton(
            key: const ValueKey('payment-requests-new'),
            tooltip: 'New request',
            icon: Icon(Icons.add_rounded, color: palette.brand, size: 28),
            onPressed: _create,
          ),
      ],
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: SegmentedButton<String>(
            showSelectedIcon: false,
            segments: [
              for (final (value, label) in _filters)
                ButtonSegment(value: value, label: Text(label)),
            ],
            selected: {_status},
            onSelectionChanged: (selection) {
              setState(() => _status = selection.first);
              _load();
            },
          ),
        ),
        if (_error != null)
          _ErrorState(message: _error!, onRetry: _load)
        else if (requests == null)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (requests.isEmpty)
          _EmptyState(
            icon: Icons.receipt_long_rounded,
            title: 'No payment requests',
            message: widget.canManage
                ? 'Ask students to pay a fine, a bill or any other amount. '
                      'They see it on their home screen.'
                : 'Requests the accounts office raises appear here.',
            action: widget.canManage
                ? FilledButton(
                    onPressed: _create,
                    child: const Text('New request'),
                  )
                : null,
          )
        else
          for (final request in requests)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _RequestTile(request: request, onTap: () => _open(request)),
            ),
      ],
    );
  }
}

class _RequestTile extends StatelessWidget {
  const _RequestTile({required this.request, required this.onTap});

  final PaymentRequestSummary request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final (tone, soft) = requestTone(context, request);
    return Material(
      color: palette.surface,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    paymentPurposeIcon(request.purpose),
                    size: 18,
                    color: palette.inkSecondary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      request.purposeLabel,
                      style: TextStyle(
                        fontSize: 13,
                        color: palette.inkSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  StatusPill(
                    label: request.statusLabel,
                    icon: switch (request.status) {
                      'closed' => Icons.check_circle_rounded,
                      'cancelled' => Icons.block_rounded,
                      _ => Icons.schedule_rounded,
                    },
                    color: tone,
                    background: soft,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      request.title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: palette.ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    formatCurrency(request.amount),
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: palette.ink,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                [
                  request.audienceLabel,
                  request.dueDate == null
                      ? 'No due date'
                      : 'Due ${formatShortDate(request.dueDate!)}',
                ].join(' · '),
                style: TextStyle(fontSize: 13, color: palette.inkSecondary),
              ),
              if (request.status != 'cancelled') ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: request.payerCount == 0
                        ? 0
                        : request.paidCount / request.payerCount,
                    minHeight: 6,
                    color: palette.success,
                    backgroundColor: palette.surfaceMuted,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${request.paidCount} of ${request.payerCount} paid · '
                  '${formatCurrency(request.collectedAmount)} of '
                  '${formatCurrency(request.expectedAmount)} collected',
                  style: TextStyle(fontSize: 12.5, color: palette.inkSecondary),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

(Color, Color) requestTone(BuildContext context, PaymentRequestSummary request) {
  final palette = context.palette;
  return switch (request.status) {
    'closed' => (palette.success, palette.successSoft),
    'cancelled' => (palette.inkTertiary, palette.surfaceMuted),
    _ when request.overdue => (palette.danger, palette.dangerSoft),
    _ => (palette.info, palette.infoSoft),
  };
}

(Color, Color) payerTone(BuildContext context, PaymentRequestStatus status) {
  final palette = context.palette;
  return switch (status) {
    PaymentRequestStatus.paid => (palette.success, palette.successSoft),
    PaymentRequestStatus.overdue => (palette.danger, palette.dangerSoft),
    PaymentRequestStatus.cancelled => (palette.inkTertiary, palette.surfaceMuted),
    PaymentRequestStatus.pending => (palette.warning, palette.warningSoft),
  };
}

/// One request: who has paid, who has not, and the office's actions.
class PaymentRequestDetailPage extends StatefulWidget {
  const PaymentRequestDetailPage({
    super.key,
    required this.repository,
    required this.requestId,
    required this.canManage,
    this.initial,
  });

  final PaymentRequestAdminRepository repository;
  final String requestId;
  final bool canManage;
  final PaymentRequestSummary? initial;

  @override
  State<PaymentRequestDetailPage> createState() =>
      _PaymentRequestDetailPageState();
}

class _PaymentRequestDetailPageState extends State<PaymentRequestDetailPage> {
  PaymentRequestSummary? _request;
  String? _error;
  String _query = '';
  bool _busy = false;
  PaymentRequestOptions _options = const PaymentRequestOptions();

  @override
  void initState() {
    super.initState();
    paymentRequestRevision.addListener(_reload);
    _load();
    if (widget.canManage) {
      widget.repository.options().then((options) {
        if (mounted) setState(() => _options = options);
      }, onError: (_) {});
    }
  }

  @override
  void dispose() {
    paymentRequestRevision.removeListener(_reload);
    super.dispose();
  }

  void _reload() {
    if (!_busy) _load();
  }

  Future<void> _load() async {
    try {
      final request = await widget.repository.detail(widget.requestId);
      if (!mounted) return;
      setState(() {
        _request = request;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = userFacingError(error));
    }
  }

  Future<void> _cancel() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _CancelDialog(),
    );
    if (reason == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final updated = await widget.repository.cancel(
        widget.requestId,
        reason: reason,
      );
      if (!mounted) return;
      setState(() => _request = updated);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingError(error))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _markPaid(PaymentRequestPayer payer) async {
    final receipt = await showModalBottomSheet<_ManualReceipt>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: context.palette.canvas,
      builder: (_) =>
          _MarkPaidSheet(payer: payer, methods: _options.manualMethods),
    );
    if (receipt == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final updated = await widget.repository.markPaid(
        widget.requestId,
        payer.id,
        method: receipt.method,
        reference: receipt.reference,
        note: receipt.note,
      );
      if (!mounted) return;
      setState(() => _request = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${payer.name} marked as paid')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingError(error))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final request = _request ?? widget.initial;
    if (request == null) {
      return SettingsPageScaffold(
        title: 'Payment request',
        children: [
          if (_error != null)
            _ErrorState(message: _error!, onRetry: _load)
          else
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      );
    }
    final query = _query.trim().toLowerCase();
    bool matches(PaymentRequestPayer payer) =>
        query.isEmpty ||
        payer.name.toLowerCase().contains(query) ||
        (payer.studentNumber ?? '').toLowerCase().contains(query);
    final payers = request.payers.where(matches).toList();
    final pending = payers.where((p) => p.status.isOpen).toList();
    final paid = payers
        .where((p) => p.status == PaymentRequestStatus.paid)
        .toList();
    final withdrawn = payers
        .where((p) => p.status == PaymentRequestStatus.cancelled)
        .toList();
    final (tone, soft) = requestTone(context, request);
    final manage = widget.canManage && request.isActive && !_busy;

    return SettingsPageScaffold(
      title: 'Payment request',
      children: [
        Row(
          children: [
            StatusPill(
              label: request.statusLabel,
              icon: Icons.circle,
              color: tone,
              background: soft,
            ),
            const SizedBox(width: 8),
            Text(
              request.purposeLabel,
              style: TextStyle(color: palette.inkSecondary, fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          request.title,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            color: palette.ink,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          request.description,
          style: TextStyle(
            fontSize: 15,
            height: 1.35,
            color: palette.inkSecondary,
          ),
        ),
        const SizedBox(height: 18),
        SettingsSection(
          dividerIndent: 16,
          children: [
            SettingsFactRow(
              label: 'Amount each',
              value: formatCurrency(request.amount),
            ),
            SettingsFactRow(
              label: 'Due date',
              value: request.dueDate == null
                  ? 'No due date'
                  : formatShortDate(request.dueDate!),
            ),
            SettingsFactRow(label: 'Sent to', value: request.audienceLabel),
            SettingsFactRow(
              label: 'Paid',
              value: '${request.paidCount} of ${request.payerCount}',
            ),
            SettingsFactRow(
              label: 'Collected',
              value:
                  '${formatCurrency(request.collectedAmount)} of '
                  '${formatCurrency(request.expectedAmount)}',
            ),
            SettingsFactRow(
              label: 'Home screen',
              value: request.showOnDashboard ? 'Shown' : 'Hidden',
            ),
            if (request.cancelReason != null)
              SettingsFactRow(
                label: 'Cancelled because',
                value: request.cancelReason!,
              ),
          ],
        ),
        if (request.payers.length > 8)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search by name or roll number',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
        if (pending.isNotEmpty)
          SettingsSection(
            header: 'NOT PAID YET · ${pending.length}',
            footer: manage
                ? 'Tap a student to record a payment made at the office.'
                : null,
            children: [
              for (final payer in pending)
                _PayerRow(
                  payer: payer,
                  onTap: manage ? () => _markPaid(payer) : null,
                ),
            ],
          ),
        if (paid.isNotEmpty)
          SettingsSection(
            header: 'PAID · ${paid.length}',
            children: [for (final payer in paid) _PayerRow(payer: payer)],
          ),
        if (withdrawn.isNotEmpty)
          SettingsSection(
            header: 'WITHDRAWN · ${withdrawn.length}',
            children: [for (final payer in withdrawn) _PayerRow(payer: payer)],
          ),
        if (widget.canManage && request.isActive)
          SettingsSection(
            footer:
                'Students who have not paid will no longer be asked to. '
                'Payments already made stay recorded.',
            children: [
              SettingsRow(
                key: const ValueKey('payment-request-cancel'),
                title: 'Cancel request',
                icon: Icons.block_rounded,
                destructive: true,
                onTap: _busy ? null : _cancel,
              ),
            ],
          ),
      ],
    );
  }
}

class _PayerRow extends StatelessWidget {
  const _PayerRow({required this.payer, this.onTap});

  final PaymentRequestPayer payer;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final (tone, soft) = payerTone(context, payer.status);
    final detail = [
      if (payer.studentNumber != null) payer.studentNumber!,
      if (payer.department != null) payer.department!,
      if (payer.status == PaymentRequestStatus.paid &&
          payer.paymentMethod != null)
        paymentMethodLabel(payer.paymentMethod!),
      if (payer.paidAt != null) formatShortDate(payer.paidAt!),
    ].join(' · ');
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    payer.name,
                    style: TextStyle(
                      fontSize: 16,
                      color: palette.ink,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (detail.isNotEmpty)
                    Text(
                      detail,
                      style: TextStyle(
                        fontSize: 13,
                        color: palette.inkSecondary,
                      ),
                    ),
                ],
              ),
            ),
            StatusPill(
              label: payer.status.label,
              icon: payer.status == PaymentRequestStatus.paid
                  ? Icons.check_rounded
                  : Icons.schedule_rounded,
              color: tone,
              background: soft,
            ),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, color: palette.inkTertiary),
            ],
          ],
        ),
      ),
    );
  }
}

class _ManualReceipt {
  const _ManualReceipt(this.method, this.reference, this.note);

  final String method;
  final String? reference;
  final String? note;
}

class _MarkPaidSheet extends StatefulWidget {
  const _MarkPaidSheet({required this.payer, required this.methods});

  final PaymentRequestPayer payer;
  final List<PaymentOption> methods;

  @override
  State<_MarkPaidSheet> createState() => _MarkPaidSheetState();
}

class _MarkPaidSheetState extends State<_MarkPaidSheet> {
  String _method = 'cash';
  final _reference = TextEditingController();
  final _note = TextEditingController();

  @override
  void dispose() {
    _reference.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Mark ${widget.payer.name} as paid',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: palette.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${formatCurrency(widget.payer.amount)} received outside the app.',
                style: TextStyle(color: palette.inkSecondary, fontSize: 14),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final method in widget.methods)
                    ChoiceChip(
                      label: Text(method.label),
                      selected: _method == method.key,
                      onSelected: (_) => setState(() => _method = method.key),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              SettingsTextField(
                controller: _reference,
                label: 'Receipt or reference (optional)',
                maxLength: 80,
              ),
              const SizedBox(height: 12),
              SettingsTextField(
                controller: _note,
                label: 'Note (optional)',
                maxLength: 300,
                maxLines: 3,
                minLines: 1,
              ),
              const SizedBox(height: 16),
              SettingsPrimaryButton(
                key: const ValueKey('payment-request-confirm-paid'),
                label: 'Mark as paid',
                onPressed: () => Navigator.of(context).pop(
                  _ManualReceipt(_method, _reference.text, _note.text),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CancelDialog extends StatefulWidget {
  const _CancelDialog();

  @override
  State<_CancelDialog> createState() => _CancelDialogState();
}

class _CancelDialogState extends State<_CancelDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cancel this request?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Students who have not paid will stop seeing it. This cannot be '
            'undone.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _reason,
            maxLength: 300,
            decoration: const InputDecoration(labelText: 'Reason (optional)'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Keep'),
        ),
        TextButton(
          key: const ValueKey('payment-request-confirm-cancel'),
          onPressed: () => Navigator.of(context).pop(_reason.text),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          child: const Text('Cancel request'),
        ),
      ],
    );
  }
}

/// The "Create Payment Request" form.
class CreatePaymentRequestPage extends StatefulWidget {
  const CreatePaymentRequestPage({super.key, required this.repository});

  final PaymentRequestAdminRepository repository;

  @override
  State<CreatePaymentRequestPage> createState() =>
      _CreatePaymentRequestPageState();
}

class _CreatePaymentRequestPageState extends State<CreatePaymentRequestPage> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _amount = TextEditingController();
  final _search = TextEditingController();
  PaymentRequestOptions _options = const PaymentRequestOptions();
  String _purpose = 'fine';
  String _target = 'all';
  DateTime? _dueDate;
  bool _showOnDashboard = true;
  final Set<String> _departments = {};
  final Set<String> _years = {};
  final Map<String, PaymentStudent> _students = {};
  List<PaymentStudent> _results = const [];
  Timer? _searchDebounce;
  bool _submitting = false;
  bool _attempted = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.repository.options().then((options) {
      if (mounted) setState(() => _options = options);
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _amount.dispose();
    _search.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  double? get _amountValue {
    final value = double.tryParse(_amount.text.replaceAll(',', '').trim());
    return value == null || value <= 0 ? null : value;
  }

  String? get _titleError =>
      _title.text.trim().length < 3 ? 'Enter a title' : null;

  String? get _descriptionError => _description.text.trim().length < 10
      ? 'Describe it in at least 10 characters'
      : null;

  String? get _amountError {
    final value = _amountValue;
    if (value == null || value < 1) return 'Enter an amount of at least ₹1';
    if (value > 1000000) return 'Enter ₹10,00,000 or less';
    return null;
  }

  String? get _audienceError => switch (_target) {
    'students' when _students.isEmpty => 'Choose at least one student',
    'cohort' when _departments.isEmpty && _years.isEmpty =>
      'Choose a department or a year',
    _ => null,
  };

  void _onSearch(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () async {
      if (value.trim().isEmpty) {
        if (mounted) setState(() => _results = const []);
        return;
      }
      try {
        final results = await widget.repository.searchStudents(value);
        if (mounted && _search.text == value) {
          setState(() => _results = results);
        }
      } catch (_) {
        // Keep the previous results; the field stays usable.
      }
    });
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now.add(const Duration(days: 7)),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 730)),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _submit() async {
    setState(() => _attempted = true);
    if (_titleError != null ||
        _descriptionError != null ||
        _amountError != null ||
        _audienceError != null) {
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final created = await widget.repository.create(
        NewPaymentRequest(
          purpose: _purpose,
          title: _title.text,
          description: _description.text,
          amount: _amountValue!,
          target: _target,
          dueDate: _dueDate,
          showOnDashboard: _showOnDashboard,
          studentUserIds: _students.keys.toList(),
          departments: _departments.toList(),
          years: _years.toList(),
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(created);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = userFacingError(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final chipSpacing = const SizedBox(height: 8);
    return SettingsPageScaffold(
      title: 'New payment request',
      bottom: SettingsPrimaryButton(
        key: const ValueKey('payment-request-submit'),
        label: 'Send request',
        busy: _submitting,
        onPressed: _submitting ? null : _submit,
      ),
      children: [
        _Label('Purpose'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final purpose in _options.purposes)
              ChoiceChip(
                avatar: Icon(paymentPurposeIcon(purpose.key), size: 16),
                label: Text(purpose.label),
                selected: _purpose == purpose.key,
                onSelected: (_) => setState(() => _purpose = purpose.key),
              ),
          ],
        ),
        const SizedBox(height: 20),
        SettingsTextField(
          fieldKey: const ValueKey('payment-request-title'),
          controller: _title,
          label: 'Title',
          hint: 'e.g. Library late fine',
          maxLength: 120,
          textCapitalization: TextCapitalization.sentences,
          errorText: _attempted ? _titleError : null,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        SettingsTextField(
          fieldKey: const ValueKey('payment-request-description'),
          controller: _description,
          label: 'Description',
          hint: 'What this is for',
          maxLength: 1000,
          maxLines: 4,
          minLines: 2,
          textCapitalization: TextCapitalization.sentences,
          errorText: _attempted ? _descriptionError : null,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        SettingsTextField(
          fieldKey: const ValueKey('payment-request-amount'),
          controller: _amount,
          label: 'Amount (₹)',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          errorText: _attempted ? _amountError : null,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 20),
        SettingsSection(
          dividerIndent: 16,
          children: [
            SettingsRow(
              title: 'Due date',
              icon: Icons.event_rounded,
              value: _dueDate == null
                  ? 'None'
                  : formatShortDate(_dueDate!),
              onTap: _pickDueDate,
            ),
            if (_dueDate != null)
              SettingsRow(
                title: 'Remove due date',
                onTap: () => setState(() => _dueDate = null),
              ),
            SwitchListTile.adaptive(
              key: const ValueKey('payment-request-show-on-dashboard'),
              title: const Text('Show on dashboard'),
              subtitle: const Text('Students will see this on their home screen'),
              value: _showOnDashboard,
              onChanged: (value) => setState(() => _showOnDashboard = value),
            ),
          ],
        ),
        _Label('Target students'),
        SegmentedButton<String>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: 'all', label: Text('All students')),
            ButtonSegment(value: 'cohort', label: Text('Year / dept')),
            ButtonSegment(value: 'students', label: Text('Specific')),
          ],
          selected: {_target},
          onSelectionChanged: (selection) =>
              setState(() => _target = selection.first),
        ),
        const SizedBox(height: 12),
        if (_target == 'all')
          Text(
            _options.studentCount > 0
                ? 'Every active student (${_options.studentCount}).'
                : 'Every active student.',
            style: TextStyle(color: palette.inkSecondary, fontSize: 14),
          ),
        if (_target == 'cohort') ...[
          if (_options.departments.isNotEmpty) ...[
            Text(
              'Departments',
              style: TextStyle(color: palette.inkSecondary, fontSize: 13),
            ),
            chipSpacing,
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final department in _options.departments)
                  FilterChip(
                    label: Text(department),
                    selected: _departments.contains(department),
                    onSelected: (on) => setState(
                      () => on
                          ? _departments.add(department)
                          : _departments.remove(department),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          if (_options.years.isNotEmpty) ...[
            Text(
              'Years',
              style: TextStyle(color: palette.inkSecondary, fontSize: 13),
            ),
            chipSpacing,
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final year in _options.years)
                  FilterChip(
                    label: Text('Year $year'),
                    selected: _years.contains(year),
                    onSelected: (on) => setState(
                      () => on ? _years.add(year) : _years.remove(year),
                    ),
                  ),
              ],
            ),
          ],
          chipSpacing,
          Text(
            'Leave one side empty to include all of it: choosing only CSE '
            'asks every CSE year.',
            style: TextStyle(color: palette.inkSecondary, fontSize: 12.5),
          ),
        ],
        if (_target == 'students') ...[
          if (_students.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final student in _students.values)
                  InputChip(
                    label: Text(student.name),
                    onDeleted: () =>
                        setState(() => _students.remove(student.userId)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            key: const ValueKey('payment-request-student-search'),
            controller: _search,
            decoration: const InputDecoration(
              hintText: 'Search by name, roll number or email',
              prefixIcon: Icon(Icons.search_rounded),
            ),
            onChanged: _onSearch,
          ),
          if (_results.isNotEmpty) ...[
            const SizedBox(height: 8),
            SettingsSection(
              dividerIndent: 16,
              children: [
                for (final student in _results)
                  CheckboxListTile(
                    value: _students.containsKey(student.userId),
                    title: Text(student.name),
                    subtitle: student.detail.isEmpty
                        ? null
                        : Text(student.detail),
                    onChanged: (on) => setState(
                      () => on == true
                          ? _students[student.userId] = student
                          : _students.remove(student.userId),
                    ),
                  ),
              ],
            ),
          ],
        ],
        if (_attempted && _audienceError != null) ...[
          const SizedBox(height: 8),
          InlineMessage(message: _audienceError!),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          InlineMessage(message: _error!),
        ],
        const SizedBox(height: 12),
        Text(
          _options.onlinePaymentsEnabled
              ? 'Students can pay online with Razorpay, or at the office — you '
                    'can mark those paid here.'
              : 'Online payment is not configured, so students pay at the '
                    'office and you mark them paid here.',
          style: TextStyle(color: palette.inkSecondary, fontSize: 12.5),
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
    child: Text(
      text,
      style: TextStyle(
        color: context.palette.inkSecondary,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
      child: Column(
        children: [
          Icon(icon, size: 40, color: palette.inkTertiary),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: palette.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.inkSecondary, fontSize: 14),
          ),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Column(
      children: [
        InlineMessage(message: message),
        const SizedBox(height: 12),
        TextButton(onPressed: onRetry, child: const Text('Try again')),
      ],
    ),
  );
}
