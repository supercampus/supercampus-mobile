import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/admin_system_models.dart';
import '../data/admin_system_repository.dart';
import 'admin_system_widgets.dart';

/// Quick type filter above the list.
enum _AuditView { all, credits, debits, refunds, payments }

/// Audit Logs: every wallet top-up, deduction, refund, order and laundry
/// payment, payment request and online payment, newest first.
class AuditLogsScreen extends StatefulWidget {
  const AuditLogsScreen({super.key, required this.repository});

  final AdminSystemRepository repository;

  @override
  State<AuditLogsScreen> createState() => _AuditLogsScreenState();
}

class _AuditLogsScreenState extends State<AuditLogsScreen> {
  static const _pageSize = 50;

  final _search = TextEditingController();
  AuditFilter _filter = const AuditFilter();
  _AuditView _view = _AuditView.all;
  final List<AuditEntry> _entries = [];
  AuditPage? _page;
  Object? _error;
  bool _loading = true;
  bool _loadingMore = false;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  AuditFilter get _effectiveFilter => switch (_view) {
    _AuditView.all => _filter,
    _AuditView.credits => _filter.copyWith(direction: AuditDirection.credit),
    _AuditView.debits => _filter.copyWith(direction: AuditDirection.debit),
    _AuditView.payments => _filter.copyWith(direction: AuditDirection.payment),
    _AuditView.refunds => _filter.copyWith(kinds: {AuditKind.refund}),
  };

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await widget.repository.auditLogs(
        _effectiveFilter,
        limit: _pageSize,
      );
      if (!mounted || request != _request) return;
      setState(() {
        _page = page;
        _entries
          ..clear()
          ..addAll(page.entries);
        _loading = false;
      });
    } catch (error) {
      if (!mounted || request != _request) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore) return;
    final request = _request;
    setState(() => _loadingMore = true);
    try {
      final page = await widget.repository.auditLogs(
        _effectiveFilter,
        limit: _pageSize,
        offset: _entries.length,
      );
      if (!mounted || request != _request) return;
      setState(() => _entries.addAll(page.entries));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _apply(AuditFilter filter) {
    setState(() => _filter = filter);
    _load();
  }

  Future<void> _openFilters() async {
    final result = await showModalBottomSheet<AuditFilter>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: context.palette.surface,
      builder: (_) => _AuditFilterSheet(initial: _filter),
    );
    if (result != null) {
      _search.text = result.search;
      _apply(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final page = _page;
    final activeFilters = [
      if (_filter.from != null || _filter.to != null) 'dates',
      if (_filter.kinds.isNotEmpty) 'types',
      if (_filter.actor.trim().isNotEmpty) 'actor',
    ].length;
    return Scaffold(
      backgroundColor: palette.surfaceSunken,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _load,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: SystemPageHeader(
                  title: 'Audit Logs',
                  subtitle: 'Finance audit trail and transaction history',
                  trailing: Badge(
                    isLabelVisible: activeFilters > 0,
                    label: Text('$activeFilters'),
                    child: IconButton(
                      key: const Key('audit-filters'),
                      tooltip: 'Filters',
                      onPressed: _openFilters,
                      icon: Icon(Icons.tune_rounded, color: palette.ink),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                  child: SystemSearchField(
                    fieldKey: const Key('audit-search'),
                    controller: _search,
                    hint: 'Student, roll number, reference',
                    onSubmitted: (value) =>
                        _apply(_filter.copyWith(search: value)),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SystemChoiceChips<_AuditView>(
                  selected: _view,
                  onSelected: (view) {
                    setState(() => _view = view);
                    _load();
                  },
                  options: const [
                    (_AuditView.all, 'All'),
                    (_AuditView.credits, 'Credits'),
                    (_AuditView.debits, 'Debits'),
                    (_AuditView.refunds, 'Refunds'),
                    (_AuditView.payments, 'Payments'),
                  ],
                ),
              ),
              if (page != null && _error == null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: SystemMetricRow(
                      metrics: [
                        ('Entries', '${page.total}', null),
                        (
                          'Credits',
                          formatRupees(page.credits),
                          palette.success,
                        ),
                        ('Debits', formatRupees(page.debits), palette.danger),
                      ],
                    ),
                  ),
                ),
              ..._body(context),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: MediaQuery.paddingOf(context).bottom + 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _body(BuildContext context) {
    if (_loading && _entries.isEmpty) {
      return const [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(48),
            child: Center(child: CircularProgressIndicator.adaptive()),
          ),
        ),
      ];
    }
    if (_error != null) {
      return [
        SliverToBoxAdapter(
          child: SystemMessage(
            icon: Icons.cloud_off_rounded,
            title: "Audit logs couldn't load",
            body: '$_error',
            actionLabel: 'Try again',
            onAction: _load,
          ),
        ),
      ];
    }
    if (_entries.isEmpty) {
      return const [
        SliverToBoxAdapter(
          child: SystemMessage(
            icon: Icons.receipt_long_outlined,
            title: 'No entries',
            body: 'Nothing matches these filters.',
          ),
        ),
      ];
    }
    final total = _page?.total ?? _entries.length;
    return [
      const SliverToBoxAdapter(child: SystemSectionLabel('Transactions')),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverToBoxAdapter(
          child: Material(
            color: context.palette.surface,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < _entries.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      thickness: 0.5,
                      indent: 64,
                      color: context.palette.divider,
                    ),
                  _AuditRow(
                    entry: _entries[i],
                    onTap: () => _showDetail(_entries[i]),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      if (_entries.length < total)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Center(
              child: _loadingMore
                  ? const CircularProgressIndicator.adaptive()
                  : TextButton(
                      key: const Key('audit-load-more'),
                      onPressed: _loadMore,
                      child: Text('Show more (${_entries.length} of $total)'),
                    ),
            ),
          ),
        ),
    ];
  }

  void _showDetail(AuditEntry entry) {
    final details = entry.details;
    String? detail(String key) => details[key]?.toString();
    showSystemDetailSheet(
      context,
      title: entry.direction == AuditDirection.payment
          ? formatRupees(entry.amount)
          : formatSignedRupees(entry.amount),
      subtitle: entry.kind.label,
      children: [
        SystemDetailLine(label: 'Member', value: entry.targetName),
        SystemDetailLine(label: 'Roll number', value: entry.targetNumber),
        SystemDetailLine(label: 'Email', value: entry.targetEmail),
        SystemDetailLine(label: 'Performed by', value: entry.actorLabel),
        SystemDetailLine(label: 'When', value: formatStamp(entry.createdAt)),
        SystemDetailLine(
          label: 'Wallet',
          value: entry.shopName ?? entry.shopKey,
        ),
        SystemDetailLine(label: 'Reason', value: entry.description),
        if (entry.balanceAfter != null)
          SystemDetailLine(
            label: 'Balance',
            value:
                '${formatRupees(entry.balanceBefore ?? 0)} → '
                '${formatRupees(entry.balanceAfter!)}',
          ),
        SystemDetailLine(label: 'Status', value: entry.status),
        SystemDetailLine(label: 'Reference', value: entry.reference),
        SystemDetailLine(label: 'Method', value: detail('method')),
        SystemDetailLine(label: 'Purpose', value: detail('purpose')),
        SystemDetailLine(label: 'Laundry item', value: detail('laundryItem')),
        SystemDetailLine(label: 'Payment ID', value: detail('paymentId')),
        SystemDetailLine(label: 'Order ID', value: detail('orderId')),
        SystemDetailLine(label: 'Note', value: detail('note')),
        SystemDetailLine(label: 'Cancel reason', value: detail('cancelReason')),
        SystemDetailLine(label: 'Error', value: detail('errorDescription')),
        SystemDetailLine(label: 'Entry ID', value: entry.id),
      ],
    );
  }
}

class _AuditRow extends StatelessWidget {
  const _AuditRow({required this.entry, required this.onTap});

  final AuditEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final (icon, color) = switch (entry.direction) {
      AuditDirection.credit => (Icons.south_west_rounded, palette.success),
      AuditDirection.debit => (Icons.north_east_rounded, palette.danger),
      AuditDirection.payment => (Icons.payments_outlined, palette.info),
    };
    final amount = entry.direction == AuditDirection.payment
        ? formatRupees(entry.amount)
        : formatSignedRupees(entry.amount);
    final title =
        entry.targetName ??
        (entry.kind == AuditKind.paymentRequestIssued
            ? entry.description ?? entry.kind.label
            : entry.kind.label);
    final subtitle = [
      entry.kind.label,
      if (entry.description != null && entry.description != title)
        entry.description!,
      'by ${entry.actorLabel}',
    ].join(' · ');
    return InkWell(
      key: Key('audit-entry-${entry.id}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 11, 14, 11),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: palette.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: palette.inkSecondary),
                  ),
                  if (entry.balanceAfter != null)
                    Text(
                      '${formatRupees(entry.balanceBefore ?? 0)} → '
                      '${formatRupees(entry.balanceAfter!)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: palette.inkTertiary,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  amount,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: entry.direction == AuditDirection.payment
                        ? palette.ink
                        : color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  formatRelative(entry.createdAt),
                  style: TextStyle(fontSize: 12, color: palette.inkTertiary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AuditFilterSheet extends StatefulWidget {
  const _AuditFilterSheet({required this.initial});

  final AuditFilter initial;

  @override
  State<_AuditFilterSheet> createState() => _AuditFilterSheetState();
}

class _AuditFilterSheetState extends State<_AuditFilterSheet> {
  late final Set<AuditKind> _kinds = {...widget.initial.kinds};
  late DateTime? _from = widget.initial.from;
  late DateTime? _to = widget.initial.to;
  late final _actor = TextEditingController(text: widget.initial.actor);

  @override
  void dispose() {
    _actor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final range = _from == null || _to == null
        ? 'Any date'
        : '${formatShortDay(_from!)} – ${formatShortDay(_to!)}';
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.viewInsetsOf(context).bottom +
            MediaQuery.paddingOf(context).bottom +
            16,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Filters',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: palette.ink,
              ),
            ),
            const SizedBox(height: 14),
            Text('Date range', style: TextStyle(color: palette.inkSecondary)),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              key: const Key('audit-date-range'),
              onPressed: () async {
                final picked = await pickDayRange(
                  context,
                  from: _from,
                  to: _to,
                );
                if (picked != null) {
                  setState(() {
                    _from = picked.start;
                    _to = picked.end;
                  });
                }
              },
              icon: const Icon(Icons.calendar_today_rounded, size: 16),
              label: Text(range),
            ),
            const SizedBox(height: 16),
            Text('Type', style: TextStyle(color: palette.inkSecondary)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final kind in AuditKind.values)
                  if (kind != AuditKind.other)
                    FilterChip(
                      label: Text(kind.label),
                      selected: _kinds.contains(kind),
                      onSelected: (selected) => setState(() {
                        selected ? _kinds.add(kind) : _kinds.remove(kind);
                      }),
                    ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('audit-actor'),
              controller: _actor,
              decoration: const InputDecoration(
                labelText: 'Performed by',
                hintText: 'Name or email, or "system"',
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.of(
                    context,
                  ).pop(AuditFilter(search: widget.initial.search)),
                  child: const Text('Reset'),
                ),
                const Spacer(),
                FilledButton(
                  key: const Key('audit-apply-filters'),
                  onPressed: () => Navigator.of(context).pop(
                    AuditFilter(
                      kinds: _kinds,
                      from: _from,
                      to: _to,
                      search: widget.initial.search,
                      actor: _actor.text,
                    ),
                  ),
                  child: const Text('Apply'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
