import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/features/authentication/data/auth_repository.dart';
import 'package:supercampus_mobile/src/features/authentication/presentation/login_screen.dart';

void main() {
  testWidgets('login asks only for email and password', (tester) async {
    final repository = _RecordingAuthRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(authRepository: repository, onSignedIn: (_) {}),
      ),
    );

    expect(find.text('Tenant ID'), findsNothing);
    expect(find.text('Find your institution'), findsNothing);
    expect(find.text('Email address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'user@example.edu',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'password123');
    await tester.tap(find.text('Sign in'));
    await tester.pump();

    expect(repository.email, 'user@example.edu');
    expect(repository.tenantDomain, isEmpty);
    await tester.pump(const Duration(seconds: 2));
  });
}

class _RecordingAuthRepository implements AuthRepository {
  String? email;
  String? tenantDomain;

  @override
  Future<UserSession> signIn({
    required String email,
    required String password,
    required String tenantDomain,
    UserRole? roleHint,
  }) async {
    this.email = email;
    this.tenantDomain = tenantDomain;
    return UserSession(
      email: email,
      displayName: 'User',
      role: UserRole.student,
    );
  }

  @override
  Future<UserSession> refresh(UserSession session) async => session;

  @override
  Future<void> sendPasswordReset(String email) async {}
}
