class RazorpayCheckoutResult {
  const RazorpayCheckoutResult({
    required this.paymentId,
    required this.orderId,
    required this.signature,
  });

  final String paymentId;
  final String orderId;
  final String signature;
}

class RazorpayCheckoutException implements Exception {
  const RazorpayCheckoutException(this.message, {this.cancelled = false});

  final String message;
  final bool cancelled;
}
