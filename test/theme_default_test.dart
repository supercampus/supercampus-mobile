import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supercampus_mobile/src/app.dart';
import 'package:supercampus_mobile/src/core/access/effective_permissions.dart';
import 'package:supercampus_mobile/src/core/access/permissions_repository.dart';
import 'package:supercampus_mobile/src/features/authentication/data/auth_repository.dart';
import 'package:supercampus_mobile/src/features/authentication/data/mock_auth_repository.dart';

void main() {
  testWidgets('a new account starts in light mode on a dark device', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.binding.platformDispatcher.platformBrightnessTestValue =
        Brightness.dark;
    addTearDown(
      tester.binding.platformDispatcher.clearPlatformBrightnessTestValue,
    );

    await tester.pumpWidget(
      SupercampusApp(
        authRepository: MockAuthRepository(),
        permissionsRepository: const _ImmediatePermissionsRepository(),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('institution-domain')),
      'mec',
    );
    final continueButton = find.byKey(
      const ValueKey('continue-from-institution'),
    );
    await tester.ensureVisible(continueButton);
    await tester.pumpAndSettle();
    await tester.tap(continueButton);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'student@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'password123');
    await tester.tap(find.text('Sign in'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 1700));

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.light);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _ImmediatePermissionsRepository implements PermissionsRepository {
  const _ImmediatePermissionsRepository();

  @override
  Future<EffectivePermissions> loadFor(UserSession session) async =>
      const EffectivePermissions.empty();
}
