import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../data/library_models.dart';

/// Full-screen QR check-in / check-out page for a library booking.
class LibraryQrScreen extends StatelessWidget {
  const LibraryQrScreen({
    super.key,
    required this.pass,
    required this.onCancel,
    required this.onEarlyCheckOut,
  });

  final LibraryVisitPass pass;
  final ValueChanged<String> onCancel;
  final ValueChanged<String> onEarlyCheckOut;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF171717) : Colors.white;
    final surfaceColor = isDark ? Colors.black : AppColors.canvas;
    final textColor = isDark ? Colors.white : AppColors.ink;
    final mutedColor = isDark ? Colors.white54 : AppColors.muted;
    final badgeColor = isDark ? pass.status.badgeColorDark : pass.status.badgeColor;
    final badgeBg = isDark ? pass.status.badgeBackgroundDark : pass.status.badgeBackground;

    return Scaffold(
      backgroundColor: surfaceColor,
      appBar: AppBar(
        backgroundColor: const Color(0xFF6D357F),
        foregroundColor: Colors.white,
        title: const Text('Check-In Pass'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Zone name header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.local_library_outlined,
                              color: Color(0xFF6D357F),
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                pass.zoneName,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: textColor,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // QR Card
                        Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: isDark
                                ? null
                                : [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.06),
                                      blurRadius: 20,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                          ),
                          child: Column(
                            children: [
                              Text(
                                'LIBRARY PASS',
                                style: TextStyle(
                                  letterSpacing: 2,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  color: mutedColor,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: QrImageView(
                                  data: pass.qrToken,
                                  size: 200,
                                  backgroundColor: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                pass.id,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 6),
                              if (pass.seatNumber != null)
                                Text(
                                  pass.seatNumber!,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: mutedColor,
                                  ),
                                ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 18),

                        // Time and date row
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _InfoChip(
                                icon: Icons.calendar_today_outlined,
                                label: DateFormat('d MMM yyyy').format(pass.date),
                                color: mutedColor,
                                textColor: textColor,
                              ),
                              Container(
                                width: 1,
                                height: 28,
                                color: isDark
                                    ? Colors.white12
                                    : const Color(0xFFE1E5E3),
                              ),
                              _InfoChip(
                                icon: Icons.access_time_outlined,
                                label: '${DateFormat('HH:mm').format(pass.start)} – ${DateFormat('HH:mm').format(pass.end)}',
                                color: mutedColor,
                                textColor: textColor,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Status badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: badgeBg,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            pass.status.label,
                            style: TextStyle(
                              color: badgeColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),

                        // Check-in / check-out times
                        if (pass.checkInAt != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            'Checked in: ${DateFormat('h:mm a').format(pass.checkInAt!)}',
                            style: TextStyle(color: mutedColor, fontSize: 13),
                          ),
                        ],
                        if (pass.checkOutAt != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Checked out: ${DateFormat('h:mm a').format(pass.checkOutAt!)}',
                            style: TextStyle(color: mutedColor, fontSize: 13),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Bottom action bar
            if (pass.status == LibraryPassStatus.upcoming ||
                pass.status == LibraryPassStatus.active ||
                pass.status == LibraryPassStatus.inside)
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                decoration: BoxDecoration(
                  color: cardColor,
                  border: Border(
                    top: BorderSide(
                      color: isDark
                          ? Colors.white10
                          : const Color(0xFFE1E5E3),
                    ),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      if (pass.status == LibraryPassStatus.upcoming ||
                          pass.status == LibraryPassStatus.active)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              onCancel(pass.id);
                              Navigator.of(context).pop('cancelled');
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFB71C1C),
                              side: const BorderSide(color: Color(0xFFB71C1C)),
                              minimumSize: const Size(0, 50),
                            ),
                            icon: const Icon(Icons.close, size: 18),
                            label: const Text('Cancel Booking'),
                          ),
                        ),
                      if (pass.status == LibraryPassStatus.inside) ...[
                        if (pass.status == LibraryPassStatus.upcoming ||
                            pass.status == LibraryPassStatus.active)
                          const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () {
                              onEarlyCheckOut(pass.id);
                              Navigator.of(context).pop('checked_out');
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF6D357F),
                              minimumSize: const Size(0, 50),
                            ),
                            icon: const Icon(Icons.logout, size: 18),
                            label: const Text('Early Check-Out'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.textColor,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: textColor,
          ),
        ),
      ],
    );
  }
}
