import 'gatepass_models.dart';

abstract interface class GatepassRepository {
  Future<GatepassStore> loadStore();

  Future<GatepassRequest> submitRequest(GatepassRequestDraft draft);

  Future<VisitorInvitation> inviteVisitor(VisitorInvitationDraft draft);

  Future<GatepassRequest> cancelRequest(String requestId);
}

class GatepassException implements Exception {
  const GatepassException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The API refused to activate a pass because the device is outside the campus
/// fence.
///
/// A distinct type because this is the one refusal that is not a fault: it says
/// exactly where the reader is standing, and the screen answers it with a
/// waiting state rather than an error.
class OutsideCampusException extends GatepassException {
  const OutsideCampusException(super.message);
}

/// The service gave back nothing this app can use — no such route, a body it
/// cannot read, or a server-side failure.
///
/// Separated from an ordinary failure because the module can still open on top
/// of it: whatever else loaded stays on screen, and only the part that depended
/// on this call reports itself missing. Matching on the sentence instead would
/// break the moment the wording improves.
class GatepassUnavailableException extends GatepassException {
  const GatepassUnavailableException(super.message);
}

/// Where the device is, including the uncertainty reported by the provider.
///
/// Declared here rather than as a `Position` so a caller — a test, a desktop
/// build with no GPS — can supply coordinates without depending on geolocator.
typedef CampusPosition = ({
  double latitude,
  double longitude,
  double accuracyMetres,
});

/// Supplies [CampusPosition]. Defaults to the device's GPS.
typedef CampusPositionProvider = Future<CampusPosition> Function();
