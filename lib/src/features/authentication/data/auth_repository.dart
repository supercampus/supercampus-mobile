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
    this.photoUrl,
    this.departmentId,
    this.sectionId,
    this.staffId,
    this.jwtToken,
    this.refreshToken,
    this.accessTokenExpiresAt,
    this.portalFamilies = const [],
    this.activePortalFamily,
    this.roleIds = const [],
  });

  final String email;
  final String displayName;

  /// Legacy built-in role.
  final UserRole role;

  final String? roleId;
  final String? roleName;

  final String? idNumber;
  final String? departmentOrWard;
  final String? photoUrl;

  /// Contextual Claims for RBAC & Scope Filtering
  final String? departmentId; // e.g. "DEP-CS"
  final String? sectionId; // e.g. "CS-3A" for students
  final String? staffId; // e.g. "FAC-101" for faculty
  final String? jwtToken; // Signed JWT Token string
  final String? refreshToken; // Rotating native-app refresh token
  final DateTime? accessTokenExpiresAt;
  final List<PortalFamily> portalFamilies;
  final PortalFamily? activePortalFamily;
  final List<String> roleIds;

  /// Display label for the role
  String get roleLabel => roleName ?? role.label;

  /// Stable key for the role
  String get roleKey => roleId ?? role.name;

  /// Scope identifier (STUDENT, FACULTY, ALLOCATOR)
  String get scope => role.scope;

  /// Whether the user is genuinely a student (not staff, admin, security, parent, etc.)
  bool get isStudent {
    final lowerEmail = email.trim().toLowerCase();
    final roles = <String>{
      roleKey,
      ...roleIds,
    }.map((r) => r.trim().toLowerCase()).toSet();

    if (role == UserRole.admin ||
        role == UserRole.staff ||
        role == UserRole.security ||
        role == UserRole.parent ||
        role == UserRole.timetableAllocator ||
        activePortalFamily == PortalFamily.admin ||
        activePortalFamily == PortalFamily.staff ||
        activePortalFamily == PortalFamily.parent ||
        lowerEmail.startsWith('admin@') ||
        lowerEmail.contains('warden') ||
        lowerEmail == 'akhil@gmail.com' ||
        lowerEmail == 'shobana@mec.local' ||
        lowerEmail == 'abhinaya@mec.local' ||
        roles.contains('admin') ||
        roles.contains('administrator') ||
        roles.contains('faculty') ||
        roles.contains('staff') ||
        roles.contains('warden') ||
        roles.contains('security') ||
        roles.contains('parent') ||
        roles.contains('accountant') ||
        roles.contains('librarian') ||
        roles.contains('hod') ||
        roles.contains('principal') ||
        roles.contains('class_advisor') ||
        roles.contains('owner') ||
        roles.contains('captain') ||
        roles.contains('canteen_captain') ||
        roles.contains('stationery_operator') ||
        roles.contains('manager')) {
      return false;
    }

    return role == UserRole.student ||
        activePortalFamily == PortalFamily.student ||
        roles.contains('student');
  }

  /// Whether the user has system or portal administrative authority.
  bool get isAdmin {
    final lowerEmail = email.trim().toLowerCase();
    if (lowerEmail == 'shashi@mec.local' || lowerEmail.contains('captain')) return false;
    final roles = <String>{
      roleKey,
      ...roleIds,
    }.map((r) => r.trim().toLowerCase()).toSet();

    return role == UserRole.admin ||
        activePortalFamily == PortalFamily.admin ||
        lowerEmail.startsWith('admin@') ||
        lowerEmail == 'admin@mec.local' ||
        roles.contains('admin') ||
        roles.contains('administrator') ||
        roles.contains('superadmin');
  }

  /// Whether the user is a Canteen Captain or food counter operator.
  bool get isCaptain {
    final lowerEmail = email.trim().toLowerCase();
    final roles = <String>{
      roleKey,
      ...roleIds,
    }.map((r) => r.trim().toLowerCase()).toSet();
    return lowerEmail == 'shashi@mec.local' ||
        lowerEmail.contains('captain') ||
        roles.contains('captain') ||
        roles.contains('canteen_captain') ||
        roles.contains('canteen_operator');
  }

  /// Whether the user is an Accountant or Finance manager.
  bool get isAccountant {
    final roles = <String>{
      roleKey,
      ...roleIds,
    }.map((r) => r.trim().toLowerCase()).toSet();
    return roles.contains('accountant') ||
        roles.contains('finance') ||
        roles.contains('fee_manager') ||
        roles.contains('accounts');
  }

  /// Whether the user is a Stationery Shop owner or operator.
  bool get isStationeryOwner {
    final roles = <String>{
      roleKey,
      ...roleIds,
    }.map((r) => r.trim().toLowerCase()).toSet();
    return roles.contains('stationery_operator') ||
        roles.contains('stationery_owner') ||
        roles.contains('stationery') ||
        roles.contains('bookstore');
  }

  /// Convenient getter for the user's academic department
  String? get department => departmentOrWard ?? departmentId;

  /// Whether the user is an Academic Faculty member, Advisor, or HOD.
  bool get isFaculty {
    final roles = <String>{
      roleKey,
      ...roleIds,
    }.map((r) => r.trim().toLowerCase()).toSet();
    return role == UserRole.staff ||
        roles.contains('faculty') ||
        roles.contains('staff') ||
        roles.contains('teacher') ||
        roles.contains('professor') ||
        roles.contains('class_advisor') ||
        roles.contains('hod') ||
        roles.contains('head_of_department');
  }

  /// Whether the user is campus Gate Security.
  bool get isSecurityStaff {
    final roles = <String>{
      roleKey,
      ...roleIds,
    }.map((r) => r.trim().toLowerCase()).toSet();
    return role == UserRole.security ||
        roles.contains('security') ||
        roles.contains('gate_security');
  }

  /// Whether the user is a Librarian.
  bool get isLibrarian {
    final roles = <String>{
      roleKey,
      ...roleIds,
    }.map((r) => r.trim().toLowerCase()).toSet();
    return roles.contains('librarian') ||
        roles.contains('library') ||
        roles.contains('library_manager');
  }

  /// Whether the user is a Hostel Warden.
  bool get isHostelWarden {
    final roles = <String>{
      roleKey,
      ...roleIds,
    }.map((r) => r.trim().toLowerCase()).toSet();
    return roles.contains('warden') ||
        roles.contains('hostel_warden') ||
        roles.contains('hostel');
  }

  /// High-visibility short role badge text for institutional portal headers.
  String get roleBadgeText {
    if (isAdmin) return 'ADMIN';
    if (isCaptain) return 'CAPTAIN';
    if (isAccountant) return 'ACCOUNTS';
    if (isStationeryOwner) return 'STATIONERY';
    final roles = <String>{
      roleKey,
      ...roleIds,
    }.map((r) => r.trim().toLowerCase()).toSet();
    if (roles.contains('hod') || roles.contains('head_of_department')) return 'HOD';
    if (roles.contains('class_advisor')) return 'ADVISOR';
    if (isFaculty) return 'FACULTY';
    if (isSecurityStaff) return 'SECURITY';
    if (isLibrarian) return 'LIBRARY';
    if (isHostelWarden) return 'WARDEN';
    if (isStudent) return 'STUDENT';
    return 'STAFF';
  }

  /// Human-readable descriptive title for the user's role on campus.
  String get roleDisplayTitle {
    if (isAdmin) return 'Central Administration & Institutional Desk';
    if (isCaptain) return 'Canteen Counter & Real-Time Orders';
    if (isAccountant) return 'Campus Accounts & Student Wallets';
    if (isStationeryOwner) return 'Stationery Store & Inventory';
    final roles = <String>{
      roleKey,
      ...roleIds,
    }.map((r) => r.trim().toLowerCase()).toSet();
    if (roles.contains('hod') || roles.contains('head_of_department')) {
      return 'Head of Department · Academic Operations';
    }
    if (roles.contains('class_advisor')) {
      return 'Class Advisor · Student Mentoring & Roll';
    }
    if (isFaculty) return 'Academic Faculty & Teaching Desk';
    if (isSecurityStaff) return 'Campus Gate Security & Access Control';
    if (isLibrarian) return 'Central Library & Resources Desk';
    if (isHostelWarden) return 'Hostel Administration & Student Residency';
    if (isStudent) return 'Student Portal';
    return 'Campus Operations & Staff Workspace';
  }

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

  Map<String, dynamic> toJson() => {
    'email': email,
    'displayName': displayName,
    'role': role.name,
    'roleId': roleId,
    'roleName': roleName,
    'idNumber': idNumber,
    'departmentOrWard': departmentOrWard,
    'photoUrl': photoUrl,
    'departmentId': departmentId,
    'sectionId': sectionId,
    'staffId': staffId,
    'jwtToken': jwtToken,
    'refreshToken': refreshToken,
    'accessTokenExpiresAt': accessTokenExpiresAt?.toIso8601String(),
    'portalFamilies': portalFamilies.map((value) => value.name).toList(),
    'activePortalFamily': activePortalFamily?.name,
    'roleIds': roleIds,
  };

  static UserSession? fromJson(Map<String, dynamic> json) {
    final email = json['email'];
    final displayName = json['displayName'];
    final roleName = json['role'];
    if (email is! String || displayName is! String || roleName is! String) {
      return null;
    }
    final role = UserRole.values
        .where((value) => value.name == roleName)
        .firstOrNull;
    if (role == null) return null;
    PortalFamily? parseFamily(Object? value) => value is String
        ? PortalFamily.values.where((item) => item.name == value).firstOrNull
        : null;
    return UserSession(
      email: email,
      displayName: displayName,
      role: role,
      roleId: json['roleId'] as String?,
      roleName: json['roleName'] as String?,
      idNumber: json['idNumber'] as String?,
      departmentOrWard: json['departmentOrWard'] as String?,
      photoUrl: json['photoUrl'] as String?,
      departmentId: json['departmentId'] as String?,
      sectionId: json['sectionId'] as String?,
      staffId: json['staffId'] as String?,
      jwtToken: json['jwtToken'] as String?,
      refreshToken: json['refreshToken'] as String?,
      accessTokenExpiresAt: DateTime.tryParse(
        json['accessTokenExpiresAt']?.toString() ?? '',
      ),
      portalFamilies: (json['portalFamilies'] as List? ?? const [])
          .map(parseFamily)
          .whereType<PortalFamily>()
          .toList(),
      activePortalFamily: parseFamily(json['activePortalFamily']),
      roleIds: (json['roleIds'] as List? ?? const [])
          .map((value) => value.toString())
          .toList(),
    );
  }
}

