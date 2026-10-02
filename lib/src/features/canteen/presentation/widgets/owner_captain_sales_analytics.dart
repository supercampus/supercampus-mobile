import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/user_facing_error.dart';
import '../../data/canteen_models.dart';
import '../../data/shop_analytics.dart';
import 'canteen_surface.dart';
import 'captain_performance_page.dart';

/// Loads one shop's analytics for a date range from the server.
typedef ShopAnalyticsLoader =
    Future<ShopAnalyticsReport> Function(
      String shopKey,
      AnalyticsDateRange range,
    );

/// Loads one staff member's detail — figures, daily series and a page of
/// their actions — for a shop and date range.
typedef CaptainDetailLoader =
    Future<CaptainPerformanceDetail> Function(
      String shopKey,
      String captainId,
      AnalyticsDateRange range,
      int page,
    );

/// The quick ranges above the figures; [custom] is a picked range.
enum SalesRangePreset { today, last7Days, last30Days, thisMonth, custom }

extension SalesRangePresetRange on SalesRangePreset {
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

/// What a figure that was never recorded shows instead of a guess.
const notRecorded = 'Not recorded';

/// The owner workspace's Sales destination: one shop's revenue, cost and
/// profit over a chosen range, and what each of its captains did. Each
/// captain is a card that opens their own page for the same range.
///
/// With [loadAnalytics] and a [shopKey] every figure comes from the server
/// for the selected range. Without the endpoint (the offline demo) the shop
/// summary is rolled up from [store]'s orders and no one is credited, since
/// the device has no record of who handled which item.
class OwnerCaptainSalesAnalytics extends StatefulWidget {
  const OwnerCaptainSalesAnalytics({
    super.key,
    required this.store,
    required this.busy,
    required this.onRefresh,
    this.shopKey,
    this.shopName,
    this.loadAnalytics,
    this.loadCaptainDetail,
    this.today,
  });

  final CanteenStore store;
  final bool busy;
  final VoidCallback onRefresh;
  final String? shopKey;
  final String? shopName;
  final ShopAnalyticsLoader? loadAnalytics;

  /// Loads a captain's own page.
  final CaptainDetailLoader? loadCaptainDetail;

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
    if (oldWidget.shopKey != widget.shopKey) _load();
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
    _select(
      SalesRangePreset.custom,
      AnalyticsDateRange(picked.start, picked.end),
    );
  }

  Future<void> _refresh() async {
    widget.onRefresh();
    await _load();
  }

  ShopAnalyticsReport? get _visibleReport {
    if (_remote) return _report;
    // Connected to the server but no shop chosen: there is nothing real to
    // show, and the device's orders are no stand-in for the server's record.
    if (widget.loadAnalytics != null) return null;
    return localShopAnalytics(
      orders: widget.store.orders,
      range: _range,
      shopKey: widget.shopKey ?? '',
      shopName: widget.shopName ?? '',
    );
  }

  Future<void> _openCaptain(CaptainPerformance captain) async {
    final shopKey = widget.shopKey;
    final loader = widget.loadCaptainDetail;
    if (loader == null || shopKey == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => CaptainPerformancePage(
          captain: captain,
          shopName: widget.shopName,
          preset: _preset,
          range: _range,
          today: _today,
          load: (range, page) => loader(shopKey, captain.userId, range, page),
          // The list follows a range picked on the captain's page, so going
          // back shows the same days.
          onRangeChanged: (preset, range) {
            if (mounted) _select(preset, range);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final report = _visibleReport;
    final noShop = !_remote && widget.loadAnalytics != null;

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
            salesRangeLabel(_range),
            key: const ValueKey('sales-range-label'),
            style: TextStyle(fontSize: 13, color: p.inkSecondary),
          ),
          const SizedBox(height: 12),
          SalesRangeBar(
            selected: _preset,
            customLabel: _preset == SalesRangePreset.custom
                ? shortSalesRange(_range)
                : null,
            onPreset: (preset) => _select(preset, preset.range(_today)),
            onCustom: _pickCustom,
          ),
          const SizedBox(height: 16),
          if (noShop)
            const _Message(
              key: ValueKey('sales-no-shop'),
              icon: Icons.storefront_outlined,
              body: 'Choose a shop to see its sales.',
            )
          else if (_loading && report == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null && report == null)
            _Message(
              icon: Icons.cloud_off_rounded,
              title: 'Couldn’t load sales',
              body: userFacingError(_error!),
              action: TextButton(
                onPressed: _load,
                child: const Text('Try again'),
              ),
            )
          else if (report != null) ...[
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            _SummaryGrid(summary: report.summary),
            const SizedBox(height: 12),
            _OutcomeCard(summary: report.summary),
            const SizedBox(height: 28),
            Text(
              'Performance by Captain',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              report.staffRecorded
                  ? 'Each item is credited to whoever prepared it or handed '
                        'it over, by when they did it.'
                  : 'Who handled each item is recorded by the campus server; '
                        'this device has no such record.',
              style: TextStyle(fontSize: 12, color: p.inkSecondary),
            ),
            const SizedBox(height: 12),
            if (report.staffRecorded) ...[
              _DeliveredTotal(staff: report.staff),
              const SizedBox(height: 10),
              if (report.captains.isEmpty)
                const _Message(
                  key: ValueKey('captains-empty'),
                  icon: Icons.badge_outlined,
                  body: noCaptainsAssignedMessage,
                )
              else
                for (final captain in report.captains)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _CaptainCard(
                      captain: captain,
                      onOpen: () => _openCaptain(captain),
                    ),
                  ),
              if (report.staff.unattributed.orders > 0)
                _UnattributedCard(history: report.staff.unattributed),
            ],
          ],
        ],
      ),
    );
  }
}

