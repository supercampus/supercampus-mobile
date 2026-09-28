import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/user_facing_error.dart';
import '../../data/canteen_models.dart';
import '../../data/shop_analytics.dart';
import 'canteen_surface.dart';
import 'order_status_badge.dart';

/// Loads one shop's analytics for a date range from the server.
typedef ShopAnalyticsLoader =
    Future<ShopAnalyticsReport> Function(
      String shopKey,
      AnalyticsDateRange range,
    );

/// The quick ranges above the figures; [custom] is a picked range.
enum SalesRangePreset { today, last7Days, last30Days, thisMonth, custom }

extension on SalesRangePreset {
  String get label => switch (this) {
    SalesRangePreset.today => 'Today',
    SalesRangePreset.last7Days => '7 days',
    SalesRangePreset.last30Days => '30 days',
    SalesRangePreset.thisMonth => 'This month',
    SalesRangePreset.custom => 'Custom',
  };

  AnalyticsDateRange range(DateTime today) => switch (this) {
    SalesRangePreset.today => AnalyticsDateRange.single(today),
    SalesRangePreset.last7Days => AnalyticsDateRange.lastDays(7, today),
    SalesRangePreset.last30Days => AnalyticsDateRange.lastDays(30, today),
    SalesRangePreset.thisMonth ||
    SalesRangePreset.custom => AnalyticsDateRange.monthToDate(today),
  };
}

/// The owner workspace's "Sales & Profit" tab: one shop's revenue, cost and
/// profit over a chosen range, and how each of its captains performed.
///
/// With [loadAnalytics] and a [shopKey] every figure comes from the server
/// for the selected range; otherwise it is rolled up from [store]'s orders.
class OwnerCaptainSalesAnalytics extends StatefulWidget {
  const OwnerCaptainSalesAnalytics({
    super.key,
    required this.store,
    required this.busy,
    required this.onRefresh,
    this.shopKey,
    this.shopName,
    this.loadAnalytics,
    this.today,
  });

  final CanteenStore store;
  final bool busy;
  final VoidCallback onRefresh;
  final String? shopKey;
  final String? shopName;
  final ShopAnalyticsLoader? loadAnalytics;

  /// Overrides the device's date, for tests.
  final DateTime? today;

  @override
  State<OwnerCaptainSalesAnalytics> createState() =>
      _OwnerCaptainSalesAnalyticsState();
}

