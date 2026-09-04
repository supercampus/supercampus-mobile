import 'dart:async';
import 'dart:js_interop';

import 'razorpay_checkout_models.dart';

@JS('superCampusOpenRazorpay')
external void _openRazorpay(
  JSObject options,
  JSFunction onSuccess,
  JSFunction onFailure,
  JSFunction onDismiss,
);

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

    void succeed(JSAny? raw) {
      if (completer.isCompleted) return;
      final value = raw?.dartify();
      final data = value is Map ? value : const <Object?, Object?>{};
      final paymentId = data['razorpay_payment_id']?.toString() ?? '';
      final returnedOrderId = data['razorpay_order_id']?.toString() ?? '';
      final signature = data['razorpay_signature']?.toString() ?? '';
      if (paymentId.isEmpty || returnedOrderId.isEmpty || signature.isEmpty) {
        completer.completeError(
          const RazorpayCheckoutException(
            'Razorpay returned an incomplete payment response.',
          ),
        );
        return;
      }
      completer.complete(
        RazorpayCheckoutResult(
          paymentId: paymentId,
          orderId: returnedOrderId,
          signature: signature,
        ),
      );
    }

    void fail(JSAny? raw) {
      if (completer.isCompleted) return;
      final value = raw?.dartify();
      final data = value is Map ? value : const <Object?, Object?>{};
      final message =
          data['description']?.toString() ??
          data['reason']?.toString() ??
          'Payment failed. Please try again.';
      completer.completeError(RazorpayCheckoutException(message));
    }

    void dismiss() {
      if (completer.isCompleted) return;
      completer.completeError(
        const RazorpayCheckoutException(
          'Payment was cancelled.',
          cancelled: true,
        ),
      );
    }

    final options =
        <String, Object?>{
              'key': keyId,
              'order_id': orderId,
              'amount': amount,
              'currency': currency,
              'name': name,
              'description': description,
              'prefill': {'name': customerName, 'email': customerEmail},
              'theme': {'color': '#5700FF'},
              'retry': {'enabled': true},
            }.jsify()
            as JSObject;

    try {
      _openRazorpay(options, succeed.toJS, fail.toJS, dismiss.toJS);
    } catch (_) {
      completer.completeError(
        const RazorpayCheckoutException(
          'Razorpay Checkout could not be opened.',
        ),
      );
    }
    return completer.future;
  }
}
