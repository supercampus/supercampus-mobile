import 'package:flutter/material.dart';

import 'status_card_models.dart';

/// Fees status card styled like a printed cashier payment receipt:
/// - Warm white / pale lavender thermal paper background
/// - Dotted receipt divider separating receipt header and amount
/// - Prominent outstanding currency amount
/// - Fee category, due date, and receipt voucher number
class FeesReceiptCard extends StatelessWidget {
  const FeesReceiptCard({
    super.key,
    required this.data,
    required this.onTap,
  });

  final FeesReceiptCardData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1B2E) : const Color(0xFFFAF8FF);
    final borderColor = isDark ? const Color(0xFF3B2D54) : const Color(0xFFDDD6FE);
    final purpleAccent = isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED);
    final statusColor = data.isOverdue ? const Color(0xFFEF4444) : purpleAccent;
    final statusBg = data.isOverdue
        ? (isDark ? const Color(0xFF450A0A) : const Color(0xFFFEE2E2))
        : (isDark ? const Color(0xFF2E1065) : const Color(0xFFEDE9FE));

    final amountFormatted = data.pendingAmount.truncateToDouble() == data.pendingAmount
        ? data.pendingAmount.toInt().toString()
        : data.pendingAmount.toStringAsFixed(2);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 128,
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7C3AED).withValues(alpha: isDark ? 0.2 : 0.07),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top receipt row: Receipt voucher number & Status pill
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.receipt_outlined,
                        size: 13,
                        color: purpleAccent,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        data.receiptNumber,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: purpleAccent,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      data.isOverdue ? 'OVERDUE' : 'PENDING PAYMENT',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: statusColor,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ],
              ),

              // Dotted divider
              _DottedDivider(color: borderColor),

              // Main body: Category/Date on left, Big Amount on right
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data.category,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF1E1B4B),
                            height: 1.15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          data.dueDateText,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'PENDING AMOUNT',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF6D28D9),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        '₹$amountFormatted',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                          color: statusColor,
                          letterSpacing: -0.5,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Bottom pay CTA
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Campus Cashier · Verified account',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 9.5,
                      color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        'Pay now',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: purpleAccent,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 14,
                        color: purpleAccent,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DottedDivider extends StatelessWidget {
  const _DottedDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxWidth = constraints.maxWidth;
        const dashWidth = 3.0;
        const dashSpace = 3.0;
        final dashCount = (boxWidth / (dashWidth + dashSpace)).floor();
        return Flex(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          direction: Axis.horizontal,
          children: List.generate(dashCount, (_) {
            return SizedBox(
              width: dashWidth,
              height: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(color: color),
              ),
            );
          }),
        );
      },
    );
  }
}
