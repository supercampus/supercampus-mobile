import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/features/authentication/data/auth_repository.dart';
import 'package:supercampus_mobile/src/features/authentication/presentation/login_screen.dart';

void main() {
  testWidgets('login screen and reset password screen use Brittany and Poppins fonts', (
    tester,
  ) async {
    final repository = _MockAuthRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(
          authRepository: repository,
          onSignedIn: (_) {},
        ),
      ),
    );

    // Verify Login Screen branding with Brittany and Poppins
    final brandTitle = tester.widget<Text>(find.text('SuperCampus'));
    expect(brandTitle.style?.fontFamily, 'Brittany');

    final subtitle = tester.widget<Text>(
      find.text('login to your account issued by your instituition'),
    );
    expect(subtitle.style?.fontFamily, 'Poppins');

    final emailLabel = tester.widget<Text>(find.text('Email address'));
    expect(emailLabel.style?.fontFamily, 'Poppins');

    final passwordLabel = tester.widget<Text>(find.text('Password'));
    expect(passwordLabel.style?.fontFamily, 'Poppins');

    final signInButton = tester.widget<Text>(find.text('Sign in'));
    expect(signInButton.style?.fontFamily, 'Poppins');

    // Tap Forgot password? to transition to reset view
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();

    // Verify Reset Password Screen typography and elements
    expect(find.text('Reset your password'), findsOneWidget);
    final resetTitle = tester.widget<Text>(find.text('Reset your password'));
    expect(resetTitle.style?.fontFamily, 'Poppins');

    final resetSubtitle = tester.widget<Text>(
      find.text(
        'Enter your registered email address. We will send instructions to regain access.',
      ),
    );
    expect(resetSubtitle.style?.fontFamily, 'Poppins');

    final sendResetButton = tester.widget<Text>(find.text('Send reset link'));
    expect(sendResetButton.style?.fontFamily, 'Poppins');

    // Verify circular back button with chevron_left_rounded
    expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);

    // Tap back button to return to login screen
    await tester.tap(find.byIcon(Icons.chevron_left_rounded));
    await tester.pumpAndSettle();

    // Verify back on login screen
    expect(find.text('SuperCampus'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });
}

class _MockAuthRepository implements AuthRepository {
  String? resetEmailSent;

  @override
  Future<UserSession> signIn({
    required String email,
    required String password,
    required String tenantDomain,
    UserRole? roleHint,
  }) async {
    return UserSession(
      email: email,
      displayName: 'Test User',
      role: UserRole.student,
    );
  }

  @override
  Future<UserSession> refresh(UserSession session) async => session;

  @override
  Future<void> sendPasswordReset(String email) async {
    resetEmailSent = email;
  }
}
