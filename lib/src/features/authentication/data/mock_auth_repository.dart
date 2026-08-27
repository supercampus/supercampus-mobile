import 'auth_repository.dart';

class MockAuthRepository implements AuthRepository {
  @override
  Future<UserSession> refresh(UserSession session) async => session;

  @override
  Future<UserSession> signIn({
    required String email,
    required String password,
    required String tenantDomain,
    UserRole? roleHint,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 650));

    // With no server to ask, the address stands in for access control, so every
    // persona is reachable without editing code: principal@, advisor@, staff@,
    // parent@, security@, allocator@, admin@ — anything else is a student.
    final role = roleHint ?? _personaFromEmail(email);

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

    if (role == UserRole.student) {
      displayName = 'Vishnu Sudharshan';
    } else if (displayName.isEmpty || displayName.toLowerCase() == role.name) {
      displayName = role.defaultName;
    }

    final (idNumber, deptOrWard) = switch (role) {
      UserRole.student => ('2024-CS-042', 'Computer Science Dept'),
      UserRole.security => ('SEC-8092', 'Main Gate - North Entrance'),
      UserRole.parent => ('PAR-4410', 'Alex Johnson (CS Dept)'),
      UserRole.staff => ('FAC-1049', 'Dept of Computer Engineering'),
      UserRole.timetableAllocator => (
        'ALLOC-9012',
        'Academic Planning & Operations',
      ),
      UserRole.admin => ('ADMIN-0001', 'SuperCampus Administration'),
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

/// Which persona a mock address stands for. Real sign-in never uses this — the
/// server resolves the role from the account's roles and portal family.
UserRole _personaFromEmail(String email) {
  final local = email.split('@').first.toLowerCase();
  if (local.contains('admin')) return UserRole.admin;
  if (local.contains('allocator') || local.contains('timetable')) {
    return UserRole.timetableAllocator;
  }
  if (local.contains('security') || local.contains('guard')) {
    return UserRole.security;
  }
  if (local.contains('parent') || local.contains('guardian')) {
    return UserRole.parent;
  }
  // Principal, HOD, class advisor and faculty are all staff personas here —
  // what separates them is grants, which the mock permissions repository
  // supplies, not the role name.
  if (local.contains('principal') ||
      local.contains('hod') ||
      local.contains('advisor') ||
      local.contains('faculty') ||
      local.contains('staff') ||
      local.contains('teacher')) {
    return UserRole.staff;
  }
  return UserRole.student;
}