/// What the Sales page says when nobody is assigned to the shop's counter.
const noCaptainsAssignedMessage =
    'No captains are assigned to this shop yet — the admin can add them in '
    'Vendors & shops → Counter staff.';

/// The range in words: one day, or both ends and the length.
String salesRangeLabel(AnalyticsDateRange range) {
  if (range.days == 1) return formatShortDate(range.from);
  return '${formatShortDate(range.from)} – ${formatShortDate(range.to)} · '
      '${range.days} days';
}

/// The range as a chip label.
String shortSalesRange(AnalyticsDateRange range) {
  String day(DateTime value) =>
      formatShortDate(value).split(' ').take(2).join(' ');
  return range.days == 1
      ? day(range.from)
      : '${day(range.from)} – ${day(range.to)}';
}

/// Minutes as "12 min" or "1 h 5 min"; [missing] when nothing was timed.
String formatHandlingMinutes(double? minutes, {String missing = '—'}) {
  if (minutes == null) return missing;
  return formatDurationSeconds(minutes * 60, missing: missing);
}

/// Seconds as "45 s", "4 min 10 s" or "1 h 5 min"; [missing] when nothing
/// was timed.
String formatDurationSeconds(double? seconds, {String missing = '—'}) {
  if (seconds == null) return missing;
  final total = seconds.round();
  if (total < 60) return '$total s';
  if (total < 3600) {
    final rest = total % 60;
    return rest == 0 ? '${total ~/ 60} min' : '${total ~/ 60} min $rest s';
  }
  final hours = total ~/ 3600;
  final minutes = (total % 3600) ~/ 60;
  return minutes == 0 ? '$hours h' : '$hours h $minutes min';
}

/// [amount] as currency, or [missing] when it was not recorded.
String formatRecordedCurrency(double? amount, {String missing = notRecorded}) =>
    amount == null ? missing : formatCurrency(amount);

/// "1 item" / "3 items".
String itemCountLabel(int count) => '$count item${count == 1 ? '' : 's'}';

