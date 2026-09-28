import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/security_gate_repository.dart';

/// "9:05 AM"
String gateTime(DateTime value) {
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${value.hour < 12 ? 'AM' : 'PM'}';
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];
const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// "28 Sep, 9:05 AM"
String gateDateTime(DateTime value) =>
    '${value.day} ${_months[value.month - 1]}, ${gateTime(value)}';

/// "Today", "Yesterday" or "Mon, 26 Sep".
String gateDayLabel(DateTime value, {DateTime? now}) {
  final today = DateUtils.dateOnly(now ?? DateTime.now());
  final day = DateUtils.dateOnly(value);
  final difference = today.difference(day).inDays;
  if (difference == 0) return 'Today';
  if (difference == 1) return 'Yesterday';
  return '${_weekdays[value.weekday - 1]}, ${value.day} ${_months[value.month - 1]}';
}

String initialsOf(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  final first = parts.first.characters.first;
  final last = parts.length > 1 ? parts.last.characters.first : '';
  return (first + last).toUpperCase();
}

/// Round photo, or initials on the brand tint when there is none.
class GatePersonAvatar extends StatelessWidget {
  const GatePersonAvatar({
    super.key,
    required this.name,
    this.photoUrl,
    this.size = 44,
  });

  final String name;
  final String? photoUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final initials = Text(
      initialsOf(name),
      style: TextStyle(
        color: p.brandInk,
        fontWeight: FontWeight.w600,
        fontSize: size * 0.34,
      ),
    );
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: p.brandSoft, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: photoUrl == null
          ? initials
          : Image.network(
              photoUrl!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => initials,
            ),
    );
  }
}

/// Direction pill: brand for gate-in, neutral ink for gate-out.
class GateDirectionPill extends StatelessWidget {
  const GateDirectionPill({super.key, required this.direction});

  final GateDirection direction;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final entry = direction == GateDirection.entry;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: entry ? p.brandSoft : p.surfaceMuted,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            entry ? Icons.south_west_rounded : Icons.north_east_rounded,
            size: 12,
            color: entry ? p.brandInk : p.inkSecondary,
          ),
          const SizedBox(width: 3),
          Text(
            direction.label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: entry ? p.brandInk : p.inkSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// One movement in a list: who, pass type, direction, time, checkpoint, guard.
class GateMovementTile extends StatelessWidget {
  const GateMovementTile({
    super.key,
    required this.movement,
    required this.onTap,
  });

  final SecurityGateMovement movement;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final details = [
      movement.checkpoint,
      if (movement.scannedByName != null) movement.scannedByName!,
    ].join(' · ');
    return Semantics(
      button: true,
      label:
          '${movement.displayName}, ${movement.passTypeLabel}, ${movement.direction.label} at ${gateTime(movement.createdAt)}',
      child: Material(
        color: p.surface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          key: ValueKey('gate-movement-${movement.id}'),
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: p.border),
            ),
            child: Row(
              children: [
                GatePersonAvatar(
                  name: movement.displayName,
                  photoUrl: movement.photoUrl,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        movement.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w600,
                          color: p.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        movement.rollNumber == null
                            ? movement.passTypeLabel
                            : '${movement.passTypeLabel} · ${movement.rollNumber}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: p.inkSecondary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        details,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: p.inkTertiary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      gateTime(movement.createdAt),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: p.inkSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    GateDirectionPill(direction: movement.direction),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
