import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../authentication/data/auth_http_client.dart';
import '../../authentication/data/auth_repository.dart';
import '../../../core/students/student_year.dart';
import '../../academics/data/academic_models.dart';

final _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

enum ManagedStudentResidency { dayScholar, hosteller }

extension ManagedStudentResidencyWire on ManagedStudentResidency {
  String get apiValue =>
      this == ManagedStudentResidency.hosteller ? 'hosteller' : 'day_scholar';

  String get label =>
      this == ManagedStudentResidency.hosteller ? 'Hosteller' : 'Day scholar';
}

class ManagedStudent {
  const ManagedStudent({
    required this.id,
    required this.name,
    required this.rollNumber,
    required this.department,
    required this.residency,
    required this.mobileNumber,
    required this.email,
    required this.status,
    this.departmentId,
    this.sectionId,
    this.programmeId,
    this.guardianName = '',
    this.guardianPhone = '',
    this.guardianRelationship = '',
    this.yearOfStudy,
    this.section,
    this.photoUrl,
  });

  final String id;
  final String name;
  final String rollNumber;
  final String department;
  final ManagedStudentResidency residency;
  final String mobileNumber;
  final String email;
  final String status;
  final String? departmentId;
  final String? sectionId;

  /// The academic-catalog programme the student is enrolled in, if linked.
  final String? programmeId;
  final String guardianName;
  final String guardianPhone;
  final String guardianRelationship;
  final int? yearOfStudy;
  final String? section;
  final String? photoUrl;

  ManagedStudent copyWith({
    String? name,
    String? rollNumber,
    String? department,
    ManagedStudentResidency? residency,
    String? mobileNumber,
    String? email,
    String? status,
    String? departmentId,
    String? sectionId,
    String? programmeId,
    String? guardianName,
    String? guardianPhone,
    String? guardianRelationship,
    int? yearOfStudy,
    String? section,
    String? photoUrl,
  }) => ManagedStudent(
    id: id,
    name: name ?? this.name,
    rollNumber: rollNumber ?? this.rollNumber,
    department: department ?? this.department,
    residency: residency ?? this.residency,
    mobileNumber: mobileNumber ?? this.mobileNumber,
    email: email ?? this.email,
    status: status ?? this.status,
    departmentId: departmentId ?? this.departmentId,
    sectionId: sectionId ?? this.sectionId,
    programmeId: programmeId ?? this.programmeId,
    guardianName: guardianName ?? this.guardianName,
    guardianPhone: guardianPhone ?? this.guardianPhone,
    guardianRelationship: guardianRelationship ?? this.guardianRelationship,
    yearOfStudy: yearOfStudy ?? this.yearOfStudy,
    section: section ?? this.section,
    photoUrl: photoUrl ?? this.photoUrl,
  );
}

class ManagedUserRole {
  const ManagedUserRole({
    required this.id,
    required this.key,
    required this.name,
    this.active = true,
    this.assignable = true,
    this.permissionKeys = const [],
  });

  final String id;
  final String key;
  final String name;
  final bool active;

  /// What the role grants, e.g. `canteen.orders.manage`. Decides whether the
  /// role puts someone behind a shop counter; never the role's name.
  final List<String> permissionKeys;

  /// Whether the signed-in administrator may grant or remove this role. The
  /// server enforces it; the app only uses it to not offer the choice.
  final bool assignable;
}

/// Roles above a tenant administrator's authority: the platform's own and
/// the tenant super administrator. Used when a server does not say which
/// roles are assignable.
bool isPrivilegedRoleKey(String key) {
  final normalized = key.trim().toLowerCase();
  return normalized == 'superadmin' ||
      normalized == 'super_admin' ||
      normalized.startsWith('platform_');
}

class ManagedTenantUser {
  const ManagedTenantUser({
    required this.id,
    required this.name,
    required this.email,
    required this.roles,
    required this.active,
    this.yearOfStudy,
    this.department,
  });

