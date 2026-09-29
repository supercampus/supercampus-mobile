import 'package:flutter/material.dart';

import '../../../../../core/theme/app_palette.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../payment_requests/data/payment_request_models.dart';
import 'status_card_models.dart';

/// Home status card for a payment the accounts office requested: what it is
/// for, how much, when it is due and where it stands (Pending, Overdue,
/// Paid). Colour carries the status; the amount is the largest thing on it.
class PaymentRequestCard extends StatelessWidget {
  const PaymentRequestCard({super.key, required this.data, required this.onTap});

  final PaymentRequestCardData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final request = data.request;
    final (tone, toneSoft) = switch (request.status) {
      PaymentRequestStatus.overdue => (palette.danger, palette.dangerSoft),
      PaymentRequestStatus.paid => (palette.success, palette.successSoft),
      PaymentRequestStatus.cancelled => (palette.inkTertiary, palette.surfaceMuted),
      PaymentRequestStatus.pending => (palette.warning, palette.warningSoft),
    };
    final footnote = switch (request.status) {
      PaymentRequestStatus.paid when request.paidAt != null =>
        'Paid ${formatShortDate(request.paidAt!)}',
      PaymentRequestStatus.paid => 'Paid',
      PaymentRequestStatus.cancelled => 'Withdrawn by the accounts office',
      _ when request.dueDate != null =>
        '${request.status == PaymentRequestStatus.overdue ? 'Was due' : 'Due'} '
            '${formatShortDate(request.dueDate!)}',
      _ => 'No due date',
    };
    final action = request.status.isOpen
        ? (data.canPayOnline ? 'Pay now' : 'Details')
        : 'View';

    return Semantics(
      button: true,
      label:
          '${request.purposeLabel}: ${request.title}, '
          '${formatCurrency(request.amount)}, ${request.status.label}, $footnote',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 128,
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: palette.border),
            ),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: toneSoft,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        paymentPurposeIcon(request.purpose),
                        size: 15,
                        color: tone,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        request.purposeLabel.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.4,
                          color: palette.inkSecondary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: toneSoft,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        request.status.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: tone,
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            request.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                              color: palette.ink,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            footnote,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color:
                                  request.status == PaymentRequestStatus.overdue
                                  ? palette.danger
                                  : palette.inkSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          formatCurrency(request.amount),
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                            height: 1.1,
                            color: palette.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              action,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: palette.brand,
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 16,
                              color: palette.brand,
                            ),
                          ],
                        ),
                      ],
                    ),
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

IconData paymentPurposeIcon(String purpose) => switch (purpose) {
  'fine' => Icons.gavel_rounded,
  'electricity' => Icons.bolt_rounded,
  'hostel' => Icons.bed_rounded,
  'exam' => Icons.edit_note_rounded,
  'library' => Icons.menu_book_rounded,
  'transport' => Icons.directions_bus_rounded,
  'event' => Icons.celebration_rounded,
  _ => Icons.receipt_long_rounded,
};
