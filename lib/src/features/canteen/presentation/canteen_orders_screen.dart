import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../data/canteen_models.dart';
import 'widgets/canteen_surface.dart';

enum OrderFilter { active, history }

class CanteenOrdersScreen extends StatefulWidget {
  const CanteenOrdersScreen({super.key, required this.orders});

  final List<CanteenOrder> orders;

  @override
  State<CanteenOrdersScreen> createState() => _CanteenOrdersScreenState();
}

class _CanteenOrdersScreenState extends State<CanteenOrdersScreen> {
  OrderFilter _filter = OrderFilter.active;

  List<CanteenOrder> get _visibleOrders {
    final active = widget.orders
        .where((order) => order.status.isActive)
        .toList();
    if (_filter == OrderFilter.active) return active;
    return widget.orders.where((order) => !order.status.isActive).toList();
  }

  @override
  Widget build(BuildContext context) {
    return CanteenPageBody(
      children: [
        CanteenPageHeader(
          title: 'My orders',
          subtitle: 'Track active and completed orders',
          trailing: IconButton.outlined(
            tooltip: 'Refresh orders',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Orders are up to date.')),
              );
            },
            icon: const Icon(Icons.refresh),
          ),
        ),
        const SizedBox(height: 20),
        SegmentedButton<OrderFilter>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: OrderFilter.active, label: Text('Active')),
            ButtonSegment(value: OrderFilter.history, label: Text('History')),
          ],
          selected: {_filter},
          onSelectionChanged: (selection) =>
              setState(() => _filter = selection.first),
        ),
        const SizedBox(height: 16),
        if (_visibleOrders.isEmpty)
          const CanteenSurface(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 34),
              child: Column(
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 38,
                    color: AppColors.muted,
                  ),
                  SizedBox(height: 12),
                  Text('No active orders right now.'),
                ],
              ),
            ),
          )
        else
          for (final order in _visibleOrders)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _OrderCard(order: order),
            ),
      ],
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final CanteenOrder order;

  @override
  Widget build(BuildContext context) {
    final active = order.status.isActive;
    final statusColor = switch (order.status) {
      CanteenOrderStatus.preparing => const Color(0xFFB96708),
      CanteenOrderStatus.ready => AppColors.success,
      CanteenOrderStatus.completed => AppColors.primary,
      CanteenOrderStatus.cancelled => Theme.of(context).colorScheme.error,
    };

    return CanteenSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '#${order.id}',
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  order.status.label,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            '${formatShortDate(order.createdAt)} · ${formatTime(order.createdAt)}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const Divider(height: 26),
          for (final line in order.lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Text(
                    '${line.quantity}×',
                    style: const TextStyle(color: AppColors.primary),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(line.item.name)),
                  Text(formatCurrency(line.total)),
                ],
              ),
            ),
          const Divider(height: 24),
          Row(
            children: [
              Icon(
                order.fulfilmentMode == FulfilmentMode.dineIn
                    ? Icons.table_restaurant_outlined
                    : Icons.shopping_bag_outlined,
                size: 19,
                color: AppColors.muted,
              ),
              const SizedBox(width: 7),
              Text(order.fulfilmentMode.label),
              if (active && order.tokenNumber != null) ...[
                const SizedBox(width: 12),
                Container(width: 1, height: 18, color: AppColors.border),
                const SizedBox(width: 12),
                Text(
                  'Token ${order.tokenNumber}',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const Spacer(),
              Text(
                formatCurrency(order.total),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
