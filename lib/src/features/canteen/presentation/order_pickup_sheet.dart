import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../data/canteen_models.dart';
import 'widgets/order_delivered_view.dart';

class OrderPickupSheet extends StatefulWidget {
  const OrderPickupSheet({
    super.key,
    required this.order,
    this.onRefresh,
    this.latestOrderFinder,
  });

  final CanteenOrder order;
  final Future<void> Function()? onRefresh;
  final CanteenOrder? Function()? latestOrderFinder;

  @override
  State<OrderPickupSheet> createState() => _OrderPickupSheetState();
}

class _OrderPickupSheetState extends State<OrderPickupSheet> {
  late CanteenOrder _order;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    _startPolling();
  }

  void _startPolling() {
    if (_order.status == CanteenOrderStatus.completed) return;
    _timer = Timer.periodic(const Duration(milliseconds: 1500), (_) async {
      if (!mounted) return;
      if (widget.onRefresh != null) {
        try {
          await widget.onRefresh!();
        } catch (_) {}
      }
      if (!mounted) return;
      final latest = widget.latestOrderFinder?.call();
      if (latest != null && latest.status != _order.status) {
        setState(() {
          _order = latest;
        });
        if (_order.status == CanteenOrderStatus.completed) {
          _timer?.cancel();
          _timer = null;
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_order.status == CanteenOrderStatus.completed) {
      return SafeArea(
        child: Container(
          color: AppColors.ink,
          child: OrderDeliveredView(
            order: _order,
            onDone: () => Navigator.of(context).pop(),
            compact: true,
          ),
        ),
      );
    }
    return SafeArea(
      child: Container(
        color: AppColors.ink,
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'MEC Canteen',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'READY FOR PICKUP',
                    style: TextStyle(
                      color: AppColors.amber,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Container(
                  width: 156,
                  height: 156,
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: QrImageView(
                    data: _order.qrPayload ?? _order.id,
                    padding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PICKUP TOKEN',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_order.tokenNumber ?? '--'}',
                        style: const TextStyle(
                          color: AppColors.amber,
                          fontSize: 46,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Show this QR at the counter.',
                        style: TextStyle(color: Colors.white70, height: 1.35),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Text(
                  '${_order.itemCount} item${_order.itemCount == 1 ? '' : 's'}',
                  style: const TextStyle(color: Colors.white70),
                ),
                const Spacer(),
                Text(
                  formatCurrency(_order.total),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.amber,
                foregroundColor: AppColors.ink,
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}
