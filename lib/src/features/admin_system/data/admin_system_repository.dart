import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../authentication/data/auth_http_client.dart';
import '../../authentication/data/auth_repository.dart';
import 'admin_system_models.dart';

class AdminSystemException implements Exception {
  const AdminSystemException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Finance audit, security logs and app version policy for the Admin Desk.
abstract class AdminSystemRepository {
  Future<AuditPage> auditLogs(
    AuditFilter filter, {
    int limit = 50,
    int offset = 0,
  });

  Future<SessionsPage> sessions(
    SecurityLogQuery query, {
    int limit = 50,
    int offset = 0,
  });

  Future<LoginEventsPage> loginEvents(
    SecurityLogQuery query, {
    int limit = 50,
    int offset = 0,
  });

  Future<void> revokeSession(String sessionId);

  Future<List<AppVersionPolicy>> appVersions();

  Future<AppVersionPolicy> saveAppVersion(AppVersionPolicy policy);
}

class BackendAdminSystemRepository implements AdminSystemRepository {
  BackendAdminSystemRepository({
    required String baseUrl,
    required AccessTokenProvider accessTokenProvider,
    http.Client? client,
  }) : _baseUri = Uri.parse(baseUrl.replaceFirst(RegExp(r'/$'), '')),
       _accessTokenProvider = accessTokenProvider,
       _client = client ?? createAuthHttpClient();

  final Uri _baseUri;
  final AccessTokenProvider _accessTokenProvider;
  final http.Client _client;

  @override
  Future<AuditPage> auditLogs(
    AuditFilter filter, {
    int limit = 50,
    int offset = 0,
  }) async => AuditPage.fromJson(
    await _send(
      'GET',
      '/api/v1/admin/audit-logs',
      query: filter.toQuery(limit: limit, offset: offset),
    ),
  );

  @override
  Future<SessionsPage> sessions(
    SecurityLogQuery query, {
    int limit = 50,
    int offset = 0,
  }) async => SessionsPage.fromJson(
    await _send(
      'GET',
      '/api/v1/admin/security-logs/sessions',
      query: query.toQuery(limit: limit, offset: offset),
    ),
  );

  @override
  Future<LoginEventsPage> loginEvents(
    SecurityLogQuery query, {
    int limit = 50,
    int offset = 0,
  }) async => LoginEventsPage.fromJson(
    await _send(
      'GET',
      '/api/v1/admin/security-logs/events',
      query: query.toQuery(limit: limit, offset: offset),
    ),
  );

  @override
  Future<void> revokeSession(String sessionId) async {
    await _send(
      'POST',
      '/api/v1/admin/security-logs/sessions/${Uri.encodeComponent(sessionId)}/revoke',
    );
  }

  @override
  Future<List<AppVersionPolicy>> appVersions() async {
    final data = await _send('GET', '/api/v1/admin/app-versions');
    return (data['policies'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (item) => AppVersionPolicy.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  @override
  Future<AppVersionPolicy> saveAppVersion(AppVersionPolicy policy) async =>
      AppVersionPolicy.fromJson(
        await _send(
          'PUT',
          '/api/v1/admin/app-versions/${Uri.encodeComponent(policy.platform)}',
          body: policy.toUpdateJson(),
        ),
      );

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
  }) async {
    final uri = _baseUri.replace(path: path, queryParameters: query);
    Future<http.Response> send(String token) {
      final headers = {
        'authorization': 'Bearer $token',
        'x-client-surface': 'app',
        'accept': 'application/json',
        if (body != null) 'content-type': 'application/json',
      };
      final encoded = body == null ? null : jsonEncode(body);
      return switch (method) {
        'POST' => _client.post(uri, headers: headers, body: encoded),
        'PUT' => _client.put(uri, headers: headers, body: encoded),
        _ => _client.get(uri, headers: headers),
      };
    }

    var response = await send(await _accessTokenProvider());
    if (response.statusCode == 401) {
      response = await send(await _accessTokenProvider(forceRefresh: true));
    }
    Map<String, dynamic>? decoded;
    try {
      final value = jsonDecode(response.body);
      if (value is Map<String, dynamic>) decoded = value;
    } catch (_) {}
    if (response.statusCode == 403) {
      throw const AdminSystemException(
        'Your account is not allowed to open this page.',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = decoded?['error'];
      final message = switch (error) {
        Map() => error['message']?.toString() ?? '',
        String() => error,
        _ => '',
      };
      throw AdminSystemException(
        message.trim().isNotEmpty
            ? message
            : 'Something went wrong. Try again.',
      );
    }
    final data = decoded?['data'];
    return data is Map<String, dynamic> ? data : const {};
  }
}
