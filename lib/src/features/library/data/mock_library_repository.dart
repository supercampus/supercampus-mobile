import 'library_models.dart';

class MockLibraryRepository {
  LibraryVisitPass? _pass;
  static const capacity = 500;
  static const booked = 487;

  int availableAt(DateTime start) => switch (start.minute) {
    0 => 13,
    15 => 19,
    30 => 32,
    45 => 6,
    _ => 13,
  };

  LibraryVisitPass? get currentPass => _pass;

  LibraryVisitPass book({required DateTime start, required int duration}) {
    if (availableAt(start) <= 0) throw StateError('This time is full.');
    final end = start.add(Duration(minutes: duration));
    return _pass = LibraryVisitPass(
      id: 'LIB-${start.millisecondsSinceEpoch.toString().substring(7)}',
      date: start,
      start: start,
      end: end,
      durationMinutes: duration,
      status: LibraryPassStatus.active,
      qrToken: 'supercampus:library:${start.millisecondsSinceEpoch}',
    );
  }

  LibraryVisitPass checkIn() {
    final pass = _pass;
    if (pass == null) throw StateError('Book a library visit first.');
    if (pass.status != LibraryPassStatus.active) {
      throw StateError('This pass is not active for entry.');
    }
    return _pass = pass.copyWith(
      status: LibraryPassStatus.inside,
      checkInAt: DateTime.now(),
    );
  }

  LibraryVisitPass checkOut() {
    final pass = _pass;
    if (pass == null || pass.status != LibraryPassStatus.inside) {
      throw StateError('Check-in is required before check-out.');
    }
    return _pass = pass.copyWith(
      status: LibraryPassStatus.used,
      checkOutAt: DateTime.now(),
    );
  }

  void cancel() => _pass = _pass?.copyWith(status: LibraryPassStatus.cancelled);
}
