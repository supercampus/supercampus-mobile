import 'canteen_repository.dart';

/// Whether the signed-in user has a wallet PIN, and a recovery word for it.
class WalletPinStatus {
  const WalletPinStatus({required this.hasPin, required this.hasPinHint});

  final bool hasPin;
  final bool hasPinHint;
}

/// How the user proves who they are before changing the PIN. The wire values
/// are the backend's `method` field.
enum WalletPinVerification {
  currentPin('current_pin'),
  recoveryWord('hint'),
  password('password');

  const WalletPinVerification(this.wireValue);

  final String wireValue;
}

/// Raised when the user already has a PIN but tried to set a first one
/// (HTTP 409). The message is the server's, written for people.
class WalletPinAlreadySetException extends CanteenException {
  const WalletPinAlreadySetException(super.message);
}

/// The wallet-PIN endpoints. Every failure throws a [CanteenException]
/// carrying the server's human message, so screens can show it inline.
abstract interface class WalletPinRepository {
  /// `GET /api/v1/operations/canteen/store` → `hasPin`, `hasPinHint`.
  Future<WalletPinStatus> loadPinStatus();

  /// `POST /api/v1/operations/canteen/wallet-pin` — first PIN only.
  Future<void> setWalletPin(String pinHash, {String? hint});

  /// `PUT /api/v1/operations/canteen/wallet-pin`. Returns whether a recovery
  /// word is stored after the change.
  ///
  /// [newHint]: null leaves the recovery word alone, an empty string clears
  /// it, anything else replaces it.
  Future<bool> changeWalletPin({
    required String newPinHash,
    required WalletPinVerification method,
    String? currentPinHash,
    String? hint,
    String? password,
    String? newHint,
  });
}
