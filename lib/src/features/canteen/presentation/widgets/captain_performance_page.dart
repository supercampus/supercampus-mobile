import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/user_facing_error.dart';
import '../../../../core/widgets/module_navigation_buttons.dart';
import '../../data/shop_analytics.dart';
import 'canteen_order_detail_page.dart';
import 'canteen_surface.dart';
import 'order_status_badge.dart';
import 'owner_captain_sales_analytics.dart';

/// Loads a page of one staff member's detail for a range.
typedef CaptainPageLoader =
    Future<CaptainPerformanceDetail> Function(
      AnalyticsDateRange range,
      int page,
    );

/// One captain's performance over the Sales page's range: who they are, the
/// figures, a day-by-day trend and every order they handled.
///
/// The range is the one the Sales page had selected; changing it here changes
/// it there too ([onRangeChanged]), so going back shows the same days.
class CaptainPerformancePage extends StatefulWidget {
  const CaptainPerformancePage({
    super.key,
    required this.captain,
    required this.preset,
    required this.range,
    required this.load,
    this.shopName,
    this.onRangeChanged,
    this.today,
  });

  /// As the Sales page listed them; shown until the detail arrives.
  final CaptainPerformance captain;
  final SalesRangePreset preset;
  final AnalyticsDateRange range;
  final CaptainPageLoader load;
  final String? shopName;
  final void Function(SalesRangePreset preset, AnalyticsDateRange range)?
  onRangeChanged;

  /// Overrides the device's date, for tests.
  final DateTime? today;

  @override
  State<CaptainPerformancePage> createState() => _CaptainPerformancePageState();
}

enum _TrendMetric { orders, revenue }

class _CaptainPerformancePageState extends State<CaptainPerformancePage> {
  late SalesRangePreset _preset = widget.preset;
  late AnalyticsDateRange _range = widget.range;
  CaptainPerformanceDetail? _detail;
  var _orders = <ShopAnalyticsOrder>[];
  var _loading = false;
  var _loadingMore = false;
  Object? _error;
  var _request = 0;
  var _metric = _TrendMetric.orders;

