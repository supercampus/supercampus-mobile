import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supercampus_mobile/src/features/authentication/data/backend_auth_repository.dart';
import 'package:supercampus_mobile/src/features/authentication/presentation/login_screen.dart';

void main() {
  test('reset password sends the token and new password to the API', () async {
    late http.Request capturedRequest;
    final repository = BackendAuthRepository(
      baseUrl: 'https://api.supercampus.ai',
      client: MockClient((request) async {
        capturedRequest = request;
        return http.Response('{"message":"Password updated"}', 200);
      }),
    );

    await repository.resetPassword(
      token: 'one-time-token',
      password: 'Pass1234',
    );

    expect(capturedRequest.method, 'POST');
    expect(capturedRequest.url.path, '/api/auth/reset-password');
    expect(jsonDecode(capturedRequest.body), {
      'token': 'one-time-token',
      'password': 'Pass1234',
    });
  });

  testWidgets('new password form validates and submits matching passwords', (
    tester,
  ) async {
    String? submittedToken;
    String? submittedPassword;
    var returnedToLogin = false;

    await tester.pumpWidget(
      MaterialApp(
        home: PasswordResetCompletionScreen(
          token: 'one-time-token',
          onResetPassword: (token, password) async {
            submittedToken = token;
            submittedPassword = password;
          },
          onBackToLogin: () => returnedToLogin = true,
        ),
      ),
    );

    expect(find.text('Create new password'), findsOneWidget);
    expect(find.text('Confirm password'), findsOneWidget);

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'Pass1234',
    );
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'Pass1234',
    );
    await tester.tap(find.text('Create password'));
    await tester.pumpAndSettle();

    expect(submittedToken, 'one-time-token');
    expect(submittedPassword, 'Pass1234');
    expect(returnedToLogin, isTrue);
  });
}