  final String id;
  final String name;
  final String email;
  final List<ManagedUserRole> roles;
  final bool active;
  final int? yearOfStudy;
  final String? department;
}

/// One shop as offered when choosing someone's counters, with their role
/// there (null when they do not work it).
class ShopCounterChoice {
  const ShopCounterChoice({
    required this.shopKey,
    required this.name,
    required this.category,
    this.role,
    this.parentShopKey,
  });

  final String shopKey;
  final String name;
  final String category;

  /// The canteen this shop is a counter of, when it is one.
  final String? parentShopKey;

  /// `owner`, `captain` or null.
  final String? role;
}

/// Outcome of a bulk delete: the ids removed and the ids skipped, each with
/// a reason the server gives in plain words.
class BulkDeleteResult {
  const BulkDeleteResult({required this.deleted, required this.failed});

  factory BulkDeleteResult.fromJson(Object? value) {
    final map = value is Map ? value : const {};
    final deleted = (map['deleted'] as List? ?? const [])
        .map((id) => id.toString())
        .toList();
    final failed = <String, String>{
      for (final item in (map['failed'] as List? ?? const []).whereType<Map>())
        item['id'].toString(): item['reason']?.toString() ?? 'Not deleted',
    };
    return BulkDeleteResult(deleted: deleted, failed: failed);
  }

  final List<String> deleted;
  final Map<String, String> failed;
}

class AdminStudentRepository {
  AdminStudentRepository({
    required String baseUrl,
    required AccessTokenProvider accessTokenProvider,
    http.Client? client,
  }) : _baseUri = Uri.parse(baseUrl.replaceFirst(RegExp(r'/$'), '')),
       _accessTokenProvider = accessTokenProvider,
       _client = client ?? createAuthHttpClient();

  final Uri _baseUri;
  final AccessTokenProvider _accessTokenProvider;
  final http.Client _client;

  Future<List<ManagedStudent>> listStudents() async {
    final data = await _request(
      (headers) => _client.get(
        _baseUri.resolve('/api/v1/student-master'),
        headers: headers,
      ),
    );
    final values = data['data'];
    if (values is! List) return const [];
    return values.whereType<Map<String, dynamic>>().map(_student).toList();
  }

  /// The institution's academic catalog (departments, programmes and
  /// classes) that the student edit form picks from.
  Future<AcademicCatalog> loadAcademicCatalog() async {
    final body = await _request(
      (headers) => _client.get(
        _baseUri.resolve('/api/v1/academic-structure/catalog'),
        headers: headers,
      ),
    );
    final data = body['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('The server returned an invalid catalog.');
    }
    return AcademicCatalog.fromJson(data);
  }