  DateTime get _today {
    final now = widget.today ?? DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await widget.load(_range, 1);
      if (!mounted || request != _request) return;
      setState(() {
        _detail = detail;
        _orders = [...detail.orders];
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
    final detail = _detail;
    if (detail == null || !detail.hasMore || _loadingMore) return;
    final request = _request;
    setState(() => _loadingMore = true);
    try {
      final next = await widget.load(_range, detail.page + 1);
      if (!mounted || request != _request) return;
      setState(() {
        _detail = next;
        _orders = [..._orders, ...next.orders];
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted || request != _request) return;
      setState(() => _loadingMore = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingError(error))));
    }
  }

  void _select(SalesRangePreset preset, AnalyticsDateRange range) {
    setState(() {
      _preset = preset;
      _range = range;
      // Figures from the previous range must not pass for the new one.
      if (_detail?.range != range) {
        _detail = null;
        _orders = [];
      }
    });
    widget.onRangeChanged?.call(preset, range);
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
    _select(
      SalesRangePreset.custom,
      AnalyticsDateRange(picked.start, picked.end),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final detail = _detail;
    // Until the detail arrives, the card's own figures stand in — they are
    // for the same range.
    final captain =
        detail?.captain ??
        (_range == widget.range ? widget.captain : null) ??
        CaptainPerformance(
          userId: widget.captain.userId,
          name: widget.captain.name,
          email: widget.captain.email,
          role: widget.captain.role,
          figures: const ShopSalesFigures(),
        );
    final name = captain.name.isEmpty ? widget.captain.name : captain.name;

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: AppBar(
        titleSpacing: 0,
        leading: ModuleBackButton(
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                key: const ValueKey('captain-page-list'),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                children: [
                  _Header(
                    captain: captain,
                    fallbackName: widget.captain.name,
                    shopName: widget.shopName,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    salesRangeLabel(_range),
                    key: const ValueKey('captain-range-label'),
                    style: TextStyle(fontSize: 13, color: p.inkSecondary),
                  ),
                  const SizedBox(height: 8),
                  SalesRangeBar(
                    selected: _preset,
                    customLabel: _preset == SalesRangePreset.custom
                        ? shortSalesRange(_range)
                        : null,
                    onPreset: (preset) => _select(preset, preset.range(_today)),
                    onCustom: _pickCustom,
                  ),
                  const SizedBox(height: 14),
                  if (_loading) ...[
                    const LinearProgressIndicator(minHeight: 2),
                    const SizedBox(height: 10),
                  ],
                  if (_error != null && detail == null)
                    _ErrorCard(error: _error!, onRetry: _load)
                  else ...[
                    _KpiGrid(captain: captain),
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Daily trend',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        SegmentedButton<_TrendMetric>(
                          key: const ValueKey('captain-trend-metric'),
                          showSelectedIcon: false,
                          style: const ButtonStyle(
                            visualDensity: VisualDensity.compact,
                          ),
                          segments: const [
                            ButtonSegment(
                              value: _TrendMetric.orders,
                              label: Text('Orders'),
                            ),
                            ButtonSegment(
                              value: _TrendMetric.revenue,
                              label: Text('Revenue'),
                            ),
                          ],
                          selected: {_metric},
                          onSelectionChanged: (value) =>
                              setState(() => _metric = value.first),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    CanteenSurface(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                      child: _TrendChart(
                        points: detail?.daily ?? const [],
                        metric: _metric,
                        loading: detail == null,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Orders handled',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (detail != null)
                          Text(
                            '${detail.totalOrders}',
                            style: TextStyle(
                              color: p.inkSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Newest first. Tap an order for its details.',
                      style: TextStyle(fontSize: 12, color: p.inkSecondary),
                    ),
                    const SizedBox(height: 10),
                    if (detail != null && _orders.isEmpty)
                      CanteenSurface(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            'No orders handled in this range.',
                            style: TextStyle(color: p.inkSecondary),
                          ),
                        ),
                      )
                    else if (_orders.isNotEmpty)
                      _OrdersGroup(orders: _orders),
                    if (detail != null && detail.hasMore) ...[
                      const SizedBox(height: 12),
                      Center(
                        child: _loadingMore
                            ? const Padding(
                                padding: EdgeInsets.all(8),
                                child: SizedBox.square(
                                  dimension: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : TextButton(
                                key: const ValueKey('captain-orders-more'),
                                onPressed: _loadMore,
                                child: Text(
                                  'Show more · '
                                  '${detail.totalOrders - _orders.length} left',
                                ),
                              ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Who this is: initials, name, email and how they are attached to the shop.
class _Header extends StatelessWidget {
  const _Header({
    required this.captain,
    required this.fallbackName,
    this.shopName,
  });

  final CaptainPerformance captain;
  final String fallbackName;
  final String? shopName;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final name = captain.name.isEmpty ? fallbackName : captain.name;
    final role = captainRoleLabel(captain.role);
    final shop = shopName?.trim();
    return CanteenSurface(
      child: Row(
        children: [
          CaptainAvatar(name: name, radius: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    height: 1.15,
                  ),
                ),
                if ((captain.email ?? '').isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    captain.email!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: p.inkSecondary, fontSize: 13),
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _Pill(text: role, strong: captain.assigned),
                    if (shop != null && shop.isNotEmpty) _Pill(text: shop),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, this.strong = false});

  final String text;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: strong ? p.brandSoft : p.surfaceSunken,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: strong ? p.brandInk : p.inkSecondary,
        ),
      ),
    );
  }
}

/// When someone was last seen doing something: the last order they moved in
/// the range, otherwise their last sign-in.
String _lastActive(CaptainPerformance captain, DateTime today) {
  final at = captain.lastHandledAt ?? captain.lastSeenAt;
  if (at == null) return '—';
  final local = at.toLocal();
  final day = isSameDay(local, today)
      ? 'Today'
      : isSameDay(local, today.subtract(const Duration(days: 1)))
      ? 'Yesterday'
      : formatShortDate(local);
  return '$day, ${formatTime(local)}';
}

/// Ten figures, two to a row.
class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.captain});

  final CaptainPerformance captain;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final f = captain.figures;
    final now = DateTime.now();
    final tiles = <Widget>[
      _Kpi(
        key: const ValueKey('kpi-orders'),
        label: 'Orders handled',
        value: '${f.orders}',
        icon: Icons.receipt_long_rounded,
        color: p.brandInk,
      ),
      _Kpi(
        key: const ValueKey('kpi-completed'),
        label: 'Completed',
        value: '${f.completedOrders}',
        icon: Icons.check_circle_rounded,
        color: p.success,
      ),
      _Kpi(
        key: const ValueKey('kpi-rejected'),
        label: 'Rejected / cancelled',
        value: '${f.rejectedOrders + f.cancelledOrders}',
        icon: Icons.cancel_rounded,
        color: p.danger,
      ),
      _Kpi(
        key: const ValueKey('kpi-items'),
        label: 'Items',
        value: '${f.itemsSold}',
        icon: Icons.shopping_basket_rounded,
        color: p.info,
      ),
      _Kpi(
        key: const ValueKey('kpi-revenue'),
        label: 'Revenue',
        value: formatCurrency(f.revenue),
        icon: Icons.payments_rounded,
        color: p.info,
      ),
      _Kpi(
        key: const ValueKey('kpi-cost'),
        label: 'Cost',
        value: formatCurrency(f.cost),
        icon: Icons.inventory_2_rounded,
        color: p.warning,
      ),
      _Kpi(
        key: const ValueKey('kpi-profit'),
        label: 'Profit',
        value: formatCurrency(f.profit),
        icon: Icons.trending_up_rounded,
        color: p.success,
      ),
      _Kpi(
        key: const ValueKey('kpi-share'),
        label: 'Share of shop',
        value:
            '${f.revenueShare.toStringAsFixed(f.revenueShare % 1 == 0 ? 0 : 1)}%',
        icon: Icons.pie_chart_rounded,
        color: p.brandInk,
      ),
      _Kpi(
        key: const ValueKey('kpi-time'),
        label: 'Avg. time to deliver',
        value: formatHandlingMinutes(f.averageHandlingMinutes),
        icon: Icons.timer_rounded,
        color: p.warning,
      ),
      _Kpi(
        key: const ValueKey('kpi-last-active'),
        label: 'Last active',
        value: _lastActive(captain, DateTime(now.year, now.month, now.day)),
        icon: Icons.schedule_rounded,
        color: p.inkSecondary,
      ),
    ];
    return Column(
      children: [
        for (var i = 0; i < tiles.length; i += 2) ...[
          if (i > 0) const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: tiles[i]),
              const SizedBox(width: 10),
              Expanded(
                child: i + 1 < tiles.length ? tiles[i + 1] : const SizedBox(),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: CanteenSurface(
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
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: p.inkSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A bucket of the trend: a day, or a week or month on longer ranges.
class _Bucket {
  _Bucket(this.start);

  final DateTime start;
  var orders = 0;
  var revenue = 0.0;
}

/// Days for a month, weeks for up to half a year, months beyond — so the
/// bars stay wide enough to read.
List<_Bucket> _buckets(List<CaptainDailyPoint> points) {
  final days = points.length;
  final buckets = <_Bucket>[];
  for (final point in points) {
    final DateTime start;
    if (days <= 31) {
      start = point.date;
    } else if (days <= 186) {
      start = point.date.subtract(Duration(days: point.date.weekday - 1));
    } else {
      start = DateTime(point.date.year, point.date.month);
    }
    if (buckets.isEmpty || buckets.last.start != start) {
      buckets.add(_Bucket(start));
    }
    buckets.last
      ..orders += point.orders
      ..revenue += point.revenue;
  }
  return buckets;
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({
    required this.points,
    required this.metric,
    required this.loading,
  });

  final List<CaptainDailyPoint> points;
  final _TrendMetric metric;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    const height = 120.0;
    if (points.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: loading
              ? const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  'Nothing to chart for this range.',
                  style: TextStyle(color: p.inkSecondary),
                ),
        ),
      );
    }
    final buckets = _buckets(points);
    final values = [
      for (final bucket in buckets)
        metric == _TrendMetric.orders
            ? bucket.orders.toDouble()
            : bucket.revenue,
    ];
    final peak = values.fold<double>(0, math.max);
    final total = values.fold<double>(0, (sum, v) => sum + v);
    String show(double value) => metric == _TrendMetric.orders
        ? '${value.round()}'
        : formatCurrency(value);
    final unit = points.length <= 31
        ? 'day'
        : points.length <= 186
        ? 'week'
        : 'month';
    final gap = buckets.length > 20 ? 2.0 : 4.0;

    return Semantics(
      label:
          '${metric == _TrendMetric.orders ? 'Orders' : 'Revenue'} per $unit: '
          'total ${show(total)}, busiest ${show(peak)}.',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Per $unit',
                style: TextStyle(fontSize: 12, color: p.inkSecondary),
              ),
              const Spacer(),
              Text(
                'Peak ${show(peak)}',
                style: TextStyle(
                  fontSize: 12,
                  color: p.inkSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: height,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < values.length; i++)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: gap / 2),
                      child: Tooltip(
                        message:
                            '${formatShortDate(buckets[i].start)}: ${show(values[i])}',
                        child: Container(
                          height: peak <= 0
                              ? 2
                              : math.max(2, values[i] / peak * height),
                          decoration: BoxDecoration(
                            color: values[i] > 0 ? p.brandInk : p.surfaceSunken,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(3),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                formatShortDate(buckets.first.start),
                style: TextStyle(fontSize: 11, color: p.inkTertiary),
              ),
              const Spacer(),
              if (buckets.length > 1)
                Text(
                  formatShortDate(buckets.last.start),
                  style: TextStyle(fontSize: 11, color: p.inkTertiary),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The orders as an inset-grouped list.
class _OrdersGroup extends StatelessWidget {
  const _OrdersGroup({required this.orders});

  final List<ShopAnalyticsOrder> orders;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: p.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < orders.length; i++) ...[
            if (i > 0) Divider(height: 1, indent: 16, color: p.divider),
            _OrderRow(order: orders[i]),
          ],
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
    final full = order.toCanteenOrder();
    final placed = order.createdAt.toLocal();
    final items = order.lines
        .map(
          (line) => line.quantity > 1
              ? '${line.quantity} × ${line.item.name}'
              : line.item.name,
        )
        .join(', ');
    return InkWell(
      key: ValueKey('captain-order-${order.id}'),
      onTap: () => openCanteenOrderDetail(context, full),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '#${full.displayId} · '
                    '${order.customerName.isEmpty ? 'Campus user' : order.customerName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w600, color: p.ink),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [
                      if (items.isNotEmpty)
                        items
                      else
                        '${order.itemCount} item${order.itemCount == 1 ? '' : 's'}',
                      '${formatShortDate(placed)}, ${formatTime(placed)}',
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: p.inkSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatCurrency(order.total),
                  style: TextStyle(fontWeight: FontWeight.w700, color: p.ink),
                ),
                const SizedBox(height: 4),
                OrderStatusGradientBadge(
                  status: order.orderStatus,
                  fontSize: 10,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2.5,
                  ),
                ),
              ],
            ),
            Icon(Icons.chevron_right_rounded, size: 20, color: p.inkTertiary),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return CanteenSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.cloud_off_rounded, color: p.inkSecondary),
          const SizedBox(height: 8),
          const Text(
            'Couldn’t load this captain',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(userFacingError(error), style: TextStyle(color: p.inkSecondary)),
          TextButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}
