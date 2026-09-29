import 'package:flutter/material.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/transaction_result_overlay.dart';
import '../../modules/presentation/widgets/status_cards/payment_request_card.dart';
import '../../modules/presentation/widgets/status_cards/status_card_models.dart';
import '../data/payment_request_models.dart';
import '../data/payment_request_repository.dart';

/// Opens the details of a payment request from its home card, with the way
/// to pay it.
Future<void> showPaymentRequestSheet(
  BuildContext context, {
  required PaymentRequestCardData data,
  required String customerName,
  required String customerEmail,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: context.palette.canvas,
    builder: (_) => PaymentRequestSheet(
      data: data,
      customerName: customerName,
      customerEmail: customerEmail,
    ),
  );
}

class PaymentRequestSheet extends StatefulWidget {
  const PaymentRequestSheet({
    super.key,
    required this.data,
    required this.customerName,
    required this.customerEmail,
  });

  final PaymentRequestCardData data;
  final String customerName;
  final String customerEmail;

  @override
  State<PaymentRequestSheet> createState() => _PaymentRequestSheetState();
}

class _PaymentRequestSheetState extends State<PaymentRequestSheet> {
  bool _paying = false;
  String? _error;

  StudentPaymentRequest get _request => widget.data.request;

  Future<void> _pay() async {
    final checkout = widget.data.checkout;
    if (checkout == null || _paying) return;
    setState(() {
      _paying = true;
      _error = null;
    });
    try {
      await checkout.payOnline(
        _request,
        customerName: widget.customerName,
        customerEmail: widget.customerEmail,
      );
      if (!mounted) return;
      final navigator = Navigator.of(context);
      await showTransactionResult(
        context,
        result: TransactionResult.success,
        title: 'Payment received',
        message: _request.title,
        amount: formatCurrency(_request.amount),
      );
      navigator.maybePop();
    } on PaymentRequestException catch (error) {
      if (!mounted) return;
      setState(() {
        _paying = false;
        _error = error.cancelled ? null : error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _paying = false;
        _error = 'The payment could not be completed. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final request = _request;
    final status = request.status;
    final tone = switch (status) {
      PaymentRequestStatus.overdue => palette.danger,
      PaymentRequestStatus.paid => palette.success,
      PaymentRequestStatus.cancelled => palette.inkTertiary,
      PaymentRequestStatus.pending => palette.warning,
    };
    final facts = <(String, String)>[
      ('Purpose', request.purposeLabel),
      ('Amount', formatCurrency(request.amount)),
      (
        'Due date',
        request.dueDate == null ? 'No due date' : formatShortDate(request.dueDate!),
      ),
      ('Status', status.label),
      if (request.paidAt != null) ('Paid on', formatShortDate(request.paidAt!)),
      if (request.paymentMethod != null)
        ('Paid by', paymentMethodLabel(request.paymentMethod!)),
    ];

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(paymentPurposeIcon(request.purpose), color: tone, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    status.label,
                    style: TextStyle(
                      color: tone,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                request.title,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                  color: palette.ink,
                ),
              ),
              if (request.description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  request.description,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.35,
                    color: palette.inkSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < facts.length; i++) ...[
                      if (i > 0)
                        Divider(height: 1, indent: 16, color: palette.divider),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Text(
                              facts[i].$1,
                              style: TextStyle(
                                fontSize: 15,
                                color: palette.inkSecondary,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              facts[i].$2,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: palette.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: palette.danger, fontSize: 14),
                ),
              ],
              const SizedBox(height: 16),
              if (widget.data.canPayOnline)
                FilledButton(
                  key: const ValueKey('payment-request-pay'),
                  onPressed: _paying ? null : _pay,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _paying
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text('Pay ${formatCurrency(request.amount)}'),
                )
              else if (status.isOpen)
                Text(
                  'Pay this at the accounts office. It will show as paid here '
                  'once they record it.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: palette.inkSecondary),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

String paymentMethodLabel(String method) => switch (method) {
  'razorpay' => 'Online (Razorpay)',
  'cash' => 'Cash',
  'bank_transfer' => 'Bank transfer',
  'upi' => 'UPI',
  'cheque' => 'Cheque',
  _ => 'Other',
};
