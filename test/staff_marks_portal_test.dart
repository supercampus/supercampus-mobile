import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/features/authentication/data/auth_repository.dart';
import 'package:supercampus_mobile/src/features/examination/presentation/examination_shell.dart';
import 'package:supercampus_mobile/src/features/examination/presentation/screens/marks_entry_screen.dart';

UserSession session(List<String> roles) => UserSession(
  email: 'staff@mec.local',
  displayName: 'MEC Staff',
  role: UserRole.staff,
  roleId: roles.first,
  roleIds: roles,
);

void main() {
  testWidgets('faculty receives templates, upload and advisor submission', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: MarksEntryScreen(session: session(['staff']))),
      ),
    );

    expect(find.text('Staff marks workspace'), findsOneWidget);
    expect(find.text('Assessment type'), findsOneWidget);
    expect(find.text('Marks out of'), findsOneWidget);
    expect(find.text('Excel (.xlsx)'), findsOneWidget);
    expect(find.text('CSV / Sheets'), findsOneWidget);
    expect(find.byKey(const ValueKey('upload-marks-file')), findsOneWidget);
    expect(find.text('Submit to class advisor'), findsOneWidget);
    expect(find.text('Class advisor'), findsOneWidget);
    expect(find.text('HOD'), findsOneWidget);
    expect(find.text('Principal'), findsOneWidget);
  });

  testWidgets('class advisor receives scoped approve and reject actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MarksEntryScreen(session: session(['staff', 'class_advisor'])),
        ),
      ),
    );

    expect(find.text('WITH ADVISOR'), findsOneWidget);
    expect(find.byKey(const ValueKey('approve-marks-batch')), findsOneWidget);
    expect(find.byKey(const ValueKey('reject-marks-batch')), findsOneWidget);
    expect(find.text('Submit to class advisor'), findsNothing);
    expect(find.text('Excel (.xlsx)'), findsOneWidget);
    expect(find.text('CSV / Sheets'), findsOneWidget);
  });

  for (final role in ['hod', 'principal']) {
    testWidgets('$role receives a dedicated marks review workspace', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: MarksEntryScreen(session: session([role]))),
        ),
      );

      expect(find.text('Staff marks workspace'), findsNothing);
      expect(find.byKey(const ValueKey('approve-marks-batch')), findsOneWidget);
      expect(find.byKey(const ValueKey('reject-marks-batch')), findsOneWidget);
      expect(find.text('Approval workflow'), findsOneWidget);
    });
  }

  testWidgets('academic staff enter examination directly at marks workflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ExaminationShell(session: session(['staff']), onSignOut: () {}),
      ),
    );

    expect(find.text('Staff marks workspace'), findsOneWidget);
    expect(find.text('Examination Cell Control Portal'), findsNothing);
    expect(find.text('Moderation'), findsNothing);
  });
}
