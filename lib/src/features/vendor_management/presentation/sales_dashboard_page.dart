part of 'vendor_management_shell.dart';

/// Sales for one period: KPIs, revenue over time, revenue by store, order
/// outcomes, the live counters and best sellers — all measured server-side.
class _SalesDashboardPage extends StatefulWidget {
  const _SalesDashboardPage({
    required this.repository,
    required this.institutionName,
    required this.onStoresLoaded,
    required this.onOpenOrders,
  });

  final VendorRepository repository;
  final String? institutionName;
  final ValueChanged<List<StoreSales>> onStoresLoaded;

  /// Jumps to the Orders tab with a status (and optionally a store) chosen.
  final void Function({OrderStatusFilter status, String? shopKey}) onOpenOrders;

  @override
  State<_SalesDashboardPage> createState() => _SalesDashboardPageState();
}

class _SalesDashboardPageState extends State<_SalesDashboardPage> {
  var _period = SalesPeriod.today;
  SalesDashboardData? _data;
  Object? _error;
  bool _loading = true;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final request = ++_request;
    final period = _period;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.repository.getSalesDashboard(period: period);
      // A newer period was picked while this one loaded; drop the stale answer.
      if (!mounted || request != _request) return;
      setState(() {
        _data = data;
        _loading = false;
      });
      widget.onStoresLoaded(data.stores);
    } catch (error) {
      if (!mounted || request != _request) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  void _selectPeriod(SalesPeriod period) {
    if (period == _period) return;
    setState(() => _period = period);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final error = _error;
    if (data == null && error != null) {
      return _loadFailure(error, _load, "You don't have access to sales figures.");
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _header(context, data),
          const SizedBox(height: 14),
          _Segments<SalesPeriod>(
            values: SalesPeriod.values,
            selected: _period,
            label: (p) => switch (p) {
              SalesPeriod.today => 'Today',
              SalesPeriod.week => 'Week',
              SalesPeriod.month => 'Month',
              SalesPeriod.all => 'All time',
            },
            onChanged: _selectPeriod,
          ),
          SizedBox(
            height: 3,
            child: _loading && data != null
                ? const LinearProgressIndicator(minHeight: 2)
                : null,
          ),
          const SizedBox(height: 11),
          if (data == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 80),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            if (error != null) ...[
              _InlineError(message: userFacingError(error), onRetry: _load),
              const SizedBox(height: 12),
            ],
            _KpiGrid(summary: data.summary, period: data.period),
            const SizedBox(height: 14),
            _RevenueChartCard(data: data),
            const SizedBox(height: 14),
            _StoreRevenueCard(
              data: data,
              onOpenStore: (shopKey) => widget.onOpenOrders(shopKey: shopKey),
            ),
            const SizedBox(height: 14),
            _StatusCard(
              summary: data.summary,
              period: data.period,
              onOpen: (status) => widget.onOpenOrders(status: status),
            ),
            const SizedBox(height: 14),
            _LiveCountersCard(stores: data.stores),
            if (data.topItems.isNotEmpty) ...[
              const SizedBox(height: 14),
              _TopItemsCard(data: data),
            ],
          ],
        ],
      ),
    );
  }

  Widget _header(BuildContext context, SalesDashboardData? data) {
    final p = context.palette;
    final name = widget.institutionName?.trim();
    final updated = data?.generatedAt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name != null && name.isNotEmpty ? name : 'Campus shops',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: p.inkSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          updated == null
              ? 'Orders and sales across campus shops'
              : 'Orders and sales across campus shops · updated '
                    '${DateFormat('h:mm a').format(updated).toLowerCase()}',
          style: TextStyle(fontSize: 12.5, color: p.inkTertiary),
        ),
      ],
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
      decoration: BoxDecoration(
        color: p.dangerSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, size: 18, color: p.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: TextStyle(fontSize: 13, color: p.ink)),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.summary, required this.period});

  final SalesSummary summary;
  final SalesPeriod period;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      _KpiTile(
        label: 'Orders',
        value: formatCount(summary.orders),
        caption: '${formatCount(summary.completedOrders)} completed',
        icon: Icons.receipt_long_rounded,
      ),
      _KpiTile(
        label: 'Revenue',
        value: formatRupees(summary.revenue),
        caption: 'Completed sales',
        icon: Icons.currency_rupee_rounded,
      ),
      _KpiTile(
        label: 'Avg. order',
        value: formatRupees(summary.averageOrderValue),
        caption: 'Per completed order',
        icon: Icons.shopping_basket_rounded,
      ),
      _KpiTile(
        label: 'Pending now',
        value: formatCount(summary.pendingNow),
        caption: 'Waiting at counters',
        icon: Icons.hourglass_top_rounded,
        highlight: summary.pendingNow > 0,
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

class _KpiTile extends StatelessWidget {
  const _KpiTile({
    required this.label,
    required this.value,
    required this.caption,
    required this.icon,
    this.highlight = false,
  });

  final String label;
  final String value;
  final String caption;
  final IconData icon;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      label: '$label $value, $caption',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: p.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: highlight ? p.warning : p.brandInk),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: p.inkSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.6,
                  height: 1.1,
                  color: highlight ? p.warning : p.ink,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: p.inkTertiary),
            ),
          ],
        ),
      ),
    );
  }
}

