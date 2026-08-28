import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../features/authentication/data/auth_http_client.dart';
import '../../features/authentication/data/auth_repository.dart';

class StudentFeeRecord {
  const StudentFeeRecord({
    required this.id,
    required this.type,
    required this.data,
  });

  factory StudentFeeRecord.fromJson(Map<String, dynamic> json) =>
      StudentFeeRecord(
        id: json['id']?.toString() ?? '',
        type: json['recordType']?.toString() ?? '',
        data: Map<String, dynamic>.from(
          json['data'] is Map ? json['data'] as Map : const {},
        ),
      );

  final String id;
  final String type;
  final Map<String, dynamic> data;
}

class TuitionFeeRepository {
  TuitionFeeRepository({
    required String baseUrl,
    required AccessTokenProvider accessTokenProvider,
    http.Client? client,
  }) : _baseUri = Uri.parse(baseUrl.trim().replaceAll(RegExp(r'/+$'), '')),
       _accessTokenProvider = accessTokenProvider,
       _client = client ?? createAuthHttpClient();

  final Uri _baseUri;
  final AccessTokenProvider _accessTokenProvider;
  final http.Client _client;

  Future<List<StudentFeeRecord>> load() async {
    var token = await _accessTokenProvider();
    var response = await _get(token);
    if (response.statusCode == 401) {
      token = await _accessTokenProvider(forceRefresh: true);
      response = await _get(token);
    }
    final decoded = jsonDecode(response.body);
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        decoded is! Map) {
      final error = decoded is Map && decoded['error'] is Map
          ? (decoded['error'] as Map)['message']?.toString()
          : null;
      throw TuitionFeeException(
        error ?? 'Your fee account could not be loaded.',
      );
    }
    final data = decoded['data'];
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((row) => StudentFeeRecord.fromJson(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  Future<http.Response> _get(String token) => _client.get(
    _baseUri.resolve('/api/v1/student/fees'),
    headers: {
      'authorization': 'Bearer $token',
      'x-client-surface': 'app',
      'accept': 'application/json',
    },
  );
}

class TuitionFeeException implements Exception {
  const TuitionFeeException(this.message);
  final String message;
}
