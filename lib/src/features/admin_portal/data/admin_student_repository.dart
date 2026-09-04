import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../authentication/data/auth_http_client.dart';
import '../../authentication/data/auth_repository.dart';

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
    this.photoUrl,
  });

  final String id;
  final String name;
  final String rollNumber;
  final String department;
  final ManagedStudentResidency residency;
  final String? photoUrl;
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

  ManagedStudent _student(Map<String, dynamic> value) => ManagedStudent(
    id: value['id']?.toString() ?? '',
    name: value['name']?.toString() ?? 'Student',
    rollNumber: value['rollNo']?.toString() ?? '',
    department: value['department']?.toString() ?? '',
    residency: value['residency'] == 'hosteller'
        ? ManagedStudentResidency.hosteller
        : ManagedStudentResidency.dayScholar,
    photoUrl: value['photoUrl']?.toString(),
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
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(body['error']?.toString() ?? 'Request failed');
    }
    return body;
  }
}
