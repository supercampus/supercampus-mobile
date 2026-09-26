import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../gatepass/data/gatepass_models.dart';
import 'status_card_models.dart';

/// Gatepass ticket card shaped like a real printed admission ticket with:
/// - Zigzag/perforated left torn edge
/// - Semicircular cutouts on top and bottom at the divider
/// - Dotted/dashed perforation line connecting the cutouts
/// - Authentic typography, approval status badge, validity text, and QR code
class GatepassTicketCard extends StatelessWidget {
  const GatepassTicketCard({
    super.key,
    required this.data,
    required this.onTap,
  });

  final GatepassTicketCardData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF4B5563);
    final dividerColor = isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);

    // Status styling
    final (statusColor, statusLabel) = switch (data.status) {
      ApprovalStatus.approved => (const Color(0xFF22C55E), 'approved'),
      ApprovalStatus.pending => (const Color(0xFFF97316), 'pending'),
      ApprovalStatus.rejected => (const Color(0xFFEF4444), 'rejected'),
      ApprovalStatus.completed => (const Color(0xFF3B82F6), 'completed'),
      ApprovalStatus.cancelled => (const Color(0xFF6B7280), 'cancelled'),
    };

    final qrData = (data.qrPayload != null && data.qrPayload!.isNotEmpty)
        ? data.qrPayload!
        : 'MEC-GP-${data.id.substring(0, data.id.length.clamp(0, 8))}';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 128,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: CustomPaint(
            painter: _TicketShadowAndPerforationPainter(
              cardColor: cardBg,
              dividerColor: dividerColor,
              isDark: isDark,
              notchRadius: 8.0,
              dividerRightOffset: 92.0,
            ),
            child: ClipPath(
              clipper: _TicketClipper(
                notchRadius: 8.0,
                dividerRightOffset: 92.0,
              ),
              child: Container(
                color: cardBg,
                padding: const EdgeInsets.fromLTRB(18, 14, 10, 14),
                child: Row(
                  children: [
                    // Left section: Title, Status Badge, Validity
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            data.title,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                              letterSpacing: -0.4,
                              height: 1.1,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 7),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3.5,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: statusColor.withValues(alpha: 0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1.5),
                                ),
                              ],
                            ),
                            child: Text(
                              statusLabel,
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 0.2,
                                height: 1.1,
                              ),
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            data.validUntilText,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: subColor,
                              height: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Right section: Clean QR Code
                    Container(
                      width: 76,
                      height: 76,
                      alignment: Alignment.center,
                      child: QrImageView(
                        data: qrData,
                        size: 74,
                        version: QrVersions.auto,
                        padding: EdgeInsets.zero,
                        eyeStyle: QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: textColor,
                        ),
                        dataModuleStyle: QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: textColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom clipper that produces:
/// - Zigzag teeth on left edge
/// - Semicircular top and bottom notches at divider line
/// - Rounded top-right and bottom-right corners
class _TicketClipper extends CustomClipper<Path> {
  const _TicketClipper({
    required this.notchRadius,
    required this.dividerRightOffset,
  });

  final double notchRadius;
  final double dividerRightOffset;

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    final r = notchRadius;
    final dividerX = w - dividerRightOffset;
    const cornerR = 14.0;
    const toothCount = 10;
    final toothH = h / toothCount;
    const toothDepth = 4.0;

    final path = Path();

    // Start at top-left
    path.moveTo(0, 0);

    // Top edge to top notch
    path.lineTo(dividerX - r, 0);
    // Semicircular notch at top
    path.arcToPoint(
      Offset(dividerX + r, 0),
      radius: Radius.circular(r),
      clockwise: false,
    );

    // Top edge to top-right corner
    path.lineTo(w - cornerR, 0);
    path.arcToPoint(
      Offset(w, cornerR),
      radius: const Radius.circular(cornerR),
      clockwise: true,
    );

    // Right edge
    path.lineTo(w, h - cornerR);
    path.arcToPoint(
      Offset(w - cornerR, h),
      radius: const Radius.circular(cornerR),
      clockwise: true,
    );

    // Bottom edge to bottom notch
    path.lineTo(dividerX + r, h);
    // Semicircular notch at bottom
    path.arcToPoint(
      Offset(dividerX - r, h),
      radius: Radius.circular(r),
      clockwise: false,
    );

    // Bottom edge to bottom-left
    path.lineTo(0, h);

    // Left edge with perforated zigzag teeth
    for (int i = toothCount - 1; i >= 0; i--) {
      final yMid = (i + 0.5) * toothH;
      final yTop = i * toothH;
      path.lineTo(toothDepth, yMid);
      path.lineTo(0, yTop);
    }

    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant _TicketClipper oldClipper) =>
      oldClipper.notchRadius != notchRadius ||
      oldClipper.dividerRightOffset != dividerRightOffset;
}

/// Custom painter for the dashed perforated line connecting the top & bottom notches
class _TicketShadowAndPerforationPainter extends CustomPainter {
  const _TicketShadowAndPerforationPainter({
    required this.cardColor,
    required this.dividerColor,
    required this.isDark,
    required this.notchRadius,
    required this.dividerRightOffset,
  });

  final Color cardColor;
  final Color dividerColor;
  final bool isDark;
  final double notchRadius;
  final double dividerRightOffset;

  @override
  void paint(Canvas canvas, Size size) {
    final dividerX = size.width - dividerRightOffset;
    final r = notchRadius;

    // Draw vertical dashed line
    final dashPaint = Paint()
      ..color = dividerColor
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    const dashHeight = 4.0;
    const dashGap = 3.5;
    double startY = r + 2;
    final endY = size.height - r - 2;

    while (startY < endY) {
      canvas.drawLine(
        Offset(dividerX, startY),
        Offset(dividerX, (startY + dashHeight).clamp(0, endY)),
        dashPaint,
      );
      startY += dashHeight + dashGap;
    }
  }

  @override
  bool shouldRepaint(covariant _TicketShadowAndPerforationPainter oldDelegate) =>
      oldDelegate.dividerColor != dividerColor ||
      oldDelegate.isDark != isDark;
}
