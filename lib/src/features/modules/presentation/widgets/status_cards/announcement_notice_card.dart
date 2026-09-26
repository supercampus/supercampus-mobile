import 'package:flutter/material.dart';

import 'status_card_models.dart';

/// Announcement card designed like a notice pinned to a college bulletin board:
/// - Pale yellow note paper background
/// - Red 3D push-pin / tape graphic at top center
/// - Prominent headline typography
/// - Department and date attribution
/// - Priority/urgency indicator badge
class AnnouncementNoticeCard extends StatelessWidget {
  const AnnouncementNoticeCard({
    super.key,
    required this.data,
    required this.onTap,
  });

  final AnnouncementNoticeCardData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF242217) : const Color(0xFFFEFCE8);
    final borderColor = isDark ? const Color(0xFF454020) : const Color(0xFFFEF08A);
    final textColor = isDark ? Colors.white : const Color(0xFF1C1917);
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF713F12);

    final (urgencyText, urgencyBg, urgencyColor) = switch (data.urgency) {
      NoticeUrgency.normal => (
        'CIRCULAR',
        isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
      ),
      NoticeUrgency.important => (
        'IMPORTANT',
        isDark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7),
        const Color(0xFFD97706),
      ),
      NoticeUrgency.urgent => (
        'URGENT',
        isDark ? const Color(0xFF450A0A) : const Color(0xFFFEE2E2),
        const Color(0xFFEF4444),
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
                color: const Color(0xFFCA8A04).withValues(alpha: isDark ? 0.2 : 0.08),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Red push-pin graphic at top center
              Positioned(
                top: -6,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(
                        colors: [Color(0xFFEF4444), Color(0xFF991B1B)],
                        center: Alignment(-0.3, -0.3),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 3,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Header row with department & priority pill
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.push_pin_outlined,
                              size: 13,
                              color: Color(0xFFCA8A04),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'COLLEGE BULLETIN · ${data.department.toUpperCase()}',
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFCA8A04),
                                letterSpacing: 0.6,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: urgencyBg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            urgencyText,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: urgencyColor,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Main Headline
                    Text(
                      data.headline,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    // Bottom info
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Published ${data.dateText}',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: subColor,
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              'Read circular',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: subColor,
                              ),
                            ),
                            const SizedBox(width: 2),
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 13,
                              color: subColor,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
