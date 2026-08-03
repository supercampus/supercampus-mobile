import 'canteen_models.dart';

abstract interface class CanteenRepository {
  Future<CanteenStore> loadStore();

  Future<WalletTopUpResult> topUpWallet(double amount);

  Future<OrderPlacementResult> placeOrder({
    required List<CartLine> lines,
    required FulfilmentMode fulfilmentMode,
  });
}

class CanteenException implements Exception {
  const CanteenException(this.message);

  final String message;

  @override
  String toString() => message;
}
