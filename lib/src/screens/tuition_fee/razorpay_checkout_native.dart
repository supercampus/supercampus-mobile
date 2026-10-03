import 'dart:async';

import 'package:razorpay_flutter/razorpay_flutter.dart';

import 'razorpay_checkout_models.dart';

/// Razorpay Standard Checkout on Android and iOS, through Razorpay's own SDK.
class RazorpayCheckoutClient {
  const RazorpayCheckoutClient();

  Future<RazorpayCheckoutResult> open({
    required String keyId,
    required String orderId,
    required int amount,
    required String currency,
    required String name,
    required String description,
    required String customerName,
    required String customerEmail,
  }) {
    final completer = Completer<RazorpayCheckoutResult>();
    final razorpay = Razorpay();

    void finish() => razorpay.clear();

    razorpay
      ..on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse response) {
        if (completer.isCompleted) return;
        final paymentId = response.paymentId ?? '';
        final returnedOrderId = response.orderId ?? '';
        final signature = response.signature ?? '';
        if (paymentId.isEmpty || returnedOrderId.isEmpty || signature.isEmpty) {
          completer.completeError(
            const RazorpayCheckoutException(
              'Razorpay returned an incomplete payment response.',
            ),
          );
        } else {
          completer.complete(
            RazorpayCheckoutResult(
              paymentId: paymentId,
              orderId: returnedOrderId,
              signature: signature,
            ),
          );
        }
        finish();
      })
      ..on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse response) {
        if (completer.isCompleted) return;
        completer.completeError(
          response.code == Razorpay.PAYMENT_CANCELLED
              ? const RazorpayCheckoutException(
                  'Payment was cancelled.',
                  cancelled: true,
                )
              : RazorpayCheckoutException(_failureMessage(response)),
        );
        finish();
      })
      ..on(Razorpay.EVENT_EXTERNAL_WALLET, (ExternalWalletResponse response) {
        // External wallets are not enabled for these orders; treat the
        // choice as backing out so the person can pick another method.
        if (completer.isCompleted) return;
        completer.completeError(
          const RazorpayCheckoutException(
            'Payment was cancelled.',
            cancelled: true,
          ),
        );
        finish();
      });

    try {
      razorpay.open({
        'key': keyId,
        'order_id': orderId,
        'amount': amount,
        'currency': currency,
        'name': name,
        'description': description,
        'prefill': {'name': customerName, 'email': customerEmail},
        'theme': {'color': '#5700FF'},
        'retry': {'enabled': true},
      });
    } catch (_) {
      finish();
      if (!completer.isCompleted) {
        completer.completeError(
          const RazorpayCheckoutException(
            'Razorpay Checkout could not be opened.',
          ),
        );
      }
    }
    return completer.future;
  }
}

/// Razorpay's failure message, which arrives either as plain text or as the
/// JSON of its error object.
String _failureMessage(PaymentFailureResponse response) {
  final raw = response.message?.trim() ?? '';
  final description = RegExp(
    r'"description"\s*:\s*"([^"]+)"',
  ).firstMatch(raw)?.group(1);
  if (description != null && description.isNotEmpty) return description;
  if (raw.isNotEmpty && !raw.startsWith('{')) return raw;
  return 'Payment failed. Please try again.';
}
