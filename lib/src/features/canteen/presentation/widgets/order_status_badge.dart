import 'package:flutter/material.dart';

import '../../data/canteen_models.dart';

/// Distinct gradients specified for order lifecycle:
/// - pending: orange gradient
/// - preparing: yellow gradient
/// - ready for pickup: purple gradient
/// - delivered: green gradient
class OrderStatusGradients {
  static const LinearGradient pending = LinearGradient(
    colors: [Color(0xFFFF9800), Color(0xFFFF5722)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient preparing = LinearGradient(
    colors: [Color(0xFFFACC15), Color(0xFFEAB308)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient ready = LinearGradient(
    colors: [Color(0xFFA855F7), Color(0xFF7C3AED)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient delivered = LinearGradient(
    colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient rejected = LinearGradient(
    colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient forStatus(CanteenOrderStatus status) {
    return switch (status) {
      CanteenOrderStatus.pending || CanteenOrderStatus.accepted => pending,
      CanteenOrderStatus.preparing => preparing,
      CanteenOrderStatus.ready => ready,
      CanteenOrderStatus.completed => delivered,
      CanteenOrderStatus.rejected || CanteenOrderStatus.cancelled => rejected,
    };
  }

  static Color textColorForStatus(CanteenOrderStatus status) {
    return switch (status) {
      CanteenOrderStatus.preparing => const Color(0xFF78350F), // high contrast amber text
      _ => Colors.white,
    };
  }

  static String labelForStatus(CanteenOrderStatus status) {
    return switch (status) {
      CanteenOrderStatus.pending => 'Pending',
      CanteenOrderStatus.accepted => 'Accepted',
      CanteenOrderStatus.preparing => 'Preparing',
      CanteenOrderStatus.ready => 'Ready for pickup',
      CanteenOrderStatus.completed => 'Delivered',
      CanteenOrderStatus.rejected => 'Rejected',
      CanteenOrderStatus.cancelled => 'Cancelled',
    };
  }
}

class OrderStatusGradientBadge extends StatelessWidget {
  const OrderStatusGradientBadge({
    super.key,
    required this.status,
    this.fontSize = 11.5,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    this.borderRadius = 8,
  });

  final CanteenOrderStatus status;
  final double fontSize;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final gradient = OrderStatusGradients.forStatus(status);
    final textColor = OrderStatusGradients.textColorForStatus(status);
    final label = OrderStatusGradients.labelForStatus(status);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: gradient.colors.first.withValues(alpha: 0.28),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            switch (status) {
              CanteenOrderStatus.pending => Icons.hourglass_top_rounded,
              CanteenOrderStatus.accepted => Icons.thumb_up_alt_outlined,
              CanteenOrderStatus.preparing => Icons.local_fire_department_rounded,
              CanteenOrderStatus.ready => Icons.room_service_rounded,
              CanteenOrderStatus.completed => Icons.check_circle_rounded,
              _ => Icons.cancel_rounded,
            },
            size: fontSize + 2,
            color: textColor,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w700,
              fontSize: fontSize,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