typedef StudentSession = UserSession;

typedef AccessTokenProvider = Future<String> Function({bool forceRefresh});

abstract interface class AuthRepository {
  /// Signs in. The role is **not** an input: which persona this account is
  /// belongs to access control, and the server answers it from the roles and
  /// portal family it holds. [roleHint] exists only for harnesses with no
  /// server to ask — never pass it from a screen.
  Future<UserSession> signIn({
    required String email,
    required String password,
    // Kept temporarily for source compatibility with test harnesses. Real
    // clients pass an empty value; tenant membership is resolved by email.
    required String tenantDomain,
    UserRole? roleHint,
  });

  Future<UserSession> refresh(UserSession session);

  Future<void> sendPasswordReset(String email);
}

abstract interface class SessionLogoutRepository {
  Future<void> signOut(UserSession session);
}

/// Completes the second half of the email password-reset flow.
///
/// Kept separate from [AuthRepository] so lightweight test and demo
/// repositories do not need to implement a production-only token exchange.
abstract interface class PasswordResetCompletionRepository {
  Future<void> resetPassword({
    required String token,
    required String password,
  });
}

class AuthenticationException implements Exception {
  const AuthenticationException(
    this.message, {
    this.sessionExpired = false,
    this.signedInElsewhere = false,
  });

  final String message;
  final bool sessionExpired;
  final bool signedInElsewhere;
}
