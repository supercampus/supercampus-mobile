import 'package:flutter/material.dart';

import 'status_card_models.dart';

/// Library card designed like an authentic paper circulation borrowing slip:
/// - Cream library card paper background
/// - Deep forest green ink accents
/// - Stamped return date box
/// - Book title, author, and book icon / cover thumbnail
/// - Barcode-style decorative edge element
class LibrarySlipCard extends StatelessWidget {
  const LibrarySlipCard({
    super.key,
    required this.data,
    required this.onTap,
  });

  final LibrarySlipCardData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1B241C) : const Color(0xFFFAF7EE);
    final borderColor = isDark ? const Color(0xFF2D3B2E) : const Color(0xFFD6CEB8);
    final inkGreen = isDark ? const Color(0xFF86EFAC) : const Color(0xFF166534);
    final textColor = isDark ? Colors.white : const Color(0xFF1C1917);
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF57534E);

    final isOverdue = data.status == LibrarySlipStatus.overdue;
    final isDueSoon = data.status == LibrarySlipStatus.dueSoon;

    final (badgeText, badgeColor, badgeBg) = switch (data.status) {
      LibrarySlipStatus.borrowed => ('BORROWED', inkGreen, isDark ? const Color(0xFF14532D) : const Color(0xFFDCFCE7)),
      LibrarySlipStatus.dueSoon => ('DUE SOON', const Color(0xFFD97706), isDark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7)),
      LibrarySlipStatus.overdue => ('OVERDUE', const Color(0xFFDC2626), isDark ? const Color(0xFF450A0A) : const Color(0xFFFEE2E2)),
      LibrarySlipStatus.returned => ('RETURNED', const Color(0xFF6B7280), isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6)),
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
                color: const Color(0xFF166534).withValues(alpha: isDark ? 0.2 : 0.06),
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
              // Header row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.local_library_outlined,
                        size: 13,
                        color: inkGreen,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'CENTRAL LIBRARY · CIRCULATION SLIP',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: inkGreen,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: badgeColor,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ],
              ),

              // Main body
              Row(
                children: [
                  // Book details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data.bookTitle,
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
                          data.author,
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

                  const SizedBox(width: 10),

                  // Stamped return date box
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF14532D).withValues(alpha: 0.3) : const Color(0xFFE8F5E9),
                      border: Border.all(
                        color: isOverdue
                            ? const Color(0xFFEF4444)
                            : (isDueSoon ? const Color(0xFFF59E0B) : inkGreen),
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'RETURN BY',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 8.5,
                            fontWeight: FontWeight.w800,
                            color: isOverdue ? const Color(0xFFEF4444) : inkGreen,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          data.returnDateText,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: isOverdue ? const Color(0xFFEF4444) : inkGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Bottom barcode decorative strip
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Shelf: CS · Scan to renew',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 9.5,
                      color: isDark ? const Color(0xFF6B7280) : const Color(0xFF78716C),
                    ),
                  ),
                  // Decorative barcode bars
                  Row(
                    children: [
                      for (final w in [2.0, 1.0, 3.0, 1.0, 2.0, 4.0, 1.0, 3.0, 2.0, 1.0, 3.0])
                        Container(
                          width: w,
                          height: 12,
                          margin: const EdgeInsets.only(left: 1.5),
                          color: isDark ? const Color(0xFF4B5563) : const Color(0xFF78716C),
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
