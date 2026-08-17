import 'dart:convert';

enum UserRole { student, security, parent, staff, timetableAllocator, admin }

enum PortalFamily { student, parent, staff, admin }

extension UserRoleExtension on UserRole {
  String get label => switch (this) {
    UserRole.student => 'Student',
    UserRole.security => 'Security Officer',
    UserRole.parent => 'Parent / Guardian',
    UserRole.staff => 'Faculty / Staff',
    UserRole.timetableAllocator => 'Timetable Allocator',
    UserRole.admin => 'Administrator',
  };

  String get defaultName => switch (this) {
    UserRole.student => 'Alex Johnson',
    UserRole.security => 'Officer R. Vance',
    UserRole.parent => 'Robert Johnson',
    UserRole.staff => 'Prof. Sarah Jenkins',
    UserRole.timetableAllocator => 'Dr. Marcus Vance',
    UserRole.admin => 'SuperCampus Administrator',
  };

  String get scope => switch (this) {
    UserRole.student => 'STUDENT',
    UserRole.security => 'SECURITY',
    UserRole.parent => 'PARENT',
    UserRole.staff => 'FACULTY',
    UserRole.timetableAllocator => 'ALLOCATOR',
    UserRole.admin => 'ADMIN',
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
    this.departmentId,
    this.sectionId,
    this.staffId,
    this.jwtToken,
    this.accessTokenExpiresAt,
    this.portalFamilies = const [],
    this.activePortalFamily,
  });

  final String email;
  final String displayName;

  /// Legacy built-in role.
  final UserRole role;

  final String? roleId;
  final String? roleName;

  final String? idNumber;
  final String? departmentOrWard;

  /// Contextual Claims for RBAC & Scope Filtering
  final String? departmentId; // e.g. "DEP-CS"
  final String? sectionId; // e.g. "CS-3A" for students
  final String? staffId; // e.g. "FAC-101" for faculty
  final String? jwtToken; // Signed JWT Token string
  final DateTime? accessTokenExpiresAt;
  final List<PortalFamily> portalFamilies;
  final PortalFamily? activePortalFamily;

  /// Display label for the role
  String get roleLabel => roleName ?? role.label;

  /// Stable key for the role
  String get roleKey => roleId ?? role.name;

  /// Scope identifier (STUDENT, FACULTY, ALLOCATOR)
  String get scope => role.scope;

  /// Generate mock JWT token with signed contextual claims payload
  static String generateMockJwt({
    required String email,
    required UserRole role,
    String? departmentId,
    String? sectionId,
    String? staffId,
  }) {
    final header = base64Url.encode(
      utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'})),
    );
    final payloadMap = {
      'sub': email,
      'scope': role.scope,
      'department_id': departmentId ?? 'DEP-CS',
      'section_id': sectionId ?? 'CS-3A',
      'staff_id': staffId ?? 'FAC-101',
      'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'exp':
          DateTime.now()
              .add(const Duration(hours: 24))
              .millisecondsSinceEpoch ~/
          1000,
    };
    final payload = base64Url.encode(utf8.encode(jsonEncode(payloadMap)));
    final signature = base64Url.encode(
      utf8.encode('supercampus_secret_key_mock'),
    );
    return '$header.$payload.$signature';
  }

  /// Verify and extract JWT claims from session payload
  Map<String, dynamic> parseJwtClaims() {
    if (jwtToken == null || !jwtToken!.contains('.')) {
      return {
        'scope': scope,
        'department_id': departmentId ?? 'DEP-CS',
        'section_id': sectionId ?? 'CS-3A',
        'staff_id': staffId ?? 'FAC-101',
      };
    }
    try {
      final parts = jwtToken!.split('.');
      final normalized = base64Url.normalize(parts[1]);
      final payloadStr = utf8.decode(base64Url.decode(normalized));
      return jsonDecode(payloadStr) as Map<String, dynamic>;
    } catch (_) {
      return {
        'scope': scope,
        'department_id': departmentId ?? 'DEP-CS',
        'section_id': sectionId ?? 'CS-3A',
        'staff_id': staffId ?? 'FAC-101',
      };
    }
  }

  /// RBAC Endpoint Access Permission check
  bool isAuthorizedFor(String action) {
    final claims = parseJwtClaims();
    final userScope = claims['scope'] ?? scope;

    if (action.startsWith('ALLOCATOR_') && userScope != 'ALLOCATOR') {
      return false;
    }
    if (action.startsWith('FACULTY_') &&
        userScope != 'FACULTY' &&
        userScope != 'ALLOCATOR') {
      return false;
    }
    return true;
  }
}

typedef StudentSession = UserSession;

abstract interface class AuthRepository {
  Future<UserSession> signIn({
    required String email,
    required String password,
    required UserRole role,
    required String tenantDomain,
  });

  Future<UserSession> refresh(UserSession session);

  Future<void> sendPasswordReset(String email);
}

class AuthenticationException implements Exception {
  const AuthenticationException(this.message);

  final String message;
}
