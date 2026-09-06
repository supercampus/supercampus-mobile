import 'gatepass_models.dart';

/// The exact server-issued payload shown on both the Gatepass screen and its
/// home module card. An active approved request takes precedence over the
/// location-bound daily pass because it is the credential for that movement.
String? gatepassCardQr(GatepassStore store, {DateTime? at}) {
  final now = at ?? DateTime.now();
  final approved = store.requests
      .where(
        (request) =>
            request.status == ApprovalStatus.approved &&
            request.qrPayload?.isNotEmpty == true &&
            request.returnAt.isAfter(now),
      )
      .firstOrNull;
  return approved?.qrPayload ?? store.dailyPass?.qrPayload;
}
