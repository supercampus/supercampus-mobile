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
    this.roleId,
    this.roleName,
    this.idNumber,
    this.departmentOrWard,
  });

  final String email;
  final String displayName;

  /// Legacy built-in role. Retained only for the screens that still branch on
  /// it; new code must ask [EffectivePermissions] what the user can do rather
  /// than what they are.
  final UserRole role;

  /// Identity of an admin-authored role, as created in the access-control
  /// console. Free-form by design — "Hostel Warden" or "HOD - Mechanical"
  /// need no code change to exist.
  final String? roleId;
  final String? roleName;

  final String? idNumber;
  final String? departmentOrWard;

  /// Display label for the role, preferring what the admin named it.
  String get roleLabel => roleName ?? role.label;

  /// Stable key for the role, preferring the console's id.
  String get roleKey => roleId ?? role.name;
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
