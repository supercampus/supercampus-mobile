import 'auth_repository.dart';

class MockAuthRepository implements AuthRepository {
  @override
  Future<UserSession> signIn({
    required String email,
    required String password,
    required UserRole role,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 650));

    if (password.toLowerCase() == 'invalid1') {
      throw const AuthenticationException(
        'The email or password you entered is incorrect.',
      );
    }

    final namePart = email.split('@').first.replaceAll(RegExp(r'[._-]+'), ' ');
    var displayName = namePart
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');

    if (displayName.isEmpty || displayName.toLowerCase() == role.name) {
      displayName = role.defaultName;
    }

    final (idNumber, deptOrWard) = switch (role) {
      UserRole.student => ('2024-CS-042', 'Computer Science Dept'),
      UserRole.security => ('SEC-8092', 'Main Gate - North Entrance'),
      UserRole.parent => ('PAR-4410', 'Alex Johnson (CS Dept)'),
      UserRole.staff => ('FAC-1049', 'Dept of Computer Engineering'),
      UserRole.timetableAllocator => (
          'ALLOC-9012',
          'Academic Planning & Operations'
        ),
    };

    return UserSession(
      email: email,
      displayName: displayName,
      role: role,
      idNumber: idNumber,
      departmentOrWard: deptOrWard,
    );
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
  }
}
