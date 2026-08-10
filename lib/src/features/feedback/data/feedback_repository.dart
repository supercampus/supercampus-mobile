import 'feedback_models.dart';

abstract interface class FeedbackRepository {
  Future<FeedbackStore> loadStore();

  Future<FeedbackTicket> submitFeedback(FeedbackDraft draft);

  Future<FeedbackTicket> acknowledgeTicket(String ticketId);

  Future<FeedbackTicket> resolveTicket(String ticketId, {required int rating});

  Future<FeedbackTicket> reopenTicket(String ticketId);
}

class FeedbackException implements Exception {
  const FeedbackException(this.message);

  final String message;

  @override
  String toString() => message;
}
