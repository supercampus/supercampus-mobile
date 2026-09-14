import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../authentication/data/auth_http_client.dart';
import '../../authentication/data/auth_repository.dart';

class MarksBatchRepository {
  MarksBatchRepository({
    required String baseUrl,
    required AccessTokenProvider accessTokenProvider,
    http.Client? client,
  }) : _baseUri = Uri.parse(baseUrl.replaceAll(RegExp(r'/+$'), '')),
       _tokenProvider = accessTokenProvider,
       _client = client ?? createAuthHttpClient();

  final Uri _baseUri;
  final AccessTokenProvider _tokenProvider;
  final http.Client _client;

  Uri _uri(String path) => _baseUri.resolve(path);

  Future<List<Map<String, dynamic>>> subjects() async {
    final response = await _request(
      (headers) => _client.get(
        _uri('/api/v1/operations/marks/subjects'),
        headers: headers,
      ),
    );
    final data = _data(response);
    return (data['subjects'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  Future<List<Map<String, dynamic>>> list() async {
    final response = await _request(
      (headers) => _client.get(
        _uri('/api/v1/operations/marks/batches'),
        headers: headers,
      ),
    );
    final data = _data(response);
    return (data['batches'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  Future<Map<String, dynamic>> create({
    required String subjectCode,
    required String subjectName,
    required String assessmentType,
    required double maximumMarks,
    required List<Map<String, dynamic>> entries,
  }) async => _data(
    await _request(
      (headers) => _client.post(
        _uri('/api/v1/operations/marks/batches'),
        headers: {...headers, 'content-type': 'application/json'},
        body: jsonEncode({
          'subjectCode': subjectCode,
          'subjectName': subjectName,
          'assessmentType': assessmentType,
          'maximumMarks': maximumMarks,
          'entries': entries,
        }),
      ),
    ),
  );

  Future<Map<String, dynamic>> review(
    String id,
    String decision, {
    String? note,
  }) async => _data(
    await _request(
      (headers) => _client.post(
        _uri('/api/v1/operations/marks/batches/$id/review'),
        headers: {...headers, 'content-type': 'application/json'},
        body: jsonEncode({
          'decision': decision,
          if (note != null && note.isNotEmpty) 'note': note,
        }),
      ),
    ),
  );

  Future<http.Response> _request(
    Future<http.Response> Function(Map<String, String>) send,
  ) async {
    var token = await _tokenProvider(forceRefresh: false);
    var response = await send({'authorization': 'Bearer $token'});
    if (response.statusCode == 401) {
      token = await _tokenProvider(forceRefresh: true);
      response = await send({'authorization': 'Bearer $token'});
    }
    return response;
  }

  Map<String, dynamic> _data(http.Response response) {
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(decoded['error']?.toString() ?? 'Marks request failed');
    }
    return (decoded['data'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};
  }
}
