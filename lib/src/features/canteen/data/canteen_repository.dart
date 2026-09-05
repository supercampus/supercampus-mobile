import 'dart:typed_data';

import 'canteen_models.dart';

abstract interface class CanteenRepository {
  Future<CanteenStore> loadStore();

  Future<WalletTopUpResult> topUpWallet(double amount);

  Future<OrderPlacementResult> placeOrder({required List<CartLine> lines});

  Future<void> updateOrderStatus(
    String orderId,
    CanteenOrderStatus status, {
    String? reason,
  });

  Future<void> scanOrder(String qrPayload);

  Future<CanteenStaffState> updateStaffState({
    required CanteenStaffMode mode,
    bool? shopOpen,
  });

  Future<CanteenMenuItem> saveMenuItem(
    CanteenMenuItem item, {
    required bool create,
  });

  Future<void> deleteMenuItem(String itemId);

  Future<String> uploadMedia(Uint8List bytes, {required String filename});

  Future<double> updateLaundryPrice(double pricePerKg);

  Future<LaundryCharge> createLaundryCharge({
    required LaundryServiceType serviceType,
    required String name,
    required String description,
    required double quantity,
    double? price,
  });

  Future<LaundryCharge> claimLaundryCharge(String qrPayload);

  Future<LaundryPaymentResult> payLaundryCharge(String chargeId);
}

class CanteenException implements Exception {
  const CanteenException(this.message);

  final String message;

  @override
  String toString() => message;
}
