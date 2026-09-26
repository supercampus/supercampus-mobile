import 'package:flutter/material.dart';

import 'status_card_models.dart';

/// Laundry status card styled like an authentic physical dry-cleaner claim tag:
/// - Light aqua / pale teal background
/// - Punched grommet hole motif with metallic ring
/// - Prominent token number: TOKEN #XXXX
/// - Garments count and collection status
class LaundryTagCard extends StatelessWidget {
  const LaundryTagCard({
    super.key,
    required this.data,
    required this.onTap,
  });

  final LaundryTagCardData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF132A29) : const Color(0xFFF0FDFA);
    final borderColor = isDark ? const Color(0xFF1D4E4A) : const Color(0xFF99F6E4);
    final tealPrimary = isDark ? const Color(0xFF2DD4BF) : const Color(0xFF0F766E);
    final textColor = isDark ? Colors.white : const Color(0xFF134E4A);
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF115E59);

    final (statusText, statusBg, statusColor) = switch (data.status) {
      LaundryTagStatus.received => (
        'RECEIVED',
        isDark ? const Color(0xFF1E3A8A) : const Color(0xFFDBEAFE),
        const Color(0xFF2563EB),
      ),
      LaundryTagStatus.washing => (
        'IN WASH CYCLE',
        isDark ? const Color(0xFF14532D) : const Color(0xFFE0F2FE),
        const Color(0xFF0284C7),
      ),
      LaundryTagStatus.ready => (
        'READY FOR PICKUP',
        isDark ? const Color(0xFF14532D) : const Color(0xFFDCFCE7),
        const Color(0xFF16A34A),
      ),
      LaundryTagStatus.collected => (
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
                color: const Color(0xFF0D9488).withValues(alpha: isDark ? 0.2 : 0.08),
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
              // Header row: Punched grommet hole + laundry service tag
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      // Metallic grommet hole motif
                      Container(
                        width: 13,
                        height: 13,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark ? const Color(0xFF0B1D1C) : Colors.white,
                          border: Border.all(
                            color: isDark ? const Color(0xFF2DD4BF) : const Color(0xFF14B8A6),
                            width: 2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'CAMPUS LAUNDRY · SERVICE TAG',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: tealPrimary,
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

              // Main body: Large token on left, clothes count on right
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TOKEN #${data.tokenNumber}',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: tealPrimary,
                          letterSpacing: -0.4,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        data.pickupDeadline,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: subColor,
                        ),
                      ),
                    ],
                  ),

                  // Garments count pill badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E3E3C) : const Color(0xFFCCFBF1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? const Color(0xFF2DD4BF) : const Color(0xFF5EEAD4),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.local_laundry_service_outlined,
                          size: 16,
                          color: tealPrimary,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${data.clothesCount} CLOTHES',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Bottom footer
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Hostel Block Laundry Counter',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 9.5,
                      color: isDark ? const Color(0xFF6B7280) : const Color(0xFF14B8A6),
                    ),
                  ),
                  Text(
                    'Scan to collect',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: tealPrimary,
                    ),
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
