import 'library_models.dart';

abstract interface class LibraryRepository {
  List<LibraryVisitPass> get bookings;

  Future<List<LibraryVisitPass>> loadBookings();

  int availableSlots({
    required DateTime date,
    required int startHour,
    required int startMinute,
    required int endHour,
    required int endMinute,
  });

  Future<LibraryVisitPass> book({
    required DateTime date,
    required int startHour,
    required int startMinute,
    required int endHour,
    required int endMinute,
    String? description,
    String? zoneName,
  });

  Future<LibraryVisitPass> cancelBooking(String id);
  Future<LibraryVisitPass> earlyCheckOut(String id);
}
