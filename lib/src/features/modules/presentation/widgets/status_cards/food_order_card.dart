import 'package:flutter/material.dart';

import '../../../../canteen/data/canteen_models.dart';
import 'status_card_models.dart';

/// Kitchen order notification card matching the reference screenshot design:
/// - "your order #XXXX is" in amber/yellow typography
/// - Status-specific pill badge (orange, yellow, purple-blue, green)
/// - State-dependent progress message
/// - Circular food dish image on the right
class FoodOrderCard extends StatelessWidget {
  const FoodOrderCard({
    super.key,
    required this.data,
    required this.onTap,
  });

  final FoodOrderCardData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final messageColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF1F2937);

    // Status pill colors and message mapping based on specification and screenshot:
    final (badgeColor, badgeText, defaultMessage) = switch (data.status) {
      CanteenOrderStatus.pending => (
        const Color(0xFFF97316), // Orange
        'pending',
        'please wait until your order is prepared',
      ),
      CanteenOrderStatus.accepted || CanteenOrderStatus.preparing => (
        const Color(0xFFEAB308), // Bright Yellow
        'preparing',
        'please wait until your order is ready to serve',
      ),
      CanteenOrderStatus.ready => (
        const Color(0xFF7C3AED), // Purple-blue gradient/color
        'ready to serve',
        'please wait until your order is delivered',
      ),
      CanteenOrderStatus.completed => (
        const Color(0xFF16A34A), // Green
        'delivered',
        'your order has been delivered',
      ),
      CanteenOrderStatus.rejected => (
        const Color(0xFFEF4444),
        'rejected',
        'your order could not be fulfilled',
      ),
      CanteenOrderStatus.cancelled => (
        const Color(0xFF6B7280),
        'cancelled',
        'your order was cancelled',
      ),
    };

    final message = data.customMessage ?? defaultMessage;

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
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            children: [
              // Left text section
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'your order #${data.orderNumber} is',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFF59E0B), // Reference amber/gold
                        letterSpacing: -0.3,
                        height: 1.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 7),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 3.5,
                      ),
                      decoration: BoxDecoration(
                        color: badgeColor,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: badgeColor.withValues(alpha: 0.35),
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        badgeText,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.2,
                          height: 1.1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      message,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: messageColor,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Right food plate circle
              _FoodPlateArt(
                imageUrl: data.imageUrl,
                itemName: data.itemName,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FoodPlateArt extends StatelessWidget {
  const _FoodPlateArt({this.imageUrl, this.itemName});

  final String? imageUrl;
  final String? itemName;

  @override
  Widget build(BuildContext context) {
    const size = 76.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFFFFBEB),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipOval(
        child: (imageUrl != null && imageUrl!.isNotEmpty)
            ? Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _DefaultDishPainterArt(),
              )
            : const _DefaultDishPainterArt(),
      ),
    );
  }
}

/// Fallback stylized golden-brown roti/dosa plate matching the reference screenshot
class _DefaultDishPainterArt extends StatelessWidget {
  const _DefaultDishPainterArt();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFDE68A),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Inner plate rim
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFEF3C7),
              border: Border.all(color: const Color(0xFFD97706), width: 1.5),
            ),
          ),
          // Food icon / layered rotis
          const Icon(
            Icons.restaurant_rounded,
            size: 32,
            color: Color(0xFFB45309),
          ),
        ],
      ),
    );
  }
}
