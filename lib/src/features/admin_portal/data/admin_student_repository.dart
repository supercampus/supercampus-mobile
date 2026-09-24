import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../authentication/data/auth_http_client.dart';
import '../../authentication/data/auth_repository.dart';
import '../../../core/students/student_year.dart';

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
  });

  final String id;
  final String key;
  final String name;
  final bool active;
}

class ManagedTenantUser {
  const ManagedTenantUser({
    required this.id,
    required this.name,
    required this.email,
    required this.roles,
    required this.active,
    this.yearOfStudy,
  });

  final String id;
  final String name;
  final String email;
  final List<ManagedUserRole> roles;
  final bool active;
  final int? yearOfStudy;
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


  Future<void> createUser({
    required String name,
    required String email,
    required String password,
    required List<String> roleIds,
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
        }),
      ),
    );
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
          if (student.departmentId case final departmentId?)
            'departmentId': departmentId,
          'mobileNumber': student.mobileNumber.trim(),
          'email': student.email.trim().toLowerCase(),
          'status': student.status,
          'yearOfStudy': student.yearOfStudy,
          'section': student.section?.trim() ?? '',
          if (student.sectionId case final sectionId?) 'sectionId': sectionId,
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
    guardianName: value['guardianName']?.toString() ?? '',
    guardianPhone: value['guardianPhone']?.toString() ?? '',
    guardianRelationship: value['guardianRelationship']?.toString() ?? '',
    yearOfStudy: parseStudentYear(value['yearOfStudy'] ?? value['year']),
    section: value['section']?.toString(),
    photoUrl: value['photoUrl']?.toString(),
  );

  ManagedUserRole _role(Map<String, dynamic> value) => ManagedUserRole(
    id: value['id']?.toString() ?? '',
    key: value['key']?.toString() ?? '',
    name: value['name']?.toString() ?? 'Role',
    active: value['active'] != false,
  );

  ManagedTenantUser _user(Map<String, dynamic> value) => ManagedTenantUser(
    id: value['id']?.toString() ?? '',
    name: value['name']?.toString() ?? 'User',
    email: value['email']?.toString() ?? '',
    active: value['active'] != false,
    yearOfStudy: parseStudentYear(value['yearOfStudy'] ?? value['year']),
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
