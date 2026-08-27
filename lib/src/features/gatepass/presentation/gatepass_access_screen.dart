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
    final approved = store.requests
        .where((request) => request.status == ApprovalStatus.approved)
        .firstOrNull;
    final daily = store.dailyPass;
    final pass = approved?.qrPayload ?? daily?.qrPayload;
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
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.gateLime,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'ACTIVE',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          store.student.residency.label,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
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
                      approved?.id ?? daily!.id,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      approved == null
                          ? 'Valid ${formatTime(daily!.validFrom)} - ${formatTime(daily.validUntil)}'
                          : 'Valid until ${formatShortDate(approved.returnAt)}, ${formatTime(approved.returnAt)}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (pass != null)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F0FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.brightness_7_outlined,
                        color: AppColors.gateBlue,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Increase screen brightness before presenting the QR.',
                        ),
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
                child: Column(
                  children: store.movements
                      .map(
                        (movement) => ListTile(
                          leading: Icon(
                            movement.direction == MovementDirection.entry
                                ? Icons.login
                                : Icons.logout,
                            color: movement.direction == MovementDirection.entry
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
