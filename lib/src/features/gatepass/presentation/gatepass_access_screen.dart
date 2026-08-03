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
    final pass = approved?.qrPayload ?? store.dailyPass.qrPayload;
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
                      approved?.id ?? store.dailyPass.id,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      approved == null
                          ? 'Valid ${formatTime(store.dailyPass.validFrom)} - ${formatTime(store.dailyPass.validUntil)}'
                          : 'Valid until ${formatShortDate(approved.returnAt)}, ${formatTime(approved.returnAt)}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
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