class _RevenueChartCard extends StatefulWidget {
  const _RevenueChartCard({required this.data});

  final SalesDashboardData data;

  @override
  State<_RevenueChartCard> createState() => _RevenueChartCardState();
}

class _RevenueChartCardState extends State<_RevenueChartCard> {
  int? _selected;

  @override
  void didUpdateWidget(covariant _RevenueChartCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) _selected = null;
  }

  String _slotLabel(TrendPoint point, TrendUnit unit) => switch (unit) {
    TrendUnit.hour =>
      '${DateFormat('h a').format(point.start).toLowerCase()}–'
          '${DateFormat('h a').format(point.start.add(const Duration(hours: 1))).toLowerCase()}',
    TrendUnit.day => DateFormat('EEE, d MMM').format(point.start),
    TrendUnit.month => DateFormat('MMMM yyyy').format(point.start),
  };

  String? _axisLabel(int index, TrendPoint point, TrendUnit unit, int count) {
    switch (unit) {
      case TrendUnit.hour:
        return point.start.hour % 6 == 0
            ? DateFormat('h a').format(point.start).toLowerCase()
            : null;
      case TrendUnit.day:
        if (count <= 7) return DateFormat('EEE').format(point.start);
        return (point.start.day - 1) % 7 == 0 ? '${point.start.day}' : null;
      case TrendUnit.month:
        return count <= 6 || index.isEven
            ? DateFormat('MMM').format(point.start)
            : null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final trend = widget.data.trend;
    final points = trend.points;
    final unitWord = switch (trend.unit) {
      TrendUnit.hour => 'hour',
      TrendUnit.day => 'day',
      TrendUnit.month => 'month',
    };
    final periodText = widget.data.period == SalesPeriod.all
        ? 'last 12 months'
        : widget.data.period.label.toLowerCase();
    final selected = _selected != null && _selected! < points.length
        ? points[_selected!]
        : null;
    final peak = trend.peakRevenue;

    return _SectionCard(
      title: 'Revenue over time',
      subtitle: 'Completed sales per $unitWord · $periodText',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            selected == null
                ? (trend.hasSales
                      ? 'Peak ${formatRupees(peak)} · tap a bar for detail'
                      : 'No completed sales ${widget.data.period == SalesPeriod.today ? 'today' : 'in this period'} yet.')
                : '${_slotLabel(selected, trend.unit)} · ${formatRupees(selected.revenue)}'
                      ' · ${formatCount(selected.orders)} order${selected.orders == 1 ? '' : 's'}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected == null ? FontWeight.w400 : FontWeight.w600,
              color: selected == null ? p.inkSecondary : p.ink,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 132,
            child: points.isEmpty
                ? const SizedBox.shrink()
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (var i = 0; i < points.length; i++)
                        Expanded(
                          child: Semantics(
                            button: true,
                            label:
                                '${_slotLabel(points[i], trend.unit)}, ${formatRupees(points[i].revenue)}',
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => setState(
                                () => _selected = _selected == i ? null : i,
                              ),
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: points.length > 16 ? 1 : 3,
                                ),
                                child: Align(
                                  alignment: Alignment.bottomCenter,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 240),
                                    curve: Curves.easeOutCubic,
                                    height: peak <= 0
                                        ? 3
                                        : 3 + 129 * (points[i].revenue / peak),
                                    decoration: BoxDecoration(
                                      color: points[i].isFuture
                                          ? p.surfaceMuted
                                          : points[i].revenue <= 0
                                          ? p.border
                                          : (_selected == null || _selected == i)
                                          ? p.brand
                                          : p.brand.withValues(alpha: 0.35),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
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
          SizedBox(
            height: 16,
            child: Row(
            children: [
              for (var i = 0; i < points.length; i++)
                Expanded(
                  child: OverflowBox(
                    maxWidth: 48,
                    maxHeight: 16,
                    child: Text(
                      _axisLabel(i, points[i], trend.unit, points.length) ?? '',
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10.5, color: p.inkTertiary),
                    ),
                  ),
                ),
            ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StoreRevenueCard extends StatelessWidget {
  const _StoreRevenueCard({required this.data, required this.onOpenStore});

  final SalesDashboardData data;
  final ValueChanged<String> onOpenStore;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final stores = data.stores;
    final topRevenue = stores.fold<double>(
      0,
      (top, s) => s.revenue > top ? s.revenue : top,
    );
    return _SectionCard(
      title: 'Sales by store',
      subtitle: '${data.period.label} · completed revenue and orders',
      child: stores.isEmpty
          ? Text(
              'No shops are set up yet.',
              style: TextStyle(color: p.inkSecondary, fontSize: 13.5),
            )
          : Column(
              children: [
                for (final store in stores)
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => onOpenStore(store.shopKey),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          _ShopAvatar(store.category, size: 36),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        store.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w600,
                                          color: p.ink,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      formatRupees(store.revenue),
                                      style: TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w600,
                                        color: p.ink,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(3),
                                  child: LinearProgressIndicator(
                                    value: topRevenue <= 0
                                        ? 0
                                        : store.revenue / topRevenue,
                                    minHeight: 5,
                                    backgroundColor: p.surfaceSunken,
                                    color: p.brand,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  '${store.category} · ${formatCount(store.orders)} '
                                  'order${store.orders == 1 ? '' : 's'}'
                                  '${store.revenueShare > 0 ? ' · ${store.revenueShare}% of revenue' : ''}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: p.inkSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.summary,
    required this.period,
    required this.onOpen,
  });

  final SalesSummary summary;
  final SalesPeriod period;
  final ValueChanged<OrderStatusFilter> onOpen;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final buckets = [
      (OrderStatusFilter.completed, summary.completedOrders, p.success),
      (OrderStatusFilter.active, summary.activeOrders, p.warning),
      (OrderStatusFilter.cancelled, summary.cancelledOrders, p.danger),
    ];
    return _SectionCard(
      title: 'Order status',
      subtitle: '${period.label} · ${formatCount(summary.orders)} '
          'order${summary.orders == 1 ? '' : 's'}',
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: SizedBox(
              height: 10,
              child: summary.orders == 0
                  ? ColoredBox(color: p.surfaceSunken)
                  : Row(
                      children: [
                        for (final (_, count, color) in buckets)
                          if (count > 0)
                            Expanded(
                              flex: count,
                              child: ColoredBox(color: color),
                            ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 8),
          for (final (status, count, color) in buckets)
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => onOpen(status),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        status.label,
                        style: TextStyle(fontSize: 14, color: p.ink),
                      ),
                    ),
                    Text(
                      '${formatCount(count)} · ${summary.percentOf(count)}%',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: p.ink,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: p.inkTertiary,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LiveCountersCard extends StatelessWidget {
  const _LiveCountersCard({required this.stores});

  final List<StoreSales> stores;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    // The administrator's shop sequence, as every other shop list shows it.
    final registered = stores.where((s) => s.id != null).toList()
      ..sort(compareStoresByPosition);
    return _SectionCard(
      title: 'Counters right now',
      subtitle: "Open or closed, today's orders and the live queue",
      child: registered.isEmpty
          ? Text(
              'No shops are set up yet.',
              style: TextStyle(color: p.inkSecondary, fontSize: 13.5),
            )
          : Column(
              children: [
                for (var i = 0; i < registered.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: p.divider),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      registered[i].name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w600,
                                        color: p.ink,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _tradingPill(
                                    context,
                                    active: registered[i].isActive,
                                    open: registered[i].isOpen,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${formatCount(registered[i].ordersToday)} '
                                'order${registered[i].ordersToday == 1 ? '' : 's'} today · '
                                '${formatRupees(registered[i].revenueToday)}',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: p.inkSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              formatCount(registered[i].activeNow),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: registered[i].activeNow > 0
                                    ? p.warning
                                    : p.inkTertiary,
                              ),
                            ),
                            Text(
                              'in queue',
                              style: TextStyle(
                                fontSize: 11,
                                color: p.inkTertiary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class _TopItemsCard extends StatelessWidget {
  const _TopItemsCard({required this.data});

  final SalesDashboardData data;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return _SectionCard(
      title: 'Top sellers',
      subtitle: '${data.period.label} · by quantity from completed orders',
      child: Column(
        children: [
          for (var i = 0; i < data.topItems.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  SizedBox(
                    width: 22,
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: p.inkTertiary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data.topItems[i].name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: p.ink,
                          ),
                        ),
                        Text(
                          data.storeName(data.topItems[i].shopKey),
                          style: TextStyle(
                            fontSize: 12,
                            color: p.inkSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${formatCount(data.topItems[i].quantity)} sold',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: p.ink,
                        ),
                      ),
                      Text(
                        formatRupees(data.topItems[i].revenue),
                        style: TextStyle(fontSize: 12, color: p.inkSecondary),
                      ),
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
