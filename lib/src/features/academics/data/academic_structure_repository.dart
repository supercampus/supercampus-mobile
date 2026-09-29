import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../authentication/data/auth_http_client.dart';
import '../../authentication/data/auth_repository.dart';
import 'academic_models.dart';

/// Reads and edits the institution's departments, programmes, classes and
/// subjects. The server decides what the signed-in person may change and
/// says so in [AcademicCatalog.access].
abstract class AcademicStructureRepository {
  Future<AcademicCatalog> loadCatalog({bool includeInactive = false});

  Future<void> createDepartment({required String code, required String name});

  Future<void> updateDepartment(
    String id, {
    required String code,
    required String name,
    bool? active,
  });

  Future<void> createProgramme({
    required String departmentId,
    required String code,
    required String name,
    int? durationTerms,
  });

  Future<void> updateProgramme(
    String id, {
    required String departmentId,
    required String code,
    required String name,
    int? durationTerms,
    bool? active,
  });

  Future<void> createClass({
    required String programmeId,
    required int yearOfStudy,
    required String sectionCode,
    int? capacity,
  });

  Future<void> updateClass(
    String id, {
    required String sectionCode,
    int? capacity,
    bool? active,
  });

  Future<void> createSubject({
    required String departmentId,
    required String code,
    required String name,
    double? credits,
  });

  Future<void> updateSubject(
    String id, {
    required String departmentId,
    required String code,
    required String name,
    double? credits,
    bool? active,
  });
}

class BackendAcademicStructureRepository
    implements AcademicStructureRepository {
  BackendAcademicStructureRepository({
    required String baseUrl,
    required AccessTokenProvider accessTokenProvider,
    http.Client? client,
  }) : _baseUri = Uri.parse(baseUrl.replaceFirst(RegExp(r'/$'), '')),
       _accessTokenProvider = accessTokenProvider,
       _client = client ?? createAuthHttpClient();

  static const _root = '/api/v1/academic-structure';

  final Uri _baseUri;
  final AccessTokenProvider _accessTokenProvider;
  final http.Client _client;

  @override
  Future<AcademicCatalog> loadCatalog({bool includeInactive = false}) async {
    final body = await _send(
      'GET',
      '$_root/catalog${includeInactive ? '?includeInactive=true' : ''}',
    );
    final data = body['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('The server returned an invalid catalog.');
    }
    return AcademicCatalog.fromJson(data);
  }

  @override
  Future<void> createDepartment({
    required String code,
    required String name,
  }) => _send('POST', '$_root/departments', {'code': code, 'name': name});

  @override
  Future<void> updateDepartment(
    String id, {
    required String code,
    required String name,
    bool? active,
  }) => _send('PUT', '$_root/departments/${Uri.encodeComponent(id)}', {
    'code': code,
    'name': name,
    'active': ?active,
  });

  @override
  Future<void> createProgramme({
    required String departmentId,
    required String code,
    required String name,
    int? durationTerms,
  }) => _send('POST', '$_root/programmes', {
    'departmentId': departmentId,
    'code': code,
    'name': name,
    'durationTerms': ?durationTerms,
  });

  @override
  Future<void> updateProgramme(
    String id, {
    required String departmentId,
    required String code,
    required String name,
    int? durationTerms,
    bool? active,
  }) => _send('PUT', '$_root/programmes/${Uri.encodeComponent(id)}', {
    'departmentId': departmentId,
    'code': code,
    'name': name,
    'durationTerms': ?durationTerms,
    'active': ?active,
  });

  @override
  Future<void> createClass({
    required String programmeId,
    required int yearOfStudy,
    required String sectionCode,
    int? capacity,
  }) => _send('POST', '$_root/classes', {
    'programmeId': programmeId,
    'yearOfStudy': yearOfStudy,
    'sectionCode': sectionCode,
    'capacity': ?capacity,
  });

  @override
  Future<void> updateClass(
    String id, {
    required String sectionCode,
    int? capacity,
    bool? active,
  }) => _send('PUT', '$_root/classes/${Uri.encodeComponent(id)}', {
    'sectionCode': sectionCode,
    'capacity': ?capacity,
    'active': ?active,
  });

  @override
  Future<void> createSubject({
    required String departmentId,
    required String code,
    required String name,
    double? credits,
  }) => _send('POST', '$_root/subjects', {
    'departmentId': departmentId,
    'code': code,
    'name': name,
    'credits': ?credits,
  });

  @override
  Future<void> updateSubject(
    String id, {
    required String departmentId,
    required String code,
    required String name,
    double? credits,
    bool? active,
  }) => _send('PUT', '$_root/subjects/${Uri.encodeComponent(id)}', {
    'departmentId': departmentId,
    'code': code,
    'name': name,
    'credits': ?credits,
    'active': ?active,
  });

  Future<Map<String, dynamic>> _send(
    String method,
    String path, [
    Map<String, Object?>? payload,
  ]) async {
    Future<http.Response> attempt(String token) {
      final request = http.Request(method, _baseUri.resolve(path))
        ..headers.addAll({
          'authorization': 'Bearer $token',
          'x-client-surface': 'app',
          'accept': 'application/json',
          if (payload != null) 'content-type': 'application/json',
        });
      if (payload != null) request.body = jsonEncode(payload);
      return _client.send(request).then(http.Response.fromStream);
    }

    var response = await attempt(await _accessTokenProvider());
    if (response.statusCode == 401) {
      response = await attempt(await _accessTokenProvider(forceRefresh: true));
    }
    final text = response.body.trim();
    Map<String, dynamic> body = const {};
    if (text.isNotEmpty) {
      try {
        final decoded = jsonDecode(text);
        if (decoded is Map<String, dynamic>) body = decoded;
      } on FormatException {
        if (response.statusCode >= 200 && response.statusCode < 300) {
          throw Exception('The server returned an invalid response.');
        }
      }
    }
    if (response.statusCode == 403) {
      throw Exception('You do not have permission to change this.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = body['error'];
      final message = error is Map<String, dynamic>
          ? error['message']?.toString()
          : error?.toString();
      throw Exception(
        message ?? 'The request failed (${response.statusCode}).',
      );
    }
    return body;
  }
}