class _OwnerCaptainSalesAnalyticsState
    extends State<OwnerCaptainSalesAnalytics> {
  var _preset = SalesRangePreset.today;
  late AnalyticsDateRange _range;
  ShopAnalyticsReport? _report;
  Object? _error;
  var _loading = false;
  var _request = 0;
  String? _expanded;

  DateTime get _today {
    final now = widget.today ?? DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  bool get _remote => widget.loadAnalytics != null && widget.shopKey != null;

  @override
  void initState() {
    super.initState();
    _range = _preset.range(_today);
    _load();
  }

  @override
  void didUpdateWidget(covariant OwnerCaptainSalesAnalytics oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shopKey != widget.shopKey) {
      _expanded = null;
      _load();
    }
  }

  Future<void> _load() async {
    final loader = widget.loadAnalytics;
    final shopKey = widget.shopKey;
    if (loader == null || shopKey == null) return;
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final report = await loader(shopKey, _range);
      if (!mounted || request != _request) return;
      setState(() {
        _report = report;
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

  void _select(SalesRangePreset preset, AnalyticsDateRange range) {
    setState(() {
      _preset = preset;
      _range = range;
      _expanded = null;
      // Figures from the previous range must not pass for the new one.
      if (_report?.range != range) _report = null;
    });
    _load();
  }

  Future<void> _pickCustom() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(_today.year - 2, _today.month, _today.day),
      lastDate: _today,
      currentDate: _today,
      initialDateRange: DateTimeRange(start: _range.from, end: _range.to),
      helpText: 'Sales range',
      saveText: 'Apply',
    );
    if (picked == null || !mounted) return;
    _select(SalesRangePreset.custom, AnalyticsDateRange(picked.start, picked.end));
  }

  Future<void> _refresh() async {
    widget.onRefresh();
    await _load();
  }

  ShopAnalyticsReport? get _visibleReport {
    if (_remote) return _report;
    return localShopAnalytics(
      orders: widget.store.orders,
      range: _range,
      shopKey: widget.shopKey ?? '',
      shopName: widget.shopName ?? '',
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final report = _visibleReport;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          Text(
            'Sales & Profit Analytics',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            _rangeLabel(_range),
            key: const ValueKey('sales-range-label'),
            style: TextStyle(fontSize: 13, color: p.inkSecondary),
          ),
          const SizedBox(height: 12),
          _RangeBar(
            selected: _preset,
            customLabel: _preset == SalesRangePreset.custom
                ? _shortRange(_range)
                : null,
            onPreset: (preset) => _select(preset, preset.range(_today)),
            onCustom: _pickCustom,
          ),
          const SizedBox(height: 16),
          if (_loading && report == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null && report == null)
            _Message(
              icon: Icons.cloud_off_rounded,
              title: 'Couldn’t load sales',
              body: userFacingError(_error!),
              action: TextButton(onPressed: _load, child: const Text('Try again')),
            )
          else if (report != null) ...[
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            _SummaryGrid(summary: report.summary),
            const SizedBox(height: 12),
            _OutcomeCard(
              summary: report.summary,
              waiting: report.unattributedOrders,
            ),
            const SizedBox(height: 28),
            Text(
              'Performance by Captain',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              'Orders are credited to whoever last moved them at the counter.',
              style: TextStyle(fontSize: 12, color: p.inkSecondary),
            ),
            const SizedBox(height: 12),
            if (report.captains.isEmpty)
              const _Message(
                icon: Icons.badge_outlined,
                title: 'No captains yet',
                body: 'Captains assigned to this shop appear here.',
              )
            else
              for (final captain in report.captains)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _CaptainCard(
                    captain: captain,
                    expanded: _expanded == captain.userId,
                    onToggle: () => setState(
                      () => _expanded = _expanded == captain.userId
                          ? null
                          : captain.userId,
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

String _rangeLabel(AnalyticsDateRange range) {
  if (range.days == 1) return formatShortDate(range.from);
  return '${formatShortDate(range.from)} – ${formatShortDate(range.to)} · '
      '${range.days} days';
}

String _shortRange(AnalyticsDateRange range) {
  String day(DateTime value) =>
      formatShortDate(value).split(' ').take(2).join(' ');
  return range.days == 1 ? day(range.from) : '${day(range.from)} – ${day(range.to)}';
}

String _minutes(double? minutes) {
  if (minutes == null) return '—';
  if (minutes < 60) return '${minutes.round()} min';
  final hours = minutes ~/ 60;
  final rest = (minutes % 60).round();
  return rest == 0 ? '$hours h' : '$hours h $rest min';
}

class _RangeBar extends StatelessWidget {
  const _RangeBar({
    required this.selected,
    required this.onPreset,
    required this.onCustom,
    this.customLabel,
  });

  final SalesRangePreset selected;
  final String? customLabel;
  final ValueChanged<SalesRangePreset> onPreset;
  final VoidCallback onCustom;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final preset in SalesRangePreset.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: preset == SalesRangePreset.custom
                  ? ChoiceChip(
                      key: const ValueKey('sales-range-custom'),
                      avatar: const Icon(Icons.calendar_month_rounded, size: 16),
                      label: Text(customLabel ?? preset.label),
                      selected: selected == preset,
                      showCheckmark: false,
                      onSelected: (_) => onCustom(),
                    )
                  : ChoiceChip(
                      label: Text(preset.label),
                      selected: selected == preset,
                      showCheckmark: false,
                      onSelected: (_) => onPreset(preset),
                    ),
            ),
        ],
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.summary});

  final ShopSalesFigures summary;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final fulfilled = summary.orders > 0
        ? (summary.completedOrders / summary.orders * 100).round()
        : 0;
    final tiles = [
      _KpiCard(
        title: 'Sales',
        value: formatCurrency(summary.revenue),
        subtitle: '${summary.completedOrders} delivered orders',
        icon: Icons.payments_rounded,
        color: p.info,
      ),
      _KpiCard(
        title: 'Net profit',
        value: formatCurrency(summary.profit),
        subtitle: '${summary.marginPercent.toStringAsFixed(1)}% margin',
        icon: Icons.trending_up_rounded,
        color: p.success,
      ),
      _KpiCard(
        title: 'Cost',
        value: formatCurrency(summary.cost),
        subtitle: '${summary.itemsSold} items sold',
        icon: Icons.inventory_2_outlined,
        color: p.warning,
      ),
      _KpiCard(
        title: 'Orders',
        value: '${summary.orders}',
        subtitle:
            '$fulfilled% delivered · ${formatCurrency(summary.averageOrderValue)} avg',
        icon: Icons.receipt_long_rounded,
        color: p.brandInk,
      ),
    ];
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: tiles[0]),
            const SizedBox(width: 10),
            Expanded(child: tiles[1]),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: tiles[2]),
            const SizedBox(width: 10),
            Expanded(child: tiles[3]),
          ],
        ),
      ],
    );
  }
}

