import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../data/canteen_models.dart';

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

  @override
  Widget build(BuildContext context) {
    const deliveredColor = Color(0xFF22C55E);

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 20 : 24,
        vertical: compact ? 16 : 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Animated checkmark badge
          Container(
            width: compact ? 76 : 92,
            height: compact ? 76 : 92,
            decoration: BoxDecoration(
              color: deliveredColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(
                color: deliveredColor.withValues(alpha: 0.35),
                width: 2.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: deliveredColor.withValues(alpha: 0.25),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              Icons.check_circle_rounded,
              color: deliveredColor,
              size: compact ? 46 : 56,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Your order is delivered',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 23,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Collected at counter · Enjoy your food!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 22),

          // Order summary card
          Container(
            padding: const EdgeInsets.all(18),
            constraints: const BoxConstraints(maxWidth: 420),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1C24),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white12),
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
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (order.tokenNumber != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Token ${order.tokenNumber}',
                              style: const TextStyle(
                                color: AppColors.amber,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: deliveredColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: deliveredColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_rounded,
                            size: 14,
                            color: deliveredColor,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'DELIVERED',
                            style: TextStyle(
                              color: deliveredColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24, color: Colors.white12),
                for (final line in order.lines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Text(
                          '${line.quantity}×',
                          style: const TextStyle(
                            color: Color(0xFF93C5FD),
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            line.item.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Text(
                          formatCurrency(line.total),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                const Divider(height: 20, color: Colors.white12),
                Row(
                  children: [
                    const Text(
                      'Total paid',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const Spacer(),
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
              child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: deliveredColor,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: onDone,
              icon: const Icon(Icons.check_rounded),
              label: const Text(
                'Done',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
        ],
      ),
    );
  }
}
