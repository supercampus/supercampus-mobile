import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../data/canteen_models.dart';

/// Shown on the order pickup screen once the order is collected. That screen
/// is always white (for the counter scanner), so these colours are fixed for
/// a white page in both app themes.
class OrderDeliveredView extends StatelessWidget {
  const OrderDeliveredView({
    super.key,
    required this.order,
    required this.onDone,
    this.compact = false,
  });

  final CanteenOrder order;
  final VoidCallback onDone;
  final bool compact;

  // Success green legible on white (text), and its soft tint for fills.
  static const _success = Color(0xFF15803D);
  static const _successSoft = Color(0xFFE7F7EC);
  static const _ink = Color(0xFF0A0A12);
  static const _inkSecondary = Color(0xFF6B7280);
  static const _card = Color(0xFFF8F6FE);
  static const _cardBorder = Color(0xFFE6DFFC);

  @override
  Widget build(BuildContext context) {
    final badgeSize = compact ? 76.0 : 92.0;

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 20 : 24,
          vertical: compact ? 16 : 24,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: constraints.maxHeight.isFinite
                ? constraints.maxHeight - (compact ? 32 : 48)
                : 0,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: badgeSize,
                      height: badgeSize,
                      decoration: const BoxDecoration(
                        color: _successSoft,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_circle_rounded,
                        color: _success,
                        size: compact ? 46 : 56,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Your order is delivered',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _ink,
                      fontSize: 23,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Collected at the counter · Enjoy your food!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _inkSecondary, fontSize: 14),
                  ),
                  const SizedBox(height: 22),
                  _summaryCard(),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      key: const ValueKey('order-delivered-done'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.brandPurple,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26),
                        ),
                        elevation: 0,
                      ),
                      onPressed: onDone,
                      child: const Text(
                        'Done',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _summaryCard() => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: _card,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _cardBorder),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order #${order.displayId}',
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (order.tokenNumber != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Token ${order.tokenNumber}',
                      style: const TextStyle(
                        color: AppColors.orangeInk,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _successSoft,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_rounded, size: 14, color: _success),
                  SizedBox(width: 4),
                  Text(
                    'Delivered',
                    style: TextStyle(
                      color: _success,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const Divider(height: 24, color: _cardBorder),
        for (final line in order.lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Text(
                  '${line.quantity}×',
                  style: const TextStyle(
                    color: AppColors.brandPurple,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    line.item.name,
                    style: const TextStyle(color: _ink, fontSize: 14),
                  ),
                ),
                Text(
                  formatCurrency(line.total),
                  style: const TextStyle(color: _inkSecondary, fontSize: 14),
                ),
              ],
            ),
          ),
        const Divider(height: 20, color: _cardBorder),
        Row(
          children: [
            const Text(
              'Total paid',
              style: TextStyle(color: _inkSecondary, fontSize: 14),
            ),
            const Spacer(),
            Text(
              formatCurrency(order.total),
              style: const TextStyle(
                color: _ink,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
