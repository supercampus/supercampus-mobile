import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/core/theme/app_theme.dart';
import 'package:supercampus_mobile/src/features/hostel/data/mock_hostel_repository.dart';
import 'package:supercampus_mobile/src/features/hostel/presentation/hostel_student_home_screen.dart';

void main() {
  Future<void> pumpHostelHome(
    WidgetTester tester, {
    required ThemeData theme,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final storeFuture = MockHostelRepository(
      studentName: 'Vishnu S',
      studentCode: 'MEC25AD48',
    ).loadStore();
    await tester.pump(const Duration(milliseconds: 200));
    final store = await storeFuture;

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: HostelStudentHomeScreen(
            store: store,
            onApplyAccommodation: () {},
            onOpenOutpass: () {},
            onOpenMess: () {},
            onOpenComplaints: () {},
            onOpenRoomChange: () {},
            onOpenVisitors: () {},
            onOpenVacateClearance: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows a compact student-first hostel dashboard', (tester) async {
    await pumpHostelHome(tester, theme: AppTheme.light);

    expect(find.text('Room B-204'), findsOneWidget);
    expect(find.text('Inside Hostel'), findsOneWidget);
    expect(find.text('Services'), findsOneWidget);
    expect(find.text('Leave & outpass'), findsOneWidget);
    expect(find.text('Mess & meals'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders the hostel dashboard in dark theme without overflow', (
    tester,
  ) async {
    await pumpHostelHome(tester, theme: AppTheme.dark);

    expect(find.text('Room B-204'), findsOneWidget);
    expect(find.byType(HostelStudentHomeScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
