import 'dart:math';

import 'library_models.dart';

class MockLibraryRepository {
  MockLibraryRepository() {
    _seedBookings();
  }

  final List<LibraryVisitPass> _bookings = [];
  static const capacity = 500;

  static const _zones = [
    'Central Library - Reading Hall',
    'Central Library - Silent Zone',
    'Science Block Library',
    'Digital Resource Centre',
  ];

  List<LibraryVisitPass> get bookings =>
      List.unmodifiable(_bookings..sort((a, b) => b.date.compareTo(a.date)));

  int availableSlots({
    required DateTime date,
    required int startHour,
    required int startMinute,
    required int endHour,
    required int endMinute,
  }) {
    // Deterministic mock availability based on time hash
    final hash = (date.day * 31 + date.month * 7 + startHour * 13 + startMinute + endHour * 3) % 50;
    if (hash < 3) return 0; // ~6% chance of full
    return (hash * 3 + 5).clamp(1, 48);
  }

  /// Legacy compatibility
  int availableAt(DateTime start) => availableSlots(
    date: start,
    startHour: start.hour,
    startMinute: start.minute,
    endHour: start.hour + 1,
    endMinute: start.minute,
  );

  LibraryVisitPass book({
    required DateTime date,
    required int startHour,
    required int startMinute,
    required int endHour,
    required int endMinute,
    String? description,
    String? zoneName,
  }) {
    final available = availableSlots(
      date: date,
      startHour: startHour,
      startMinute: startMinute,
      endHour: endHour,
      endMinute: endMinute,
    );
    if (available <= 0) throw StateError('This slot is full.');

    final start = DateTime(date.year, date.month, date.day, startHour, startMinute);
    final end = DateTime(date.year, date.month, date.day, endHour, endMinute);
    final duration = end.difference(start).inMinutes;

    final rng = Random();
    final zone = zoneName ?? _zones[0];
    final seat = 'Seat ${(rng.nextInt(200) + 1).toString().padLeft(3, '0')}';

    final pass = LibraryVisitPass(
      id: 'LIB-${start.millisecondsSinceEpoch.toString().substring(7)}',
      date: date,
      start: start,
      end: end,
      durationMinutes: duration,
      status: start.isAfter(DateTime.now())
          ? LibraryPassStatus.upcoming
          : LibraryPassStatus.active,
      qrToken: 'supercampus:library:${start.millisecondsSinceEpoch}:$seat',
      zoneName: zone,
      seatNumber: seat,
      description: description,
    );
    _bookings.add(pass);
    return pass;
  }

  LibraryVisitPass checkIn(String id) {
    final index = _bookings.indexWhere((b) => b.id == id);
    if (index == -1) throw StateError('Booking not found.');
    final pass = _bookings[index];
    if (pass.status != LibraryPassStatus.active) {
      throw StateError('This pass is not active for entry.');
    }
    final updated = pass.copyWith(
      status: LibraryPassStatus.inside,
      checkInAt: DateTime.now(),
    );
    _bookings[index] = updated;
    return updated;
  }

  LibraryVisitPass checkOut(String id) {
    final index = _bookings.indexWhere((b) => b.id == id);
    if (index == -1) throw StateError('Booking not found.');
    final pass = _bookings[index];
    if (pass.status != LibraryPassStatus.inside) {
      throw StateError('Check-in is required before check-out.');
    }
    final updated = pass.copyWith(
      status: LibraryPassStatus.used,
      checkOutAt: DateTime.now(),
    );
    _bookings[index] = updated;
    return updated;
  }

  LibraryVisitPass cancelBooking(String id) {
    final index = _bookings.indexWhere((b) => b.id == id);
    if (index == -1) throw StateError('Booking not found.');
    final pass = _bookings[index];
    if (pass.status == LibraryPassStatus.used ||
        pass.status == LibraryPassStatus.cancelled) {
      throw StateError('Cannot cancel a completed or already cancelled booking.');
    }
    final updated = pass.copyWith(status: LibraryPassStatus.cancelled);
    _bookings[index] = updated;
    return updated;
  }

  LibraryVisitPass earlyCheckOut(String id) {
    return checkOut(id);
  }

  /// Legacy compatibility
  LibraryVisitPass? get currentPass => _bookings.isEmpty ? null : _bookings.last;

  /// Legacy compatibility
  void cancel() {
    if (_bookings.isNotEmpty) {
      cancelBooking(_bookings.last.id);
    }
  }

  void _seedBookings() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Upcoming booking — tomorrow morning
    final tomorrow = today.add(const Duration(days: 1));
    _bookings.add(LibraryVisitPass(
      id: 'LIB-8201',
      date: tomorrow,
      start: DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 10, 0),
      end: DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 12, 0),
      durationMinutes: 120,
      status: LibraryPassStatus.upcoming,
      qrToken: 'supercampus:library:seed:8201',
      zoneName: 'Central Library - Reading Hall',
      seatNumber: 'Seat 042',
    ));

    // Active booking — today
    _bookings.add(LibraryVisitPass(
      id: 'LIB-7305',
      date: today,
      start: DateTime(today.year, today.month, today.day, now.hour, 0),
      end: DateTime(today.year, today.month, today.day, now.hour + 2, 0),
      durationMinutes: 120,
      status: LibraryPassStatus.active,
      qrToken: 'supercampus:library:seed:7305',
      zoneName: 'Central Library - Silent Zone',
      seatNumber: 'Seat 118',
    ));

    // Completed booking — yesterday
    final yesterday = today.subtract(const Duration(days: 1));
    _bookings.add(LibraryVisitPass(
      id: 'LIB-6192',
      date: yesterday,
      start: DateTime(yesterday.year, yesterday.month, yesterday.day, 14, 0),
      end: DateTime(yesterday.year, yesterday.month, yesterday.day, 16, 0),
      durationMinutes: 120,
      status: LibraryPassStatus.used,
      qrToken: 'supercampus:library:seed:6192',
      zoneName: 'Science Block Library',
      seatNumber: 'Seat 007',
      checkInAt: DateTime(yesterday.year, yesterday.month, yesterday.day, 14, 2),
      checkOutAt: DateTime(yesterday.year, yesterday.month, yesterday.day, 15, 55),
    ));

    // Cancelled booking — 3 days ago
    final threeDaysAgo = today.subtract(const Duration(days: 3));
    _bookings.add(LibraryVisitPass(
      id: 'LIB-5044',
      date: threeDaysAgo,
      start: DateTime(threeDaysAgo.year, threeDaysAgo.month, threeDaysAgo.day, 9, 0),
      end: DateTime(threeDaysAgo.year, threeDaysAgo.month, threeDaysAgo.day, 11, 0),
      durationMinutes: 120,
      status: LibraryPassStatus.cancelled,
      qrToken: 'supercampus:library:seed:5044',
      zoneName: 'Digital Resource Centre',
      seatNumber: 'Seat 203',
    ));
  }
}