/// Where the range's orders ended up, as one grouped card.
class _OutcomeCard extends StatelessWidget {
  const _OutcomeCard({required this.summary, required this.waiting});

  final ShopSalesFigures summary;
  final int waiting;

  @override
  Widget build(BuildContext context) {
    return CanteenSurface(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          _Line(
            label: 'In the queue',
            value:
                '${summary.activeOrders} · ${formatCurrency(summary.activeValue)}',
            detail: waiting > 0 ? '$waiting not yet picked up' : null,
          ),
          const Divider(height: 1),
          _Line(
            label: 'Rejected & refunded',
            value:
                '${summary.rejectedOrders} · ${formatCurrency(summary.refunded)}',
          ),
          if (summary.cancelledOrders > 0) ...[
            const Divider(height: 1),
            _Line(label: 'Cancelled', value: '${summary.cancelledOrders}'),
          ],
          const Divider(height: 1),
          _Line(
            label: 'Avg. time to deliver',
            value: _minutes(summary.averageHandlingMinutes),
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value, this.detail});

  final String label;
  final String value;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 14)),
                if (detail != null)
                  Text(
                    detail!,
                    style: TextStyle(fontSize: 12, color: p.inkSecondary),
                  ),
              ],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: p.inkSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _CaptainCard extends StatelessWidget {
  const _CaptainCard({
    required this.captain,
    required this.expanded,
    required this.onToggle,
  });

  final CaptainPerformance captain;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final f = captain.figures;
    final initials = captain.name
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .map((word) => word[0].toUpperCase())
        .take(2)
        .join();
    final role = switch (captain.role) {
      'captain' => 'Captain',
      'owner' => 'Owner',
      null => 'No longer assigned',
      final other => other,
    };
    final idle = f.orders == 0;

    return CanteenSurface(
      key: ValueKey('captain-${captain.userId}'),
      onTap: idle ? null : onToggle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: p.brandInk.withValues(alpha: 0.12),
                foregroundColor: p.brandInk,
                child: Text(
                  initials.isEmpty ? '?' : initials,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      captain.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      idle
                          ? '$role · no orders in this range'
                          : '$role · ${f.orders} orders · '
                                '${f.completedOrders} delivered',
                      style: TextStyle(fontSize: 12, color: p.inkSecondary),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatCurrency(f.revenue),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    '${formatCurrency(f.profit)} profit',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: p.success,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (f.revenueShare / 100).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: p.surfaceSunken,
              valueColor: AlwaysStoppedAnimation<Color>(p.brandInk),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _Stat(label: 'Share', value: '${f.revenueShare.round()}%'),
              _Stat(label: 'Items', value: '${f.itemsSold}'),
              _Stat(label: 'Rejected', value: '${f.rejectedOrders}'),
              _Stat(
                label: 'Avg. time',
                value: _minutes(f.averageHandlingMinutes),
              ),
            ],
          ),
          if (!idle) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  f.activeOrders > 0 ? '${f.activeOrders} in the queue' : '',
                  style: TextStyle(fontSize: 12, color: p.inkSecondary),
                ),
                const Spacer(),
                Text(
                  expanded ? 'Hide orders' : 'View orders',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: p.brandInk,
                  ),
                ),
                Icon(
                  expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: p.brandInk,
                ),
              ],
            ),
          ],
          if (expanded && captain.recentOrders.isNotEmpty) ...[
            const Divider(height: 24),
            for (final order in captain.recentOrders) _OrderRow(order: order),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(label, style: TextStyle(fontSize: 11, color: p.inkSecondary)),
        ],
      ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.order});

  final ShopAnalyticsOrder order;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final status = CanteenOrderStatus.values.firstWhere(
      (value) => value.apiValue == order.status,
      orElse: () => CanteenOrderStatus.pending,
    );
    final number = int.tryParse(order.orderNumber);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Text(
            '#${number == null ? order.orderNumber : number.toString().padLeft(4, '0')}',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              order.customerName.isEmpty ? 'Customer' : order.customerName,
              style: TextStyle(fontSize: 12, color: p.inkSecondary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          OrderStatusGradientBadge(
            status: status,
            fontSize: 10,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
          ),
          const SizedBox(width: 8),
          Text(
            formatCurrency(order.total),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return CanteenSurface(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: p.inkSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(fontSize: 11, color: p.inkSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return CanteenSurface(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: p.inkSecondary),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(body, style: TextStyle(color: p.inkSecondary)),
            if (action != null) ...[const SizedBox(height: 4), action!],
          ],
        ),
      ),
    );
  }
}
