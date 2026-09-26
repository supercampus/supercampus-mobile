import 'package:flutter/material.dart';

import 'status_card_models.dart';

/// Stationery card designed like a postal parcel package label:
/// - Warm kraft/pale yellow label background
/// - Tracking code & postage barcode header
/// - Order number, item count, and pickup desk location
/// - Parcel / package illustration
class StationeryParcelCard extends StatelessWidget {
  const StationeryParcelCard({
    super.key,
    required this.data,
    required this.onTap,
  });

  final StationeryParcelCardData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF261E14) : const Color(0xFFFFFBEB);
    final borderColor = isDark ? const Color(0xFF452E15) : const Color(0xFFFDE68A);
    final warmBrown = isDark ? const Color(0xFFFBBF24) : const Color(0xFF92400E);
    final textColor = isDark ? Colors.white : const Color(0xFF1C1917);
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF78350F);

    final (statusText, statusBg, statusColor) = switch (data.status) {
      StationeryParcelStatus.processing => (
        'PACKING',
        isDark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7),
        const Color(0xFFD97706),
      ),
      StationeryParcelStatus.readyForPickup => (
        'READY FOR PICKUP',
        isDark ? const Color(0xFF14532D) : const Color(0xFFDCFCE7),
        const Color(0xFF16A34A),
      ),
      StationeryParcelStatus.collected => (
        'COLLECTED',
        isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6),
        const Color(0xFF6B7280),
      ),
    };

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
                color: const Color(0xFFD97706).withValues(alpha: isDark ? 0.2 : 0.07),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Header row: tracking code and status pill
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 13,
                        color: warmBrown,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'STATIONERY DEPOT · ${data.trackingCode}',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: warmBrown,
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
                      statusText,
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

              // Main body
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your stationery order #${data.orderNumber}',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                            height: 1.15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${data.itemCount} items · ${data.pickupLocation}',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: subColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Parcel package icon badge
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF382A1C) : const Color(0xFFFDE68A),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? const Color(0xFF5A4428) : const Color(0xFFF59E0B),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.markunread_mailbox_rounded,
                      size: 24,
                      color: Color(0xFF92400E),
                    ),
                  ),
                ],
              ),

              // Bottom row with barcode pattern
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Present token at store counter',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 9.5,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF92400E),
                    ),
                  ),
                  Row(
                    children: [
                      for (final w in [3.0, 1.0, 2.0, 4.0, 1.0, 2.0, 3.0, 1.0, 2.0])
                        Container(
                          width: w,
                          height: 10,
                          margin: const EdgeInsets.only(left: 1.5),
                          color: isDark ? const Color(0xFF6B7280) : const Color(0xFF92400E),
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
