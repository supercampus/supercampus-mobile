import 'dart:convert';

import 'package:http/http.dart' as http;

import 'admin_system_models.dart';

/// Reads the public app version policy (`GET /api/app-version`). No session
/// is needed: the check runs before sign-in too.
abstract class AppVersionSource {
  Future<AppVersionPolicy> fetch(String platform);
}

class BackendAppVersionSource implements AppVersionSource {
  BackendAppVersionSource({required String baseUrl, http.Client? client})
    : _baseUri = Uri.parse(baseUrl.replaceFirst(RegExp(r'/$'), '')),
      _client = client ?? http.Client();

  final Uri _baseUri;
  final http.Client _client;

  @override
  Future<AppVersionPolicy> fetch(String platform) async {
    final response = await _client
        .get(
          _baseUri.replace(
            path: '/api/app-version',
            queryParameters: {'platform': platform},
          ),
          headers: const {'accept': 'application/json'},
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('App version check failed (${response.statusCode})');
    }
    final decoded = jsonDecode(response.body);
    final data = decoded is Map ? decoded['data'] : null;
    if (data is! Map) throw const FormatException('Unreadable version policy');
    return AppVersionPolicy.fromJson(Map<String, dynamic>.from(data));
  }
}
