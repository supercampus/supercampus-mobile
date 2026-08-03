import 'auth_repository.dart';

class MockAuthRepository implements AuthRepository {
  @override
  Future<StudentSession> signIn({
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 850));

    if (password.toLowerCase() == 'invalid1') {
      throw const AuthenticationException(
        'The email or password you entered is incorrect.',
      );
    }

    final namePart = email.split('@').first.replaceAll(RegExp(r'[._-]+'), ' ');
    final displayName = namePart
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');

    return StudentSession(
      email: email,
      displayName: displayName.isEmpty ? 'Student' : displayName,
    );
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
  }
}