/// The quick ranges and the custom-range chip.
class SalesRangeBar extends StatelessWidget {
  const SalesRangeBar({
    super.key,
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
                      avatar: const Icon(
                        Icons.calendar_month_rounded,
                        size: 16,
                      ),
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
    final uncosted = summary.uncostedItems > 0
        ? '${itemCountLabel(summary.uncostedItems)} without a cost price'
        : null;
    final margin = summary.marginPercent;
    final tiles = [
      _KpiCard(
        key: const ValueKey('summary-sales'),
        title: 'Sales',
        value: formatCurrency(summary.revenue),
        subtitle: '${summary.completedOrders} delivered orders',
        icon: Icons.payments_rounded,
        color: p.info,
      ),
      _KpiCard(
        key: const ValueKey('summary-profit'),
        title: 'Net profit',
        value: formatRecordedCurrency(summary.profit),
        subtitle:
            uncosted ??
            (margin == null ? '—' : '${margin.toStringAsFixed(1)}% margin'),
        icon: Icons.trending_up_rounded,
        color: p.success,
      ),
      _KpiCard(
        key: const ValueKey('summary-cost'),
        title: 'Cost',
        value: formatRecordedCurrency(summary.cost),
        subtitle: '${summary.itemsSold} items sold',
        icon: Icons.inventory_2_outlined,
        color: p.warning,
      ),
      _KpiCard(
        key: const ValueKey('summary-orders'),
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
  const _OutcomeCard({required this.summary});

  final ShopSalesFigures summary;

  @override
  Widget build(BuildContext context) {
    final waiting = summary.waitingOrders;
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
            key: const ValueKey('summary-handling'),
            label: 'Avg. time to deliver',
            value: formatHandlingMinutes(
              summary.averageHandlingMinutes,
              missing: notRecorded,
            ),
            detail: summary.timedOrders > 0
                ? 'Placed → last item handed over · '
                      '${summary.timedOrders} of ${summary.completedOrders} '
                      'delivered orders timed'
                : null,
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    super.key,
    required this.label,
    required this.value,
    this.detail,
  });

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
          const SizedBox(width: 8),
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

/// Everything handed over in the range — the base of every captain's share.
class _DeliveredTotal extends StatelessWidget {
  const _DeliveredTotal({required this.staff});

  final StaffSummary staff;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Text(
      'Handed over in this range: ${formatCurrency(staff.totalRevenue)} · '
      '${itemCountLabel(staff.totalItems)}',
      key: const ValueKey('staff-delivered-total'),
      style: TextStyle(
        fontSize: 13,
        color: p.inkSecondary,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

/// A captain at a glance: who, what they handed over, their share of the
/// range's deliveries and how quickly. Tapping opens their page.
class _CaptainCard extends StatelessWidget {
  const _CaptainCard({required this.captain, required this.onOpen});

  final CaptainPerformance captain;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final f = captain.figures;
    final role = captainRoleLabel(captain.role);
    final summary = f.idle
        ? '$role · no activity in this range'
        : [
            role,
            '${itemCountLabel(f.itemsDelivered)} handed over',
            if (f.itemsPrepared > 0) '${f.itemsPrepared} prepared',
          ].join(' · ');

    return Semantics(
      button: true,
      label:
          '${captain.name}, $summary, ${formatCurrency(f.revenue)}. '
          'Opens their performance.',
      excludeSemantics: true,
      child: CanteenSurface(
        key: ValueKey('captain-${captain.userId}'),
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CaptainAvatar(name: captain.name, radius: 20),
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
                          letterSpacing: -0.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        summary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: p.inkSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  formatCurrency(f.revenue),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(Icons.chevron_right_rounded, color: p.inkTertiary),
              ],
            ),
            const SizedBox(height: 12),
            _ShareBar(share: f.revenueShare),
            const SizedBox(height: 12),
            Row(
              children: [
                _Stat(label: 'Orders', value: '${f.ordersDelivered}'),
                _Stat(label: 'Share', value: formatShare(f.revenueShare)),
                _Stat(
                  label: 'Hand-over',
                  value: formatDurationSeconds(f.averageHandoverSeconds),
                ),
                _Stat(
                  label: 'Profit',
                  value: formatRecordedCurrency(f.profit, missing: '—'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A share as "52%" or "4.8%".
String formatShare(double share) =>
    '${share.toStringAsFixed(share % 1 == 0 ? 0 : 1)}%';

class _ShareBar extends StatelessWidget {
  const _ShareBar({required this.share, this.muted = false});

  final double share;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: (share / 100).clamp(0.0, 1.0),
        minHeight: 6,
        backgroundColor: p.surfaceSunken,
        valueColor: AlwaysStoppedAnimation<Color>(
          muted ? p.inkTertiary : p.brandInk,
        ),
      ),
    );
  }
}

/// Deliveries from before the counter recorded who handled each item: shown
/// as they are rather than credited to whoever last touched the order.
class _UnattributedCard extends StatelessWidget {
  const _UnattributedCard({required this.history});

  final UnattributedHistory history;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return CanteenSurface(
      key: const ValueKey('unattributed-history'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: p.surfaceSunken,
                foregroundColor: p.inkSecondary,
                child: const Icon(Icons.history_rounded, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Unattributed',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${history.orders} '
                      'order${history.orders == 1 ? '' : 's'} · '
                      '${itemCountLabel(history.items)} · '
                      '${formatShare(history.revenueShare)}',
                      style: TextStyle(fontSize: 12, color: p.inkSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                formatCurrency(history.revenue),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _ShareBar(share: history.revenueShare, muted: true),
          const SizedBox(height: 10),
          Text(
            'Handed over before the counter recorded who handled each item, '
            'so they are not credited to anyone.',
            style: TextStyle(fontSize: 12, color: p.inkSecondary),
          ),
        ],
      ),
    );
  }
}

/// A person's initials in a soft brand circle.
class CaptainAvatar extends StatelessWidget {
  const CaptainAvatar({super.key, required this.name, this.radius = 20});

  final String name;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final initials = name
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .map((word) => word[0].toUpperCase())
        .take(2)
        .join();
    return CircleAvatar(
      radius: radius,
      backgroundColor: p.brandInk.withValues(alpha: 0.12),
      foregroundColor: p.brandInk,
      child: Text(
        initials.isEmpty ? '?' : initials,
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: radius * 0.7),
      ),
    );
  }
}

/// How the shop knows a staff member.
String captainRoleLabel(String? role) => switch (role) {
  'captain' => 'Captain',
  'owner' => 'Owner',
  null => 'Not assigned here',
  final other => other,
};

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

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    super.key,
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
    super.key,
    required this.icon,
    this.title,
    required this.body,
    this.action,
  });

  final IconData icon;
  final String? title;
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
            if (title != null) ...[
              Text(title!, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
            ],
            Text(body, style: TextStyle(color: p.inkSecondary)),
            if (action != null) ...[const SizedBox(height: 4), action!],
          ],
        ),
      ),
    );
  }
}
