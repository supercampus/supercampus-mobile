enum UserRole { student, security, parent, staff, timetableAllocator }

extension UserRoleExtension on UserRole {
  String get label => switch (this) {
        UserRole.student => 'Student',
        UserRole.security => 'Security Officer',
        UserRole.parent => 'Parent / Guardian',
        UserRole.staff => 'Faculty / Staff',
        UserRole.timetableAllocator => 'Timetable Allocator',
      };

  String get defaultEmail => switch (this) {
        UserRole.student => 'student@supercampus.edu',
        UserRole.security => 'security@supercampus.edu',
        UserRole.parent => 'parent@supercampus.edu',
        UserRole.staff => 'faculty@supercampus.edu',
        UserRole.timetableAllocator => 'allocator@supercampus.edu',
      };

  String get defaultName => switch (this) {
        UserRole.student => 'Alex Johnson',
        UserRole.security => 'Officer R. Vance',
        UserRole.parent => 'Robert Johnson',
        UserRole.staff => 'Prof. Sarah Jenkins',
        UserRole.timetableAllocator => 'Dr. Marcus Vance',
      };
}

class UserSession {
  const UserSession({
    required this.email,
    required this.displayName,
    required this.role,
    this.idNumber,
    this.departmentOrWard,
  });

  final String email;
  final String displayName;
  final UserRole role;
  final String? idNumber;
  final String? departmentOrWard;
}

typedef StudentSession = UserSession;

abstract interface class AuthRepository {
  Future<UserSession> signIn({
    required String email,
    required String password,
    required UserRole role,
  });

  Future<void> sendPasswordReset(String email);
}

class AuthenticationException implements Exception {
  const AuthenticationException(this.message);

  final String message;
}
