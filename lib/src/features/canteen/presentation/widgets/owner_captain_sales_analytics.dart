import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../data/canteen_models.dart';
import 'canteen_surface.dart';
import 'order_status_badge.dart';

enum CaptainSalesFilter { today, thisWeek, allTime }

/// Dedicated Owner Workspace screen to analyze sales, orders, and fulfillment
/// performance across canteen captains.
class OwnerCaptainSalesAnalytics extends StatefulWidget {
  const OwnerCaptainSalesAnalytics({
    super.key,
    required this.store,
    required this.busy,
    required this.onRefresh,
  });

  final CanteenStore store;
  final bool busy;
  final VoidCallback onRefresh;

  @override
  State<OwnerCaptainSalesAnalytics> createState() =>
      _OwnerCaptainSalesAnalyticsState();
}

class _OwnerCaptainSalesAnalyticsState
    extends State<OwnerCaptainSalesAnalytics> {
  CaptainSalesFilter _filter = CaptainSalesFilter.allTime;
  String? _selectedCaptain;

  List<CanteenOrder> get _filteredOrders {
    final now = DateTime.now();
    return widget.store.orders.where((order) {
      if (_filter == CaptainSalesFilter.today) {
        return order.createdAt.year == now.year &&
            order.createdAt.month == now.month &&
            order.createdAt.day == now.day;
      } else if (_filter == CaptainSalesFilter.thisWeek) {
        final difference = now.difference(order.createdAt).inDays;
        return difference <= 7;
      }
      return true;
    }).toList();
  }

  Map<String, List<CanteenOrder>> get _ordersByCaptain {
    final map = <String, List<CanteenOrder>>{};
    for (final order in _filteredOrders) {
      final name = order.effectiveCaptainName;
      map.putIfAbsent(name, () => []).add(order);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredOrders;
    final byCaptain = _ordersByCaptain;
    final totalRevenue = filtered.fold<double>(
      0,
      (sum, order) =>
          sum +
          (order.status == CanteenOrderStatus.completed ||
                  order.status.isActive
              ? order.total
              : 0),
    );
    final totalOrders = filtered.length;
    final deliveredOrders = filtered
        .where((o) => o.status == CanteenOrderStatus.completed)
        .length;
    final aov = totalOrders > 0 ? (totalRevenue / totalOrders) : 0.0;

    return RefreshIndicator(
      onRefresh: () async => widget.onRefresh(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          // Filter Chips Header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Captain Sales Analytics',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Real-time revenue & fulfillment by captain',
                      style: TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              SegmentedButton<CaptainSalesFilter>(
                segments: const [
                  ButtonSegment(
                    value: CaptainSalesFilter.today,
                    label: Text('Today'),
                  ),
                  ButtonSegment(
                    value: CaptainSalesFilter.thisWeek,
                    label: Text('Week'),
                  ),
                  ButtonSegment(
                    value: CaptainSalesFilter.allTime,
                    label: Text('All'),
                  ),
                ],
                selected: {_filter},
                showSelectedIcon: false,
                onSelectionChanged: (val) =>
                    setState(() => _filter = val.first),
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Overview KPI cards
          Row(
            children: [
              Expanded(
                child: _KpiCard(
                  title: 'Captain Sales',
                  value: formatCurrency(totalRevenue),
                  subtitle: '$totalOrders orders',
                  icon: Icons.payments_rounded,
                  color: const Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _KpiCard(
                  title: 'Delivered',
                  value: '$deliveredOrders',
                  subtitle:
                      '${totalOrders > 0 ? ((deliveredOrders / totalOrders) * 100).toInt() : 0}% fulfilled',
                  icon: Icons.check_circle_rounded,
                  color: const Color(0xFF2563EB),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _KpiCard(
                  title: 'Avg Value',
                  value: formatCurrency(aov),
                  subtitle: '${byCaptain.length} active',
                  icon: Icons.trending_up_rounded,
                  color: const Color(0xFFF59E0B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Section Title: Performance by Captain
          Row(
            children: [
              const Icon(Icons.badge_outlined, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Performance by Captain',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (byCaptain.isEmpty)
            const CanteenSurface(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text('No orders found for the selected period.'),
                ),
              ),
            )
          else
            ...byCaptain.entries.map((entry) {
              final captainName = entry.key;
              final captainOrders = entry.value;
              final captainRevenue = captainOrders.fold<double>(
                0,
                (sum, o) =>
                    sum +
                    (o.status == CanteenOrderStatus.completed ||
                            o.status.isActive
                        ? o.total
                        : 0),
              );
              final revenueRatio =
                  totalRevenue > 0 ? (captainRevenue / totalRevenue) : 0.0;
              final completed = captainOrders
                  .where((o) => o.status == CanteenOrderStatus.completed)
                  .length;
              final active =
                  captainOrders.where((o) => o.status.isActive).length;
              final isSelected = _selectedCaptain == captainName;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedCaptain = isSelected ? null : captainName;
                    });
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: CanteenSurface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor:
                                  AppColors.primary.withValues(alpha: 0.12),
                              foregroundColor: AppColors.primary,
                              child: Text(
                                captainName
                                    .split(' ')
                                    .map((p) => p.isNotEmpty ? p[0] : '')
                                    .take(2)
                                    .join(),
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    captainName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${captainOrders.length} orders · $completed delivered · $active active',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  formatCurrency(captainRevenue),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                    color: Color(0xFF0F766E),
                                  ),
                                ),
                                Text(
                                  '${(revenueRatio * 100).toStringAsFixed(1)}% of sales',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.muted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Sales Share Bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: revenueRatio.clamp(0.0, 1.0),
                            minHeight: 6,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF0F766E),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Status pills summary
                        Row(
                          children: [
                            _MiniStatusPill(
                              label: 'Delivered',
                              count: completed,
                              gradient: OrderStatusGradients.delivered,
                            ),
                            const SizedBox(width: 8),
                            _MiniStatusPill(
                              label: 'In Queue',
                              count: active,
                              gradient: OrderStatusGradients.preparing,
                              darkText: true,
                            ),
                            const Spacer(),
                            Text(
                              isSelected ? 'Hide orders ▲' : 'View orders ▼',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        if (isSelected) ...[
                          const Divider(height: 24),
                          Text(
                            'Recent Orders Handled by $captainName',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...captainOrders.take(10).map((order) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 5),
                              child: Row(
                                children: [
                                  Text(
                                    '#${order.displayId}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      order.customerName ?? 'User',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.muted,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  OrderStatusGradientBadge(
                                    status: order.status,
                                    fontSize: 10,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2.5,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    formatCurrency(order.total),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }),
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.muted,
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
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 10.5,
              color: AppColors.muted,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _MiniStatusPill extends StatelessWidget {
  const _MiniStatusPill({
    required this.label,
    required this.count,
    required this.gradient,
    this.darkText = false,
  });

  final String label;
  final int count;
  final LinearGradient gradient;
  final bool darkText;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$count $label',
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: darkText ? const Color(0xFF78350F) : Colors.white,
        ),
      ),
    );
  }
}
