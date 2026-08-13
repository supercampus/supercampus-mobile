import 'hostel_models.dart';

abstract class HostelRepository {
  Future<HostelStore> loadStore();
  Future<HostelApplication> applyForAccommodation({
    required String preferredRoomType,
    required String specialRequirements,
  });
  Future<HostelOutpass> requestOutpass({
    required DateTime leavingAt,
    required DateTime expectedReturnAt,
    required String destination,
    required String reason,
  });
  Future<HostelOutpass> approveOutpass(String outpassId);
  Future<HostelMovement> scanOutpassGate({
    required String outpassId,
    required String gateName,
    required String action, // EXIT or ENTRY
  });
  Future<MessMealToken> redeemMessMeal(String tokenId);
  Future<HostelComplaint> submitComplaint({
    required String category,
    required String description,
  });
  Future<RoomChangeRequest> requestRoomChange({
    required String reason,
    required String preferredHostel,
  });
  Future<VisitorPass> inviteVisitor({
    required String visitorName,
    required String visitorContact,
    required String purpose,
    required DateTime visitDate,
    required String validFromTime,
    required String validUntilTime,
  });
  Future<HostelClearance> submitVacateRequest();
  Future<HostelClearance> updateClearanceChecklist({
    required String clearanceId,
    required bool roomCleared,
    required bool assetsReturned,
    required bool keyReturned,
    required bool feesPaid,
    required bool messCleared,
    required bool complaintsClosed,
    required bool damageSettled,
  });
  Future<HostelResidency> completeCheckout(String residencyId);
}
