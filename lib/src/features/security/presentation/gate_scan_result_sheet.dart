import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/security_gate_repository.dart';
import 'gate_movement_tile.dart';

enum GateScanResultKind { accepted, alreadyScanned, rejected }

/// The answer to a scan, sized for a guard glancing at it: one colour, one
/// icon, one verdict, then the few facts that back it up.
class GateScanResultSheet extends StatelessWidget {
  const GateScanResultSheet({
    super.key,
    required this.kind,
    required this.title,
    required this.message,
    this.movement,
  });

  final GateScanResultKind kind;
  final String title;
  final String message;

  /// The recorded movement (accepted) or the earlier one (already scanned).
  final SecurityGateMovement? movement;

  static Future<void> show(
    BuildContext context, {
    required GateScanResultKind kind,
    required String title,
    required String message,
    SecurityGateMovement? movement,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GateScanResultSheet(
        kind: kind,
        title: title,
        message: message,
        movement: movement,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final (Color ink, Color soft, IconData icon) = switch (kind) {
      GateScanResultKind.accepted => (
        p.success,
        p.successSoft,
        Icons.check_circle_rounded,
      ),
      GateScanResultKind.alreadyScanned => (
        p.warning,
        p.warningSoft,
        Icons.history_toggle_off_rounded,
      ),
      GateScanResultKind.rejected => (
        p.danger,
        p.dangerSoft,
        Icons.block_rounded,
      ),
    };
    final movement = this.movement;
    return Container(
      key: ValueKey('gate-result-${kind.name}'),
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
      decoration: BoxDecoration(
        color: p.surfaceRaised,
        borderRadius: BorderRadius.circular(28),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: soft,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 30, color: ink),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 22,
                      height: 1.15,
                      letterSpacing: -0.3,
                      fontWeight: FontWeight.w700,
                      color: p.ink,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(fontSize: 15, height: 1.4, color: p.inkSecondary),
            ),
            if (movement != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: p.surfaceSunken,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        GatePersonAvatar(
                          name: movement.displayName,
                          photoUrl: movement.photoUrl,
                          size: 40,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                movement.displayName,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: p.ink,
                                ),
                              ),
                              Text(
                                movement.passTypeLabel,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: p.inkSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        GateDirectionPill(direction: movement.direction),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _fact(
                      context,
                      kind == GateScanResultKind.alreadyScanned
                          ? 'First scanned'
                          : 'Time',
                      gateDateTime(movement.createdAt),
                    ),
                    _fact(context, 'Checkpoint', movement.checkpoint),
                    if (movement.scannedByName != null)
                      _fact(context, 'Scanned by', movement.scannedByName!),
                    if (movement.late)
                      _fact(context, 'Return', 'Late — after the pass window'),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: p.brand,
                foregroundColor: p.onBrand,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: () => Navigator.pop(context),
              child: Text(
                kind == GateScanResultKind.accepted ? 'Scan next' : 'Done',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fact(BuildContext context, String label, String value) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: p.inkSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: p.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
