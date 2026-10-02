import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supercampus_mobile/src/core/access/effective_permissions.dart';
import 'package:supercampus_mobile/src/core/theme/app_theme.dart';
import 'package:supercampus_mobile/src/core/widgets/sign_out_confirmation.dart';
import 'package:supercampus_mobile/src/features/authentication/data/auth_repository.dart';
import 'package:supercampus_mobile/src/features/modules/presentation/widgets/settings_page.dart';

const _session = UserSession(
  email: 'student@mec.local',
  displayName: 'Asha Kumar',
  role: UserRole.student,
  roleId: 'student',
  roleIds: ['student'],
);

Future<void> _openSettings(WidgetTester tester, VoidCallback onSignOut) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => SettingsPage(
                  session: _session,
                  permissions: const EffectivePermissions.empty(),
                  onOpenModule: (_) {},
                  onSignOut: onSignOut,
                  onThemeModeChanged: (_) {},
                  modules: const [],
                  moduleOrder: const [],
                ),
              ),
            ),
            child: const Text('open settings'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open settings'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Sign out is the last thing in Settings', (tester) async {
    await _openSettings(tester, () {});
    final signOut = find.byKey(const ValueKey('settings-sign-out'));
    await tester.scrollUntilVisible(signOut, 200);
    await tester.ensureVisible(signOut);
    await tester.pumpAndSettle();
    final contact = find.text('Contact & Support');
    expect(
      tester.getTopLeft(signOut).dy,
      greaterThan(tester.getTopLeft(contact).dy),
    );
  });

  testWidgets('Cancel keeps you signed in; Sign out signs out', (
    tester,
  ) async {
    var signedOut = 0;
    await _openSettings(tester, () => signedOut++);
    final signOut = find.byKey(const ValueKey('settings-sign-out'));
    await tester.scrollUntilVisible(signOut, 200);
    await tester.ensureVisible(signOut);
    await tester.pumpAndSettle();

    await tester.tap(signOut);
    await tester.pumpAndSettle();
    expect(find.byType(SignOutConfirmationCard), findsOneWidget);
    expect(find.text('Sign out?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('sign-out-cancel')));
    await tester.pumpAndSettle();
    expect(find.byType(SignOutConfirmationCard), findsNothing);
    expect(signedOut, 0);
    expect(find.byType(SettingsPage), findsOneWidget);

    await tester.tap(signOut);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sign-out-confirm')));
    await tester.pumpAndSettle();
    expect(signedOut, 1);
    expect(find.byType(SettingsPage), findsNothing);
  });

  testWidgets('the two buttons sit side by side at the same size', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => confirmSignOut(context),
            child: const Text('go'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    final cancel = tester.getRect(find.byKey(const ValueKey('sign-out-cancel')));
    final confirm = tester.getRect(
      find.byKey(const ValueKey('sign-out-confirm')),
    );
    expect(cancel.top, confirm.top);
    expect(cancel.size, confirm.size);
    expect(cancel.right, lessThan(confirm.left));
  });
}
