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
