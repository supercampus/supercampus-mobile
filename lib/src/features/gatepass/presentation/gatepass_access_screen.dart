import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../data/gatepass_models.dart';
import 'widgets/gatepass_ui.dart';

class GatepassAccessScreen extends StatelessWidget {
  const GatepassAccessScreen({super.key, required this.store});

  final GatepassStore store;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final approvedPasses =
        store.requests
            .where(
              (request) =>
                  request.status == ApprovalStatus.approved &&
                  request.qrPayload?.isNotEmpty == true &&
                  request.returnAt.isAfter(now),
            )
            .toList()
          ..sort((left, right) => left.returnAt.compareTo(right.returnAt));
    final approved = approvedPasses.firstOrNull;
    final daily = store.dailyPass;
    final pass = approved?.qrPayload ?? daily?.qrPayload;
    final manualCode = approved?.manualCode ?? daily?.manualCode;
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            children: [
              const GatepassPageHeader(
                title: 'Campus access',
                subtitle: 'Present this code at the gate',
              ),
              const SizedBox(height: 20),
              if (pass == null)
                _NoPassCard(zone: store.zone, reason: store.dailyPassIssue)
              else
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF171719),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: QrImageView(
                          data: pass,
                          size: 210,
                          eyeStyle: const QrEyeStyle(color: Color(0xFF171719)),
                          dataModuleStyle: const QrDataModuleStyle(
                            color: Color(0xFF171719),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        approved == null
                            ? 'DAILY ACCESS'
                            : approved.type.label.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        manualCode ?? '----',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 8,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Use this 6-digit code if the QR cannot be scanned',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      const SizedBox(height: 10),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.verified_user_outlined,
                            color: AppColors.gateLime,
                            size: 16,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Server-verified gate QR',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              Text(
                'Movement history',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              GatepassSurface(
                child: store.movements.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 22),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history, color: AppColors.muted),
                            SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                'No gate movements recorded yet.',
                                style: TextStyle(color: AppColors.muted),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        children: store.movements
                            .map(
                              (movement) => ListTile(
                                leading: Icon(
                                  movement.direction == MovementDirection.entry
                                      ? Icons.login
                                      : Icons.logout,
                                  color:
                                      movement.direction ==
                                          MovementDirection.entry
                                      ? const Color(0xFF087A4B)
                                      : AppColors.gateMagenta,
                                ),
                                title: Text(
                                  movement.direction == MovementDirection.entry
                                      ? 'Entry'
                                      : 'Exit',
                                ),
                                subtitle: Text(
                                  '${formatShortDate(movement.recordedAt)} • ${movement.gate}',
                                ),
                                trailing: Text(formatTime(movement.recordedAt)),
                              ),
                            )
                            .toList(),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown in place of the QR when today's pass could not be activated.
///
/// The rest of the screen — movement history, the request list behind it —
/// stays exactly where it was. Only the code itself is missing, so only the
/// code's place says so.
///
/// Being outside the fence gets its own wording and its own icon. It is not a
/// fault and there is nothing for the reader to fix: the pass issues itself
/// when they arrive, and the screen is already watching for that.
class _NoPassCard extends StatelessWidget {
  const _NoPassCard({required this.zone, this.reason});

  final CampusZone zone;
  final String? reason;

  @override
  Widget build(BuildContext context) {
    final outside = zone == CampusZone.outside;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F0FF),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Icon(
            outside ? Icons.location_off_outlined : Icons.qr_code_2_outlined,
            size: 40,
            color: AppColors.gateBlue,
          ),
          const SizedBox(height: 12),
          Text(
            outside ? 'Outside campus' : 'No entry QR yet',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          Text(
            reason ?? "Today's campus entry QR is not active yet.",
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted),
          ),
          if (outside) ...[
            const SizedBox(height: 14),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 10),
                Flexible(
                  child: Text(
                    'Watching for the campus boundary',
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
