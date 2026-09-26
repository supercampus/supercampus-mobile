import 'gatepass_models.dart';

/// Returns ONLY a valid active approved outpass or leave pass (Gate-Out) QR payload.
///
/// Returns null if no active approved outpass or leave pass exists.
/// Never returns a Gate-In QR code.
String? validGateOutPassQr(GatepassStore store, {DateTime? at}) {
  final now = at ?? DateTime.now();
  final approved = store.requests
      .where(
        (request) =>
            request.status == ApprovalStatus.approved &&
            request.qrPayload?.isNotEmpty == true &&
            request.returnAt.isAfter(now),
      )
      .firstOrNull;
  if (approved == null) return null;
  final payload = approved.qrPayload?.trim();
  if (payload == null || payload.isEmpty) return null;
  // Ensure it's not a gate-in code
  if (payload.contains('/day/') ||
      payload.contains('/entry/') ||
      payload.contains('/gate_in/') ||
      payload.contains('gate-in')) {
    return null;
  }
  return payload;
}

/// Returns the Gate-In QR code payload specifically for campus entry.
///
/// This is used next to the Apply Leave/Outpass buttons.
/// Never returns an Outpass or Leave pass QR code.
String gateInPassQr(GatepassStore store) {
  if (store.dailyPass?.qrPayload case final qr? when qr.trim().isNotEmpty) {
    if (!qr.contains('/outpass/') &&
        !qr.contains('/leave/') &&
        !qr.contains('/exit/')) {
      return qr;
    }
  }
  final roll = store.student.rollNumber.isNotEmpty
      ? store.student.rollNumber
      : (store.student.email.isNotEmpty ? store.student.email : 'STUDENT');
  return 'supercampus://gate/entry/$roll';
}

/// Returns the Gate-Out pass QR payload for home status cards and overview.
/// Never falls back to a Gate-In QR code.
String? gatepassCardQr(GatepassStore store, {DateTime? at}) {
  return validGateOutPassQr(store, at: at);
}
