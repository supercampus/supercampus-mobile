import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/core/access/effective_permissions.dart';
import 'package:supercampus_mobile/src/features/authentication/data/auth_repository.dart';
import 'package:supercampus_mobile/src/features/modules/presentation/widgets/home_sheets.dart';

void main() {
  const session = UserSession(
    email: 'abinaya2006sathya@gmail.com',
    displayName: 'Abinaya S',
    role: UserRole.student,
    idNumber: 'MEC25AD01',
    departmentOrWard: 'AIDS',
    photoUrl: 'https://res.cloudinary.com/demo/image/upload/abinaya.jpg',
  );

  testWidgets('profile card and digital ID use the authenticated photo', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileSheet(
            session: session,
            permissions: const EffectivePermissions.empty(),
            onOpenModule: (_) {},
            onSignOut: () {},
            onThemeModeChanged: (_) {},
          ),
        ),
      ),
    );

    final profilePhoto = find.byKey(const ValueKey('profile-card-photo'));
    expect(profilePhoto, findsOneWidget);
    expect(
      find.descendant(of: profilePhoto, matching: find.byType(Image)),
      findsOneWidget,
    );

    await tester.tap(find.text('Details'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Digital ID card'));
    await tester.pumpAndSettle();

    final digitalIdPhoto = find.byKey(const ValueKey('digital-id-photo'));
    expect(digitalIdPhoto, findsOneWidget);
    expect(
      find.descendant(of: digitalIdPhoto, matching: find.byType(Image)),
      findsOneWidget,
    );
    expect(find.text('Abinaya S'), findsWidgets);
    expect(find.text('MEC25AD01'), findsWidgets);
  });
}
