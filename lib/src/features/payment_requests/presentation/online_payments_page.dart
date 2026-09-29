import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/access/effective_permissions.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/user_facing_error.dart';
import '../../settings/presentation/settings_ui.dart';
import '../data/payment_request_models.dart';
import '../data/payment_request_repository.dart';

bool canViewOnlinePayments(EffectivePermissions permissions) =>
    permissions.can('fees', 'online_payments', 'read') ||
    canReconcileOnlinePayments(permissions);

bool canReconcileOnlinePayments(EffectivePermissions permissions) =>
    permissions.can('fees', 'online_payments', 'reconcile');

/// Razorpay capture, crediting, recovery and settlement for this campus.
/// Reloads on `payments.*` realtime events and every 30 seconds while open.
class OnlinePaymentsPage extends StatefulWidget {
  const OnlinePaymentsPage({
    super.key,
    required this.repository,
    this.refreshInterval = const Duration(seconds: 30),
  });

  final PaymentRequestAdminRepository repository;
  final Duration refreshInterval;

  @override
  State<OnlinePaymentsPage> createState() => _OnlinePaymentsPageState();
}

class _OnlinePaymentsPageState extends State<OnlinePaymentsPage>
    with WidgetsBindingObserver {
  static const _filters = <(String, String)>[
    ('all', 'All'),
    ('pending', 'Pending'),
    ('credited', 'Credited'),
    ('captured_not_credited', 'Captured, not credited'),
    ('recovered', 'Recovered'),
    ('failed', 'Failed'),
    ('refunded', 'Refunded'),
  ];

  late DateTimeRange _range;
  String _status = 'all';
  String _query = '';
  OnlinePaymentsReport? _report;
  String? _error;
  bool _syncing = false;
  String? _syncMessage;
  Timer? _timer;
  Timer? _searchDebounce;
  int _loadToken = 0;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    final end = DateTime(today.year, today.month, today.day);
    _range = DateTimeRange(
      start: end.subtract(const Duration(days: 29)),
      end: end,
    );
    WidgetsBinding.instance.addObserver(this);
    paymentRequestRevision.addListener(_refresh);
    _startTimer();
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    paymentRequestRevision.removeListener(_refresh);
    _timer?.cancel();
    _searchDebounce?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Poll only while someone is looking.
    if (state == AppLifecycleState.resumed) {
      _startTimer();
      _refresh();
    } else {
      _timer?.cancel();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(widget.refreshInterval, (_) => _refresh());
  }

  void _refresh() => _load(quiet: true);

  Future<void> _load({bool quiet = false}) async {
    final token = ++_loadToken;
    if (!quiet) setState(() => _error = null);
    try {
      final report = await widget.repository.onlinePayments(
        from: _range.start,
        to: _range.end,
        status: _status,
        query: _query,
      );
      if (!mounted || token != _loadToken) return;
      setState(() {
        _report = report;
        _error = null;
      });
    } catch (error) {
      if (!mounted || token != _loadToken) return;
      // A background refresh that fails keeps the last good numbers.
      if (!quiet || _report == null) {
        setState(() => _error = userFacingError(error));
      }
    }
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year, now.month, now.day),
      initialDateRange: _range,
    );
    if (picked == null) return;
    setState(() {
      _range = picked;
      _report = null;
    });
    _load();
  }

  Future<void> _sync() async {
    setState(() {
      _syncing = true;
      _syncMessage = null;
    });
    try {
      final result = await widget.repository.syncOnlinePayments(
        from: _range.start,
        to: _range.end,
      );
      if (!mounted) return;
      setState(() {
        _syncMessage = [
          result.summary,
          if (result.settlementError != null)
            'Settlements not available: ${result.settlementError}',
          if (result.errors.isNotEmpty)
            '${result.errors.length} could not be checked',
        ].join('\n');
      });
      await _load(quiet: true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _syncMessage = userFacingError(error));
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  void _showPayment(OnlinePayment payment) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: context.palette.canvas,
      builder: (_) => _PaymentDetails(payment: payment),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final report = _report;
    final summary = report?.summary;
    return SettingsPageScaffold(
      title: 'Online payments',
      actions: [
        IconButton(
          tooltip: 'Refresh',
          icon: Icon(Icons.refresh_rounded, color: palette.brand),
          onPressed: () => _load(),
        ),
      ],
      children: [
        Text(
          'Track Razorpay capture, settlement, and recovery. Updates '
          'automatically.',
          style: TextStyle(color: palette.inkSecondary, fontSize: 14),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const ValueKey('online-payments-range'),
                onPressed: _pickRange,
                icon: const Icon(Icons.date_range_rounded, size: 18),
                label: Text(
                  '${formatShortDate(_range.start)} – '
                  '${formatShortDate(_range.end)}',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final (value, label) in _filters) ...[
                ChoiceChip(
                  label: Text(label),
                  selected: _status == value,
                  onSelected: (_) {
                    setState(() => _status = value);
                    _load();
                  },
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          key: const ValueKey('online-payments-search'),
          decoration: const InputDecoration(
            hintText: 'Order ID, payment ID, name or email',
            prefixIcon: Icon(Icons.search_rounded),
          ),
          onChanged: (value) {
            _query = value;
            _searchDebounce?.cancel();
            _searchDebounce = Timer(
              const Duration(milliseconds: 350),
              () => _load(quiet: true),
            );
          },
        ),
        const SizedBox(height: 16),
        if (_error != null && report == null)
          Column(
            children: [
              InlineMessage(message: _error!),
              TextButton(onPressed: _load, child: const Text('Try again')),
            ],
          )
        else if (report == null || summary == null)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          _StatGrid(
            stats: [
              _Stat('Total records', '${summary.totalRecords}'),
              _Stat(
                'Credited',
                formatCurrency(summary.creditedAmount),
                caption: '${summary.creditedCount} payments',
                tone: palette.success,
              ),
              _Stat(
                'Captured, not credited',
                formatCurrency(summary.capturedNotCreditedAmount),
                caption: '${summary.capturedNotCreditedCount} to recover',
                tone: summary.capturedNotCreditedCount > 0
                    ? palette.danger
                    : null,
              ),
              _Stat(
                'Pending',
                '${summary.pendingCount}',
                tone: summary.pendingCount > 0 ? palette.warning : null,
              ),
              _Stat(
                'Failed',
                '${summary.failedCount}',
                tone: summary.failedCount > 0 ? palette.danger : null,
              ),
              _Stat(
                'Settled',
                summary.settlementKnownCount == 0
                    ? 'Not available'
                    : formatCurrency(summary.settledAmount),
                caption: summary.settlementKnownCount == 0
                    ? 'Sync with Razorpay to read settlements'
                    : '${summary.settledCount} of ${summary.settlementKnownCount} checked',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '“Pending” orders were created but no captured payment is known '
            'yet. “Captured, not credited” is the recovery bucket: money '
            'Razorpay captured that the campus has not credited. A sync '
            'credits them and marks them Recovered.',
            style: TextStyle(color: palette.inkSecondary, fontSize: 12.5),
          ),
          const SizedBox(height: 16),
          if (report.canReconcile)
            SettingsSection(
              footer: report.gatewayConfigured
                  ? (report.lastSyncedAt == null
                        ? 'Not synced yet.'
                        : 'Last synced ${formatShortDate(report.lastSyncedAt!)}, '
                              '${formatTime(report.lastSyncedAt!)}.')
                  : 'Razorpay keys are not configured on the server, so '
                        'capture and settlement cannot be read.',
              children: [
                SettingsRow(
                  key: const ValueKey('online-payments-sync'),
                  title: _syncing ? 'Syncing…' : 'Sync with Razorpay',
                  icon: Icons.sync_rounded,
                  onTap: report.gatewayConfigured && !_syncing ? _sync : null,
                ),
              ],
            ),
          if (_syncMessage != null) ...[
            InlineMessage(
              message: _syncMessage!,
              tone: InlineMessageTone.info,
            ),
            const SizedBox(height: 16),
          ],
          if (report.payments.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  'No online payments in this range.',
                  style: TextStyle(color: palette.inkSecondary),
                ),
              ),
            )
          else
            SettingsSection(
              header: report.truncated
                  ? 'PAYMENTS · showing the latest'
                  : 'PAYMENTS · ${report.payments.length}',
              dividerIndent: 16,
              children: [
                for (final payment in report.payments)
                  _PaymentRow(
                    payment: payment,
                    onTap: () => _showPayment(payment),
                  ),
              ],
            ),
        ],
      ],
    );
  }
}

class _Stat {
  const _Stat(this.label, this.value, {this.caption, this.tone});

  final String label;
  final String value;
  final String? caption;
  final Color? tone;
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.stats});

  final List<_Stat> stats;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 560 ? 3 : 2;
        final width = (constraints.maxWidth - 10 * (columns - 1)) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final stat in stats)
              Container(
                width: width,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stat.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: palette.inkSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      stat.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        color: stat.tone ?? palette.ink,
                      ),
                    ),
                    if (stat.caption != null)
                      Text(
                        stat.caption!,
                        maxLines: 2,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: palette.inkTertiary,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

(Color, Color) onlinePaymentTone(BuildContext context, OnlinePaymentState state) {
  final palette = context.palette;
  return switch (state) {
    OnlinePaymentState.credited => (palette.success, palette.successSoft),
    OnlinePaymentState.capturedNotCredited => (palette.danger, palette.dangerSoft),
    OnlinePaymentState.failed => (palette.danger, palette.dangerSoft),
    OnlinePaymentState.refunded => (palette.inkSecondary, palette.surfaceMuted),
    OnlinePaymentState.pending => (palette.warning, palette.warningSoft),
  };
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({required this.payment, required this.onTap});

  final OnlinePayment payment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final (tone, soft) = onlinePaymentTone(context, payment.state);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    payment.payerLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: palette.ink,
                    ),
                  ),
                ),
                Text(
                  formatCurrency(payment.amount),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: palette.ink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              [
                payment.purposeLabel,
                if (payment.detail != null) payment.detail!,
                '${formatShortDate(payment.createdAt)}, ${formatTime(payment.createdAt)}',
              ].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: palette.inkSecondary),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                StatusPill(
                  label: payment.state.label,
                  icon: Icons.circle,
                  color: tone,
                  background: soft,
                ),
                if (payment.recovered)
                  StatusPill(
                    label: 'Recovered',
                    icon: Icons.healing_rounded,
                    color: palette.info,
                    background: palette.infoSoft,
                  ),
                if (payment.settled == true)
                  StatusPill(
                    label: 'Settled',
                    icon: Icons.account_balance_rounded,
                    color: palette.success,
                    background: palette.successSoft,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentDetails extends StatelessWidget {
  const _PaymentDetails({required this.payment});

  final OnlinePayment payment;

  String _when(DateTime? value) => value == null
      ? 'Not available'
      : '${formatShortDate(value)}, ${formatTime(value)}';

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    String paise(int? value) =>
        value == null ? 'Not available' : formatCurrency(value / 100);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${formatCurrency(payment.amount)} · ${payment.state.label}',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: palette.ink,
              ),
            ),
            const SizedBox(height: 12),
            SettingsSection(
              header: 'PAYMENT',
              dividerIndent: 16,
              children: [
                SettingsFactRow(label: 'Paid by', value: payment.payerLabel),
                if (payment.userEmail != null)
                  SettingsFactRow(label: 'Email', value: payment.userEmail!),
                SettingsFactRow(label: 'For', value: payment.purposeLabel),
                if (payment.detail != null)
                  SettingsFactRow(label: 'Detail', value: payment.detail!),
                SettingsFactRow(
                  label: 'Order',
                  value: payment.orderId ?? 'Not stored',
                  copyable: payment.orderId != null,
                ),
                SettingsFactRow(
                  label: 'Payment',
                  value: payment.paymentId ?? 'Not stored yet',
                  copyable: payment.paymentId != null,
                ),
                if (payment.paymentMethod != null)
                  SettingsFactRow(label: 'Method', value: payment.paymentMethod!),
                SettingsFactRow(
                  label: 'Gateway status',
                  value: payment.gatewayStatus ?? 'Not available',
                ),
                if (payment.errorDescription != null)
                  SettingsFactRow(label: 'Error', value: payment.errorDescription!),
              ],
            ),
            SettingsSection(
              header: 'TIMELINE',
              dividerIndent: 16,
              children: [
                SettingsFactRow(label: 'Created', value: _when(payment.createdAt)),
                SettingsFactRow(label: 'Captured', value: _when(payment.capturedAt)),
                SettingsFactRow(
                  label: 'Credited',
                  value: _when(payment.fulfilledAt),
                ),
                SettingsFactRow(
                  label: 'Recovered by sync',
                  value: payment.recovered ? 'Yes' : 'No',
                ),
                SettingsFactRow(
                  label: 'Last synced',
                  value: _when(payment.lastSyncedAt),
                ),
              ],
            ),
            SettingsSection(
              header: 'SETTLEMENT',
              dividerIndent: 16,
              footer: payment.settled == null
                  ? 'Settlement is read from Razorpay during a sync; until then '
                        'it is not available.'
                  : null,
              children: [
                SettingsFactRow(label: 'Status', value: payment.settlementLabel),
                SettingsFactRow(
                  label: 'Settlement',
                  value: payment.settlementId ?? 'Not available',
                  copyable: payment.settlementId != null,
                ),
                SettingsFactRow(label: 'Settled on', value: _when(payment.settledAt)),
                SettingsFactRow(label: 'Gateway fee', value: paise(payment.feePaise)),
                SettingsFactRow(label: 'Tax on fee', value: paise(payment.taxPaise)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
