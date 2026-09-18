import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../data/canteen_models.dart';
import 'widgets/canteen_surface.dart';

enum OrderFilter { active, history }

class CanteenOrdersScreen extends StatefulWidget {
  const CanteenOrdersScreen({
    super.key,
    required this.orders,
    required this.onBack,
  });

  final List<CanteenOrder> orders;

  /// Returns to the shops menu, which is this module's home.
  final VoidCallback onBack;

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
        builder: (_) => FullScreenOrderQrScreen(order: order),
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
    final statusColor = switch (order.status) {
      CanteenOrderStatus.pending => const Color(0xFFB96708),
      CanteenOrderStatus.accepted => AppColors.primary,
      CanteenOrderStatus.preparing => const Color(0xFFB96708),
      CanteenOrderStatus.ready => AppColors.success,
      CanteenOrderStatus.completed => const Color(0xFF168A5B),
      CanteenOrderStatus.rejected => Theme.of(context).colorScheme.error,
      CanteenOrderStatus.cancelled => Theme.of(context).colorScheme.error,
    };

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
                    fontWeight: FontWeight.w600,
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
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.qr_code_2_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tap to view pickup QR code in full screen',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FullScreenOrderQrScreen extends StatelessWidget {
  const FullScreenOrderQrScreen({super.key, required this.order});

  final CanteenOrder order;

  @override
  Widget build(BuildContext context) {
    final qrSize = (MediaQuery.sizeOf(context).width - 100).clamp(200.0, 320.0);
    final isReady = order.status == CanteenOrderStatus.ready;
    final statusColor = switch (order.status) {
      CanteenOrderStatus.ready => AppColors.amber,
      CanteenOrderStatus.completed => const Color(0xFF4ADE80),
      CanteenOrderStatus.rejected || CanteenOrderStatus.cancelled => Colors.redAccent,
      _ => const Color(0xFF93C5FD),
    };

    return Scaffold(
      backgroundColor: const Color(0xFF111014),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111014),
        foregroundColor: Colors.white,
        title: Text('Order #${order.displayId}'),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Close',
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    isReady
                        ? 'READY FOR PICKUP'
                        : order.status.label.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black54,
                        blurRadius: 20,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: QrImageView(
                    data: order.qrPayload ?? order.id,
                    size: qrSize,
                    padding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(height: 24),
                if (order.tokenNumber != null) ...[
                  const Text(
                    'PICKUP TOKEN',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${order.tokenNumber}',
                    style: const TextStyle(
                      color: AppColors.amber,
                      fontSize: 48,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                const Text(
                  'Show this QR at the counter to collect your order.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 22),
                Container(
                  padding: const EdgeInsets.all(16),
                  constraints: const BoxConstraints(maxWidth: 420),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1C24),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final line in order.lines)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Text(
                                '${line.quantity}×',
                                style: const TextStyle(
                                  color: Color(0xFF93C5FD),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  line.item.name,
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              Text(
                                formatCurrency(line.total),
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                      const Divider(color: Colors.white12, height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${order.itemCount} item${order.itemCount == 1 ? '' : 's'}',
                            style: const TextStyle(color: Colors.white54),
                          ),
                          Text(
                            formatCurrency(order.total),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: isReady ? AppColors.amber : const Color(0xFF2A2832),
                        foregroundColor: isReady ? AppColors.ink : Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(
                        'Done',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
