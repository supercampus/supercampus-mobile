import 'razorpay_checkout_models.dart';

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
  }) => throw const RazorpayCheckoutException(
    'Razorpay Standard Checkout is available in the web portal.',
  );
}
