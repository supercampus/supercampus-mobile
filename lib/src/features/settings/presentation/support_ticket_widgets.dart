import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../data/support_repository.dart';
import 'settings_ui.dart';

/// Text + icon status chip for a help request.
class SupportStatusPill extends StatelessWidget {
  const SupportStatusPill({super.key, required this.status});

  final SupportTicketStatus status;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final (icon, fg, bg) = switch (status) {
      SupportTicketStatus.open => (
        Icons.radio_button_unchecked_rounded,
        palette.info,
        palette.infoSoft,
      ),
      SupportTicketStatus.inProgress => (
        Icons.timelapse_rounded,
        palette.warning,
        palette.warningSoft,
      ),
      SupportTicketStatus.resolved => (
        Icons.check_circle_rounded,
        palette.success,
        palette.successSoft,
      ),
      SupportTicketStatus.closed => (
        Icons.lock_outline_rounded,
        palette.inkSecondary,
        palette.surfaceMuted,
      ),
    };
    return StatusPill(
      label: status.label,
      icon: icon,
      color: fg,
      background: bg,
    );
  }
}

String formatTicketDate(DateTime? value) =>
    value == null ? '' : DateFormat('d MMM y, h:mm a').format(value);

/// A help request as a row inside a grouped section.
class SupportTicketTile extends StatelessWidget {
  const SupportTicketTile({
    super.key,
    required this.ticket,
    this.showRequester = false,
    this.actions,
  });

  final SupportTicket ticket;
  final bool showRequester;
  final Widget? actions;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final meta = [
      ticket.categoryLabel,
      if (!showRequester && ticket.handledBy != null)
        'Goes to ${ticket.handledBy}',
      if (formatTicketDate(ticket.createdAt) case final date
          when date.isNotEmpty)
        date,
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  ticket.subject,
                  style: TextStyle(
                    color: palette.ink,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SupportStatusPill(status: ticket.status),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            meta,
            style: TextStyle(color: palette.inkSecondary, fontSize: 12.5),
          ),
          if (showRequester &&
              (ticket.requesterName != null ||
                  ticket.requesterEmail != null)) ...[
            const SizedBox(height: 3),
            Text(
              [
                ?ticket.requesterName,
                ?ticket.requesterEmail,
              ].join(' · '),
              style: TextStyle(
                color: palette.ink,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          if (ticket.message.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              ticket.message,
              maxLines: showRequester ? null : 3,
              overflow: showRequester ? null : TextOverflow.ellipsis,
              style: TextStyle(color: palette.ink, fontSize: 14, height: 1.35),
            ),
          ],
          if (ticket.resolutionNote case final note?) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: palette.surfaceSunken,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'Reply: ',
                      style: TextStyle(
                        color: palette.inkSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextSpan(text: note),
                  ],
                ),
                style: TextStyle(color: palette.ink, fontSize: 13.5),
              ),
            ),
          ],
          if (actions != null) ...[const SizedBox(height: 8), actions!],
        ],
      ),
    );
  }
}
