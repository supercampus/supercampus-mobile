import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/core/theme/app_theme.dart';
import 'package:supercampus_mobile/src/features/hostel/data/backend_hostel_repository.dart';
import 'package:supercampus_mobile/src/features/hostel/data/hostel_models.dart';
import 'package:supercampus_mobile/src/features/hostel/data/mock_hostel_repository.dart';
import 'package:supercampus_mobile/src/features/hostel/presentation/hostel_ops_dashboard_screen.dart';

/// Records staff actions instead of calling the backend.
class _FakeHostelRepository extends MockHostelRepository {
  _FakeHostelRepository() : super(studentName: 'Warden', studentCode: '');

  final updates = <(String, String)>[];

  @override
  Future<HostelQueueRequest> updateRequestStatus({
    required String requestId,
    required String status,
    String? note,
  }) async {
    updates.add((requestId, status));
    return HostelQueueRequest(
      id: requestId,
      kind: 'complaint',
      status: status,
      requesterName: 'Arun K',
      createdAt: DateTime(2026, 9, 28),
      details: const {},
    );
  }
}

HostelOperations _operations() => parseHostelOperations({
  'scopeHostel': 'Boys Hostel',
  'residents': 50,
  'outside': 4,
  'onLeave': 2,
  'canUpdate': true,
  'hostels': [
    {'name': 'Boys Hostel', 'residents': 50, 'outside': 4},
  ],
  'overdue': [
    {
      'requestId': 'p1',
      'name': 'Arun K',
      'rollNumber': 'MEC26AI002',
      'hostel': 'Boys Hostel',
      'room': 'BH-101',
      'passType': 'outpass',
      'destination': 'Home',
      'departureAt': '2026-09-27T04:30:00Z',
      'returnAt': '2026-09-27T12:30:00Z',
      'exitedAt': '2026-09-27T04:35:00Z',
    },
  ],
  'away': const [],
  'requests': [
    {
      'id': 'c1',
      'kind': 'complaint',
      'status': 'submitted',
      'requesterName': 'Arun K',
      'rollNumber': 'MEC26AI002',
      'hostel': 'Boys Hostel',
      'room': 'BH-101',
      'createdAt': '2026-09-28T03:00:00Z',
      'details': {'category': 'Plumbing', 'description': 'Tap is leaking'},
    },
  ],
});

HostelOperations _emptyOperations() => parseHostelOperations({
  'residents': 0,
  'outside': 0,
  'onLeave': 0,
  'hostels': const [],
  'overdue': const [],
  'away': const [],
  'requests': const [],
});

Future<void> _pump(
  WidgetTester tester,
  HostelOperations operations,
  _FakeHostelRepository repository,
) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: HostelOpsDashboardScreen(
          operations: operations,
          repository: repository,
          onRefresh: () async {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows real counts from the operations board', (tester) async {
    await _pump(tester, _operations(), _FakeHostelRepository());

    expect(find.text('Boys Hostel'), findsOneWidget);
    expect(find.text('50'), findsOneWidget);
    expect(find.text('46'), findsOneWidget); // on campus = 50 - 4
    expect(find.text('Needs attention'), findsOneWidget);
    expect(find.text('Overdue returns'), findsOneWidget);
    expect(find.text('Maintenance complaints'), findsOneWidget);
    // Nothing without a data source is shown.
    expect(find.text('Available Beds'), findsNothing);
    expect(find.textContaining('Applications'), findsNothing);
    expect(find.text('2,843'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('overdue row lists the student with room and return time', (
    tester,
  ) async {
    await _pump(tester, _operations(), _FakeHostelRepository());

    await tester.tap(find.text('Overdue returns'));
    await tester.pumpAndSettle();

    expect(find.text('Arun K'), findsOneWidget);
    expect(find.textContaining('BH-101'), findsOneWidget);
    expect(find.textContaining('Due back'), findsOneWidget);
  });

  testWidgets('complaint queue resolves through the repository', (
    tester,
  ) async {
    final repository = _FakeHostelRepository();
    await _pump(tester, _operations(), repository);

    await tester.tap(find.text('Maintenance complaints'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Tap is leaking'), findsOneWidget);

    await tester.tap(find.text('Mark resolved'));
    await tester.pumpAndSettle();

    expect(repository.updates, [('c1', 'resolved')]);
    expect(find.text('No open complaints'), findsOneWidget);
  });

  testWidgets('empty board shows zeroes and empty queues', (tester) async {
    await _pump(tester, _emptyOperations(), _FakeHostelRepository());

    expect(find.text('All hostels'), findsOneWidget);
    await tester.tap(find.text('Room change requests'));
    await tester.pumpAndSettle();
    expect(find.text('No room change requests'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
