import 'package:flutter/material.dart';

import 'status_card_models.dart';

/// Academics card styled like an authentic student report card / marksheet:
/// - Warm cream paper background
/// - Dark ink typography with official marksheet header
/// - Large attendance percentage as the prominent hero number
/// - Two-tone progress bar with 75% threshold indicator
/// - Orange warning accents when below threshold, green when healthy
class AcademicsReportCard extends StatelessWidget {
  const AcademicsReportCard({
    super.key,
    required this.data,
    required this.onTap,
  });

  final AcademicsReportCardData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1F2937) : const Color(0xFFFDFBF7);
    final isCritical = data.percentage < data.requiredThreshold;

    final accentColor = isCritical ? const Color(0xFFEA580C) : const Color(0xFF16A34A);
    final accentBg = isCritical ? const Color(0xFFFFEDD5) : const Color(0xFFDCFCE7);
    final textColor = isDark ? Colors.white : const Color(0xFF1C1917);
    final subColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF57534E);

    final title = isCritical
        ? 'Your attendance has dropped to ${data.percentage}%'
        : 'Attendance is healthy at ${data.percentage}%';

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
              color: isCritical
                  ? const Color(0xFFFDBA74)
                  : (isDark ? const Color(0xFF374151) : const Color(0xFFE7E5E4)),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: (isCritical ? const Color(0xFFEA580C) : Colors.black)
                    .withValues(alpha: isDark ? 0.2 : 0.05),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top row: Header tag & Status Pill
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.school_outlined,
                        size: 14,
                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF78716C),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'ACADEMIC REPORT · ATTENDANCE',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF78716C),
                          letterSpacing: 0.7,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: accentBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      isCritical ? 'NEEDS ATTENTION' : 'ON TRACK',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: accentColor,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),

              // Middle: Message and Large Attendance %
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isCritical ? accentColor : textColor,
                            height: 1.15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          data.subtitle ??
                              '${data.attendedClasses} of ${data.totalClasses} classes attended · Min ${data.requiredThreshold}%',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                            color: subColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${data.percentage}%',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: accentColor,
                      letterSpacing: -1,
                      height: 1,
                    ),
                  ),
                ],
              ),

              // Bottom: Threshold Progress Bar
              _ThresholdProgressBar(
                percentage: data.percentage,
                threshold: data.requiredThreshold,
                accentColor: accentColor,
                isDark: isDark,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThresholdProgressBar extends StatelessWidget {
  const _ThresholdProgressBar({
    required this.percentage,
    required this.threshold,
    required this.accentColor,
    required this.isDark,
  });

  final int percentage;
  final int threshold;
  final Color accentColor;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final progress = (percentage / 100.0).clamp(0.0, 1.0);
    final thresholdRatio = (threshold / 100.0).clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final thresholdX = width * thresholdRatio;

        return Stack(
          alignment: Alignment.centerLeft,
          children: [
            // Track background
            Container(
              height: 7,
              width: width,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF374151) : const Color(0xFFE7E5E4),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            // Progress fill
            Container(
              height: 7,
              width: width * progress,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            // Threshold tick marker
            Positioned(
              left: thresholdX - 1.5,
              child: Container(
                width: 3,
                height: 11,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white : const Color(0xFF1C1917),
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