  Future<void> setStudentPhoto(String studentId, String photoUrl) async {
    await _request(
      (headers) => _client.put(
        _baseUri.resolve(
          '/api/v1/student-master/${Uri.encodeComponent(studentId)}/photo',
        ),
        headers: {...headers, 'content-type': 'application/json'},
        body: jsonEncode({'photoUrl': photoUrl}),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> importStudentAccounts(
    List<Map<String, dynamic>> rows,
  ) async {
    final response = await _request(
      (headers) => _client.post(
        _baseUri.resolve('/api/v1/student-master/accounts/import'),
        headers: {...headers, 'content-type': 'application/json'},
        body: jsonEncode({'rows': rows}),
      ),
    );
    return ((response['data'] as Map<String, dynamic>)['results'] as List)
        .cast<Map<String, dynamic>>();
  }

  Future<List<ManagedTenantUser>> listUsers() async {
    final data = await _request(
      (headers) => _client.get(
        _baseUri.resolve('/api/v1/authorization/users'),
        headers: headers,
      ),
    );
    final values = data['data'];
    if (values is! List) return const [];
    return values.whereType<Map<String, dynamic>>().map(_user).toList();
  }

  /// Every active shop in the administrator's order, with [userId]'s role at
  /// each.
  Future<List<ShopCounterChoice>> loadShopCounters(String userId) async {
    final data = await _request(
      (headers) => _client.get(
        _baseUri.resolve(
          '/api/v1/operations/canteen/shops/assignments/${Uri.encodeComponent(userId)}',
        ),
        headers: headers,
      ),
    );
    final body = data['data'];
    final shops = body is Map ? body['shops'] : null;
    if (shops is! List) return const [];
    return [
      for (final shop in shops.whereType<Map>())
        ShopCounterChoice(
          shopKey: shop['shopKey']?.toString() ?? '',
          name: shop['name']?.toString() ?? 'Shop',
          category: shop['category']?.toString() ?? '',
          parentShopKey:
              (shop['parentShopKey']?.toString().trim().isEmpty ?? true)
              ? null
              : shop['parentShopKey'].toString().trim(),
          role: switch (shop['assignmentRole']) {
            'owner' => 'owner',
            'captain' => 'captain',
            _ => null,
          },
        ),
    ];
  }

  /// Replaces the counters [userId] works: shop key to `owner`/`captain`.
  Future<void> saveShopCounters(
    String userId,
    Map<String, String> rolesByShop,
  ) async {
    await _request(
      (headers) => _client.put(
        _baseUri.resolve(
          '/api/v1/operations/canteen/shops/assignments/${Uri.encodeComponent(userId)}',
        ),
        headers: {...headers, 'content-type': 'application/json'},
        body: jsonEncode({
          'assignments': [
            for (final entry in rolesByShop.entries)
              {'shopKey': entry.key, 'assignmentRole': entry.value},
          ],
        }),
      ),
    );
  }

  Future<List<ManagedUserRole>> listRoles() async {
    final data = await _request(
      (headers) => _client.get(
        _baseUri.resolve('/api/v1/authorization/roles'),
        headers: headers,
      ),
    );
    final values = data['data'];
    if (values is! List) return const [];
    return values
        .whereType<Map<String, dynamic>>()
        .map(_role)
        .where((role) => role.active)
        .toList();
  }

  Future<void> setUserRoles(String userId, List<String> roleIds) async {
    await _request(
      (headers) => _client.put(
        _baseUri.resolve(
          '/api/v1/authorization/users/${Uri.encodeComponent(userId)}/roles',
        ),
        headers: {...headers, 'content-type': 'application/json'},
        body: jsonEncode({'roleIds': roleIds}),
      ),
    );
  }

  /// Deactivates (signing the user out everywhere) or reactivates an account
  /// in this tenant.
  Future<void> setUserActive(String userId, {required bool active}) async {
    await _request(
      (headers) => _client.put(
        _baseUri.resolve(
          '/api/v1/authorization/users/${Uri.encodeComponent(userId)}/status',
        ),
        headers: {...headers, 'content-type': 'application/json'},
        body: jsonEncode({'active': active}),
      ),
    );
  }

  Future<void> setUserPassword(String userId, String password) async {
    await _request(
      (headers) => _client.put(
        _baseUri.resolve(
          '/api/v1/authorization/users/${Uri.encodeComponent(userId)}/password',
        ),
        headers: {...headers, 'content-type': 'application/json'},
        body: jsonEncode({'password': password}),
      ),
    );
  }

  Future<void> updateUser(
    String userId, {
    String? name,
    String? email,
  }) async {
    await _request(
      (headers) => _client.put(
        _baseUri.resolve(
          '/api/v1/authorization/users/${Uri.encodeComponent(userId)}',
        ),
        headers: {...headers, 'content-type': 'application/json'},
        body: jsonEncode({
          if (name != null) 'name': name.trim(),
          if (email != null) 'email': email.trim().toLowerCase(),
        }),
      ),
    );
  }

  /// Sets a student's year of study (1–6) on the account and the linked
  /// student record.
  Future<void> setUserYear(String userId, int yearOfStudy) async {
    if (yearOfStudy < 1 || yearOfStudy > 6) {
      throw ArgumentError.value(yearOfStudy, 'yearOfStudy', 'must be 1–6');
    }
    await _request(
      (headers) => _client.put(
        _baseUri.resolve(
          '/api/v1/authorization/users/${Uri.encodeComponent(userId)}/year',
        ),
        headers: {...headers, 'content-type': 'application/json'},
        body: jsonEncode({'yearOfStudy': yearOfStudy}),
      ),
    );
  }

  Future<void> createUser({
    required String name,
    required String email,
    required String password,
    required List<String> roleIds,
    int? yearOfStudy,
  }) async {
    await _request(
      (headers) => _client.post(
        _baseUri.resolve('/api/v1/authorization/users'),
        headers: {...headers, 'content-type': 'application/json'},
        body: jsonEncode({
          'name': name.trim(),
          'email': email.trim().toLowerCase(),
          'temporaryPassword': password,
          'roleIds': roleIds,
          if (yearOfStudy != null) 'yearOfStudy': yearOfStudy,
        }),
      ),
    );
  }

  /// Permanently deletes one user: membership, sign-in and contact details
  /// go; the history they left (ledgers, orders, attendance) stays.
  Future<void> deleteUser(String userId) async {
    await _request(
      (headers) => _client.delete(
        _baseUri.resolve(
          '/api/v1/authorization/users/${Uri.encodeComponent(userId)}',
        ),
        headers: headers,
      ),
    );
  }

  /// Permanently deletes several users. The server refuses the whole batch
  /// when it includes the caller or the last administrator; users it skips
  /// for other reasons come back in [BulkDeleteResult.failed].
  Future<BulkDeleteResult> deleteUsers(List<String> userIds) async {
    final response = await _request(
      (headers) => _client.post(
        _baseUri.resolve('/api/v1/authorization/users/bulk-delete'),
        headers: {...headers, 'content-type': 'application/json'},
        body: jsonEncode({'ids': userIds}),
      ),
    );
    return BulkDeleteResult.fromJson(response['data']);
  }

  Future<ManagedStudentResidency> setResidency(
    String studentId,
    ManagedStudentResidency residency,
  ) async {
    final data = await _request(
      (headers) => _client.put(
        _baseUri.resolve(
          '/api/v1/student-master/${Uri.encodeComponent(studentId)}/residency',
        ),
        headers: {...headers, 'content-type': 'application/json'},
        body: jsonEncode({'residency': residency.apiValue}),
      ),
    );
    final value = data['data'];
    return value is Map<String, dynamic> && value['residency'] == 'hosteller'
        ? ManagedStudentResidency.hosteller
        : ManagedStudentResidency.dayScholar;
  }

  Future<ManagedStudent> updateStudent(ManagedStudent student) async {
    final response = await _request(
      (headers) => _client.put(
        _baseUri.resolve(
          '/api/v1/student-master/${Uri.encodeComponent(student.id)}',
        ),
        headers: {...headers, 'content-type': 'application/json'},
        body: jsonEncode({
          'name': student.name.trim(),
          'rollNo': student.rollNumber.trim(),
          'department': student.department.trim(),
          'mobileNumber': student.mobileNumber.trim(),
          'email': student.email.trim().toLowerCase(),
          'status': student.status,
          'yearOfStudy': student.yearOfStudy,
          'section': student.section?.trim() ?? '',
          // Fallbacks only: the server resolves the chosen department and
          // section by name first. Legacy records can hold non-uuid ids,
          // which the server would refuse outright, so those are left out.
          if (student.departmentId case final departmentId?
              when _uuidPattern.hasMatch(departmentId))
            'departmentId': departmentId,
          if (student.sectionId case final sectionId?
              when _uuidPattern.hasMatch(sectionId))
            'sectionId': sectionId,
          if (student.programmeId case final programmeId?
              when _uuidPattern.hasMatch(programmeId))
            'programmeId': programmeId,
          'residency': student.residency.apiValue,
          if (student.guardianName.trim().isNotEmpty &&
              student.guardianPhone.trim().isNotEmpty) ...{
            'guardianName': student.guardianName.trim(),
            'guardianPhone': student.guardianPhone.trim(),
            'guardianRelationship': student.guardianRelationship.trim().isEmpty
                ? 'Parent'
                : student.guardianRelationship.trim(),
          },
        }),
      ),
    );
    final value = response['data'];
    if (value is! Map<String, dynamic>) {
      throw const FormatException('The server returned an invalid student.');
    }
    return _student(value);
  }

  ManagedStudent _student(Map<String, dynamic> value) => ManagedStudent(
    id: value['id']?.toString() ?? '',
    name: value['name']?.toString() ?? 'Student',
    rollNumber: value['rollNo']?.toString() ?? '',
    department: value['department']?.toString() ?? '',
    residency: value['residency'] == 'hosteller'
        ? ManagedStudentResidency.hosteller
        : ManagedStudentResidency.dayScholar,
    mobileNumber: value['mobileNumber']?.toString() ?? '',
    email: value['email']?.toString() ?? '',
    status: value['status']?.toString() ?? 'active',
    departmentId: value['departmentId']?.toString(),
    sectionId: value['sectionId']?.toString(),
    programmeId: value['programmeId']?.toString(),
    guardianName: value['guardianName']?.toString() ?? '',
    guardianPhone: value['guardianPhone']?.toString() ?? '',
    guardianRelationship: value['guardianRelationship']?.toString() ?? '',
    yearOfStudy: parseStudentYear(value['yearOfStudy'] ?? value['year']),
    section: value['section']?.toString(),
    photoUrl: value['photoUrl']?.toString(),
  );

  ManagedUserRole _role(Map<String, dynamic> value) {
    final key = value['key']?.toString() ?? '';
    return ManagedUserRole(
      id: value['id']?.toString() ?? '',
      key: key,
      name: value['name']?.toString() ?? 'Role',
      active: value['active'] != false,
      assignable: switch (value['assignable']) {
        final bool flag => flag,
        _ => !isPrivilegedRoleKey(key),
      },
      permissionKeys: [
        for (final permission in (value['permissions'] as List? ?? const []))
          if (permission is Map && permission['key'] != null)
            permission['key'].toString(),
      ],
    );
  }

  ManagedTenantUser _user(Map<String, dynamic> value) => ManagedTenantUser(
    id: value['id']?.toString() ?? '',
    name: value['name']?.toString() ?? 'User',
    email: value['email']?.toString() ?? '',
    active: value['active'] != false,
    yearOfStudy: parseStudentYear(value['yearOfStudy'] ?? value['year']),
    department: value['department']?.toString(),
    roles: (value['roles'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(_role)
        .toList(),
  );

  Future<Map<String, dynamic>> _request(
    Future<http.Response> Function(Map<String, String> headers) send,
  ) async {
    var token = await _accessTokenProvider();
    var response = await send({
      'authorization': 'Bearer $token',
      'x-client-surface': 'app',
      'accept': 'application/json',
    });
    if (response.statusCode == 401) {
      token = await _accessTokenProvider(forceRefresh: true);
      response = await send({
        'authorization': 'Bearer $token',
        'x-client-surface': 'app',
        'accept': 'application/json',
      });
    }
    final responseText = response.body.trim();
    Map<String, dynamic> body = const {};
    if (responseText.isNotEmpty) {
      try {
        final decoded = jsonDecode(responseText);
        if (decoded is Map<String, dynamic>) body = decoded;
      } on FormatException {
        if (response.statusCode >= 200 && response.statusCode < 300) {
          throw Exception('The server returned an invalid response.');
        }
      }
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = body['error'];
      final message = error is Map<String, dynamic>
          ? error['message']?.toString()
          : error?.toString();
      throw Exception(
        message ??
            (responseText.isNotEmpty
                ? responseText
                : 'Request failed (${response.statusCode})'),
      );
    }
    return body;
  }
}
