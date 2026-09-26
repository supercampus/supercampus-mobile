import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../data/gatepass_models.dart';
import 'widgets/gatepass_ui.dart';

class GatepassAccessScreen extends StatelessWidget {
  const GatepassAccessScreen({super.key, required this.store});

  final GatepassStore store;

  void _showMovementDetails(
    BuildContext context,
    GateMovement movement,
    List<GateMovement> allMovements,
  ) {
    String outTimeStr;
    String inTimeStr;

    if (movement.direction == MovementDirection.exit) {
      outTimeStr = formatTime(movement.recordedAt);
      final returns = allMovements
          .where(
            (m) =>
                m.direction == MovementDirection.entry &&
                m.recordedAt.isAfter(movement.recordedAt),
          )
          .toList()
        ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
      inTimeStr = returns.isNotEmpty
          ? formatTime(returns.first.recordedAt)
          : 'Pending return';
    } else {
      inTimeStr = formatTime(movement.recordedAt);
      final departures = allMovements
          .where(
            (m) =>
                m.direction == MovementDirection.exit &&
                m.recordedAt.isBefore(movement.recordedAt),
          )
          .toList()
        ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
      outTimeStr = departures.isNotEmpty
          ? formatTime(departures.first.recordedAt)
          : 'Not recorded';
    }

    final p = context.palette;
    final lineColor = context.adaptive(
      light: const Color(0xFFE5E7EB),
      dark: p.border,
    );
    final hairline = context.adaptive(
      light: const Color(0xFFF3F4F6),
      dark: p.divider,
    );
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: p.surfaceRaised,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Movement Details',
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.adaptive(
                    light: const Color(0xFFF9FAFB),
                    dark: p.surfaceSunken,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: lineColor),
                ),
                child: Column(
                  children: [
                    _DetailRow(
                      icon: Icons.logout_rounded,
                      label: 'Out Time',
                      value: outTimeStr,
                      valueColor: context.adaptive(
                        light: AppColors.gateMagenta,
                        dark: const Color(0xFFD58CFF),
                      ),
                    ),
                    Divider(height: 20, color: lineColor),
                    _DetailRow(
                      icon: Icons.login_rounded,
                      label: 'In Time',
                      value: inTimeStr,
                      valueColor: inTimeStr == 'Pending return'
                          ? p.warning
                          : context.adaptive(
                              light: const Color(0xFF059669),
                              dark: const Color(0xFF6EE7B7),
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: lineColor),
                ),
                child: Column(
                  children: [
                    _DetailRow(
                      icon: Icons.calendar_today_outlined,
                      label: 'Date',
                      value: formatShortDate(movement.recordedAt),
                    ),
                    Divider(height: 16, color: hairline),
                    _DetailRow(
                      icon: Icons.meeting_room_outlined,
                      label: 'Gate',
                      value: movement.gate,
                    ),
                    Divider(height: 16, color: hairline),
                    _DetailRow(
                      icon: Icons.verified_outlined,
                      label: 'Method',
                      value: movement.method,
                    ),
                    Divider(height: 16, color: hairline),
                    _DetailRow(
                      icon: Icons.swap_horiz_rounded,
                      label: 'Recorded Direction',
                      value: movement.direction == MovementDirection.entry
                          ? 'Campus Entry'
                          : 'Campus Exit',
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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            children: [
              const GatepassPageHeader(
                title: 'Recent movement',
                subtitle: 'Campus entry and exit logs',
              ),
              const SizedBox(height: 20),
              GatepassSurface(
                child: store.movements.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.history,
                              color: context.palette.inkSecondary,
                            ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                'No gate movements recorded yet.',
                                style: TextStyle(
                                  color: context.palette.inkSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        children: store.movements
                            .map(
                              (movement) => ListTile(
                                onTap: () => _showMovementDetails(
                                  context,
                                  movement,
                                  store.movements,
                                ),
                                leading: Icon(
                                  movement.direction == MovementDirection.entry
                                      ? Icons.login
                                      : Icons.logout,
                                  color: movement.direction ==
                                          MovementDirection.entry
                                      ? context.adaptive(
                                          light: const Color(0xFF087A4B),
                                          dark: const Color(0xFF6EE7B7),
                                        )
                                      : context.adaptive(
                                          light: AppColors.gateMagenta,
                                          dark: const Color(0xFFD58CFF),
                                        ),
                                ),
                                title: Text(
                                  movement.direction == MovementDirection.entry
                                      ? 'Entry'
                                      : 'Exit',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  '${formatShortDate(movement.recordedAt)} • ${movement.gate}',
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      formatTime(movement.recordedAt),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      size: 18,
                                      color: context.palette.borderStrong,
                                    ),
                                  ],
                                ),
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

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: context.palette.inkSecondary),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(fontSize: 14, color: context.palette.inkSecondary),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: valueColor ?? context.palette.ink,
          ),
        ),
      ],
    );
  }
}
