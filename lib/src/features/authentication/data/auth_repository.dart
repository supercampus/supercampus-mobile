class StudentSession {
  const StudentSession({required this.email, required this.displayName});

  final String email;
  final String displayName;
}

abstract interface class AuthRepository {
  Future<StudentSession> signIn({
    required String email,
    required String password,
  });

  Future<void> sendPasswordReset(String email);
}

class AuthenticationException implements Exception {
  const AuthenticationException(this.message);

  final String message;
}
