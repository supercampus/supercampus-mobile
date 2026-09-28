import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../data/canteen_models.dart';
import 'order_pickup_sheet.dart';
import 'widgets/canteen_surface.dart';
import 'widgets/order_status_badge.dart';

enum OrderFilter { active, history }

class CanteenOrdersScreen extends StatefulWidget {
  const CanteenOrdersScreen({
    super.key,
    required this.orders,
    required this.onBack,
    this.onRefresh,
  });

  final List<CanteenOrder> orders;

  /// Returns to the shops menu, which is this module's home.
  final VoidCallback onBack;

  final Future<void> Function()? onRefresh;

  @override
  State<CanteenOrdersScreen> createState() => _CanteenOrdersScreenState();
}

class _CanteenOrdersScreenState extends State<CanteenOrdersScreen> {
  OrderFilter _filter = OrderFilter.active;

  @override
  void initState() {
    super.initState();
    final hasActive = widget.orders.any((o) => o.status.isActive);
    _filter = hasActive ? OrderFilter.active : OrderFilter.history;
  }

  void _openOrderQr(CanteenOrder order) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => FullScreenOrderQrScreen(
          order: order,
          onRefresh: widget.onRefresh,
          latestOrderFinder: () {
            for (final o in widget.orders) {
              if (o.id == order.id) return o;
            }
            return null;
          },
        ),
      ),
    );
  }

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
          onBack: widget.onBack,
          title: 'My orders',
          subtitle: 'Track active and completed orders',
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
          CanteenSurface(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 34),
              child: Column(
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 38,
                    color: context.palette.inkSecondary,
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
              child: _OrderCard(
                order: order,
                onTap: () => _openOrderQr(order),
              ),
            ),
      ],
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.onTap});

  final CanteenOrder order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final active = order.status.isActive;
    return CanteenSurface(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '#${order.displayId}',
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              OrderStatusGradientBadge(status: order.status),
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
                    style: TextStyle(color: context.palette.brandInk),
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
                color: context.palette.inkSecondary,
              ),
              const SizedBox(width: 7),
              Text(order.fulfilmentMode.label),
              if (active && order.tokenNumber != null) ...[
                const SizedBox(width: 12),
                Container(width: 1, height: 18, color: context.palette.border),
                const SizedBox(width: 12),
                Text(
                  'Token ${order.tokenNumber}',
                  style: TextStyle(
                    color: context.palette.brandInk,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const Spacer(),
              Text(
                formatCurrency(order.total),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Only an order still at the counter has a pickup QR; a settled
          // one opens its outcome instead.
          _OrderCardPrompt(order: order),
        ],
      ),
    );
  }
}

class _OrderCardPrompt extends StatelessWidget {
  const _OrderCardPrompt({required this.order});

  final CanteenOrder order;

  @override
  Widget build(BuildContext context) {
    final refused =
        order.status == CanteenOrderStatus.rejected ||
        order.status == CanteenOrderStatus.cancelled;
    final tone = refused
        ? context.adaptive(
            light: const Color(0xFFB42318),
            dark: const Color(0xFFFCA5A5),
          )
        : context.palette.brandInk;
    final outcome = order.status == CanteenOrderStatus.rejected
        ? 'Rejected'
        : 'Cancelled';
    final (IconData icon, String label) = order.status.isActive
        ? (Icons.qr_code_2_rounded, 'Tap to view pickup QR code in full screen')
        : refused
        ? (
            Icons.cancel_outlined,
            '$outcome · ${formatCurrency(order.total)} refunded · Tap for details',
          )
        : (Icons.receipt_long_outlined, 'Tap to view order details');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: tone),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: tone,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
          Icon(Icons.chevron_right_rounded, size: 18, color: tone),
        ],
      ),
    );
  }
}

class FullScreenOrderQrScreen extends StatelessWidget {
  const FullScreenOrderQrScreen({
    super.key,
    required this.order,
    this.onRefresh,
    this.latestOrderFinder,
  });

  final CanteenOrder order;
  final Future<void> Function()? onRefresh;
  final CanteenOrder? Function()? latestOrderFinder;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: OrderPickupSheet(
        order: order,
        onRefresh: onRefresh,
        latestOrderFinder: latestOrderFinder,
      ),
    );
  }
}
