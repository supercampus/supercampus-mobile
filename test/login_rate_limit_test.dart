import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supercampus_mobile/src/features/authentication/data/auth_repository.dart';
import 'package:supercampus_mobile/src/features/authentication/data/login_attempt_limiter.dart';
import 'package:supercampus_mobile/src/features/authentication/presentation/login_screen.dart';

void main() {
  group('LoginAttemptLimiter', () {
    late DateTime now;
    late LoginAttemptLimiter limiter;

    setUp(() {
      now = DateTime(2026, 9, 26, 10);
      limiter = LoginAttemptLimiter(clock: () => now);
    });

    test('locks for 30 seconds on the third wrong password', () {
      expect(limiter.recordFailure(), isNull);
      expect(limiter.attemptsRemaining, 2);
      expect(limiter.recordFailure(), isNull);
      expect(limiter.attemptsRemaining, 1);
      expect(limiter.recordFailure(), const Duration(seconds: 30));
      expect(limiter.isLocked, isTrue);

      now = now.add(const Duration(seconds: 29));
      expect(limiter.isLocked, isTrue);
      now = now.add(const Duration(seconds: 1));
      expect(limiter.isLocked, isFalse);
    });

    test('doubles the lock for each further failure, capped at 15 minutes', () {
      expect(limiter.lockoutFor(3), const Duration(seconds: 30));
      expect(limiter.lockoutFor(4), const Duration(seconds: 60));
      expect(limiter.lockoutFor(5), const Duration(seconds: 120));
      expect(limiter.lockoutFor(40), const Duration(minutes: 15));

      for (var i = 0; i < 3; i++) {
        limiter.recordFailure();
      }
      now = now.add(const Duration(seconds: 30));
      expect(limiter.recordFailure(), const Duration(seconds: 60));
    });

    test('a successful sign-in clears the record', () {
      limiter
        ..recordFailure()
        ..recordFailure()
        ..recordSuccess();
      expect(limiter.attemptsRemaining, 3);
      expect(limiter.isLocked, isFalse);
    });

    test('failures older than the window are forgotten', () {
      limiter
        ..recordFailure()
        ..recordFailure();
      now = now.add(const Duration(minutes: 16));
      expect(limiter.attemptsRemaining, 3);
      expect(limiter.recordFailure(), isNull);
    });

    test('the lock survives a restart', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final first = LoginAttemptLimiter(
        clock: () => now,
        preferences: preferences,
      );
      for (var i = 0; i < 3; i++) {
        first.recordFailure();
      }

      final restarted = LoginAttemptLimiter(
        clock: () => now,
        preferences: preferences,
      );
      await restarted.restore();
      expect(restarted.isLocked, isTrue);
      expect(restarted.lockoutRemaining, const Duration(seconds: 30));
    });
  });

  group('LoginScreen lockout', () {
    late DateTime now;
    late _RejectingAuthRepository repository;
    late LoginAttemptLimiter limiter;

    setUp(() {
      now = DateTime(2026, 9, 26, 10);
      repository = _RejectingAuthRepository();
      limiter = LoginAttemptLimiter(clock: () => now);
    });

    Future<void> pumpLogin(WidgetTester tester) => tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(
          authRepository: repository,
          onSignedIn: (_) {},
          attemptLimiter: limiter,
        ),
      ),
    );

    Future<void> attempt(WidgetTester tester) async {
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'student@mec.local',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'wrongpass');
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      await tester.pump();
    }

    testWidgets('warns before locking, then locks for 30 seconds', (
      tester,
    ) async {
      await pumpLogin(tester);

      await attempt(tester);
      expect(find.textContaining('2 attempts left'), findsOneWidget);
      await attempt(tester);
      expect(find.textContaining('1 attempt left'), findsOneWidget);
      await attempt(tester);

      expect(repository.calls, 3);
      expect(find.textContaining('Too many incorrect attempts'), findsOneWidget);
      expect(find.text('Locked · 30 s'), findsOneWidget);
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);

      // Submitting from the keyboard is ignored while locked.
      await tester.enterText(find.byType(TextFormField).at(1), 'wrongpass');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(repository.calls, 3);

      now = now.add(const Duration(seconds: 10));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Locked · 20 s'), findsOneWidget);

      now = now.add(const Duration(seconds: 20));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Sign in'), findsOneWidget);
      expect(find.textContaining('Too many incorrect attempts'), findsNothing);
    });

    testWidgets('network errors do not count toward the lock', (tester) async {
      repository.failWith = const AuthenticationException(
        'Could not reach the server.',
      );
      await pumpLogin(tester);
      for (var i = 0; i < 4; i++) {
        await attempt(tester);
      }
      expect(limiter.isLocked, isFalse);
      expect(find.text('Sign in'), findsOneWidget);
    });
  });
}

class _RejectingAuthRepository implements AuthRepository {
  int calls = 0;
  AuthenticationException failWith = const AuthenticationException(
    'The email or password you entered is incorrect.',
    invalidCredentials: true,
  );

  @override
  Future<UserSession> signIn({
    required String email,
    required String password,
    required String tenantDomain,
    UserRole? roleHint,
  }) async {
    calls++;
    throw failWith;
  }

  @override
  Future<UserSession> refresh(UserSession session) async => session;

  @override
  Future<void> sendPasswordReset(String email) async {}
}
