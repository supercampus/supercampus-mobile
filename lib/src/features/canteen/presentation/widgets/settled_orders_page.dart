import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/module_navigation_buttons.dart';
import '../../data/canteen_models.dart';
import 'canteen_order_detail_page.dart';

enum _DateFilter { all, today, yesterday, picked }

/// Every order the counter has finished with, as a page of its own.
class SettledOrdersPage extends StatelessWidget {
  const SettledOrdersPage({super.key, required this.orders, this.now});

  final List<CanteenOrder> orders;

  /// Fixed "today" for tests; defaults to the clock.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.palette.canvas,
      appBar: AppBar(
        titleSpacing: 0,
        leading: ModuleBackButton(
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('Settled orders'),
      ),
      body: SafeArea(
        top: false,
        child: SettledOrdersView(orders: orders, now: now),
      ),
    );
  }
}

/// Every order the counter has finished with, searchable and by day — the
/// owner workspace's Settled destination, or the body of [SettledOrdersPage].
class SettledOrdersView extends StatefulWidget {
  const SettledOrdersView({
    super.key,
    required this.orders,
    this.now,
    this.showTitle = false,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 32),
  });

  /// Delivered, rejected and cancelled orders (any order order).
  final List<CanteenOrder> orders;

  /// Fixed "today" for tests; defaults to the clock.
  final DateTime? now;

  /// Leads with a "Settled orders" heading, for use inside a workspace.
  final bool showTitle;
  final EdgeInsetsGeometry padding;

  @override
  State<SettledOrdersView> createState() => _SettledOrdersViewState();
}

class _SettledOrdersViewState extends State<SettledOrdersView> {
  final _search = TextEditingController();
  var _query = '';
  var _filter = _DateFilter.all;
  DateTime? _picked;

  DateTime get _today => widget.now ?? DateTime.now();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matchesDate(CanteenOrder order) {
    final placed = order.createdAt.toLocal();
    return switch (_filter) {
      _DateFilter.all => true,
      _DateFilter.today => isSameDay(placed, _today),
      _DateFilter.yesterday => isSameDay(
        placed,
        _today.subtract(const Duration(days: 1)),
      ),
      _DateFilter.picked => _picked != null && isSameDay(placed, _picked!),
    };
  }

  bool _matchesQuery(CanteenOrder order) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    final number = order.displayId.toLowerCase();
    return number.contains(q.replaceAll('#', '')) ||
        (order.customerName ?? '').toLowerCase().contains(q) ||
        order.lines.any((line) => line.item.name.toLowerCase().contains(q));
  }

  Future<void> _pickDate() async {
    final today = _today;
    final picked = await showDatePicker(
      context: context,
      initialDate: _picked ?? today,
      firstDate: DateTime(today.year - 2),
      lastDate: today,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _picked = picked;
      _filter = _DateFilter.picked;
    });
  }

  String _dayLabel(DateTime day) {
    if (isSameDay(day, _today)) return 'Today';
    if (isSameDay(day, _today.subtract(const Duration(days: 1)))) {
      return 'Yesterday';
    }
    return formatShortDate(day);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final visible = [
      for (final order in widget.orders)
        if (_matchesDate(order) && _matchesQuery(order)) order,
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // Grouped by the day they were placed, newest day first.
    final days = <DateTime, List<CanteenOrder>>{};
    for (final order in visible) {
      final placed = order.createdAt.toLocal();
      days
          .putIfAbsent(
            DateTime(placed.year, placed.month, placed.day),
            () => <CanteenOrder>[],
          )
          .add(order);
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: widget.padding,
          children: [
            if (widget.showTitle) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Settled orders',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  Text(
                    '${widget.orders.length}',
                    style: TextStyle(fontSize: 12, color: p.inkSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _search,
              onChanged: (value) => setState(() => _query = value),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search order, customer or item',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _search.clear();
                          setState(() => _query = '');
                        },
                      ),
                filled: true,
                fillColor: p.surfaceSunken,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final (filter, label) in const [
                    (_DateFilter.all, 'All'),
                    (_DateFilter.today, 'Today'),
                    (_DateFilter.yesterday, 'Yesterday'),
                  ]) ...[
                    ChoiceChip(
                      label: Text(label),
                      selected: _filter == filter,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _filter = filter),
                    ),
                    const SizedBox(width: 8),
                  ],
                  ChoiceChip(
                    avatar: const Icon(Icons.calendar_today_outlined, size: 16),
                    label: Text(
                      _filter == _DateFilter.picked && _picked != null
                          ? formatShortDate(_picked!)
                          : 'Pick date',
                    ),
                    selected: _filter == _DateFilter.picked,
                    showCheckmark: false,
                    onSelected: (_) => _pickDate(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (visible.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: Text(
                    widget.orders.isEmpty
                        ? 'Nothing settled yet.'
                        : 'No settled orders match.',
                    style: TextStyle(color: p.inkSecondary),
                  ),
                ),
              )
            else
              for (final entry in days.entries) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _dayLabel(entry.key).toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.4,
                            color: p.inkSecondary,
                          ),
                        ),
                      ),
                      Text(
                        '${entry.value.length} · ${formatCurrency(_revenue(entry.value))}',
                        style: TextStyle(fontSize: 12, color: p.inkSecondary),
                      ),
                    ],
                  ),
                ),
                _OrdersGroup(orders: entry.value),
                const SizedBox(height: 12),
              ],
          ],
        ),
      ),
    );
  }

  static double _revenue(List<CanteenOrder> orders) => orders
      .where((order) => order.status == CanteenOrderStatus.completed)
      .fold<double>(0, (sum, order) => sum + order.total);
}

/// One day's settled orders as an inset-grouped list.
class _OrdersGroup extends StatelessWidget {
  const _OrdersGroup({required this.orders});

  final List<CanteenOrder> orders;

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
            if (i > 0) Divider(height: 1, indent: 48, color: p.divider),
            SettledOrderTile(order: orders[i]),
          ],
        ],
      ),
    );
  }
}

/// A settled order as one row; tapping it opens the order's details.
class SettledOrderTile extends StatelessWidget {
  const SettledOrderTile({super.key, required this.order});

  final CanteenOrder order;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final stopped =
        order.status == CanteenOrderStatus.rejected ||
        order.status == CanteenOrderStatus.cancelled;
    final placed = order.createdAt.toLocal();
    final items = order.lines
        .map(
          (line) => line.quantity > 1
              ? '${line.quantity} × ${line.item.name}'
              : line.item.name,
        )
        .join(', ');
    return InkWell(
      key: ValueKey('settled-order-${order.id}'),
      onTap: () => openCanteenOrderDetail(context, order),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(
                stopped ? Icons.close_rounded : Icons.check_rounded,
                size: 20,
                color: stopped ? p.danger : p.success,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    items.isEmpty ? 'Order #${order.displayId}' : items,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                      color: p.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '#${order.displayId} · ${order.customerName ?? 'Campus user'}'
                    ' · ${formatTime(placed)}'
                    '${stopped ? ' · ${order.status.label}' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: p.inkSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              formatCurrency(order.total),
              style: TextStyle(fontWeight: FontWeight.w700, color: p.ink),
            ),
            Icon(Icons.chevron_right_rounded, size: 20, color: p.inkTertiary),
          ],
        ),
      ),
    );
  }
}
