import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/features/library/data/library_models.dart';
import 'package:supercampus_mobile/src/features/library/data/library_repository.dart';
import 'package:supercampus_mobile/src/features/library/presentation/library_visit_slots_section.dart';

void main() {
  testWidgets('shows slot booking controls and active visits inline', (
    tester,
  ) async {
    final date = DateTime(2026, 9, 9);
    final repository = _FakeLibraryRepository([
      LibraryVisitPass(
        id: 'LIB-1',
        date: date,
        start: DateTime(2026, 9, 9, 10),
        end: DateTime(2026, 9, 9, 11),
        durationMinutes: 60,
        status: LibraryPassStatus.approved,
        qrToken: 'library-pass',
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: LibraryVisitSlotsSection(repository: repository),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Library visit slots'), findsOneWidget);
    expect(find.text('Book a visit slot'), findsOneWidget);
    expect(find.text('Central Library - Reading Hall'), findsOneWidget);
    expect(find.text('Approved'), findsOneWidget);
    expect(find.text('Show QR'), findsOneWidget);
  });
}

class _FakeLibraryRepository implements LibraryRepository {
  _FakeLibraryRepository(this._bookings);

  final List<LibraryVisitPass> _bookings;

  @override
  List<LibraryVisitPass> get bookings => List.unmodifiable(_bookings);

  @override
  Future<List<LibraryVisitPass>> loadBookings() async => bookings;

  @override
  int availableSlots({
    required DateTime date,
    required int startHour,
    required int startMinute,
    required int endHour,
    required int endMinute,
  }) => 25;

  @override
  Future<LibraryVisitPass> book({
    required DateTime date,
    required int startHour,
    required int startMinute,
    required int endHour,
    required int endMinute,
    String? description,
    String? zoneName,
  }) async => throw UnimplementedError();

  @override
  Future<LibraryVisitPass> cancelBooking(String id) async =>
      throw UnimplementedError();

  @override
  Future<LibraryVisitPass> earlyCheckOut(String id) async =>
      throw UnimplementedError();
}
