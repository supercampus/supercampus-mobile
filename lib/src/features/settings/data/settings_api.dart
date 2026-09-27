import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../authentication/data/auth_http_client.dart';
import '../../authentication/data/auth_repository.dart';

/// A failure whose [message] is written for people (usually the server's own
/// `error` text) and can be shown as-is.
class SettingsApiException implements Exception {
  const SettingsApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Minimal authorised JSON client shared by the Settings repositories. It
/// retries once with a refreshed token on 401, like the other repositories.
class SettingsApiClient {
  SettingsApiClient({
    required String baseUrl,
    required AccessTokenProvider accessTokenProvider,
    http.Client? client,
  }) : _baseUri = Uri.parse(baseUrl.trim().replaceAll(RegExp(r'/+$'), '')),
       _accessTokenProvider = accessTokenProvider,
       _client = client ?? createAuthHttpClient();

  final Uri _baseUri;
  final AccessTokenProvider _accessTokenProvider;
  final http.Client _client;

  String get baseUrl => _baseUri.toString();

  /// Sends the request and returns the decoded `data` field (or null when a
  /// success carries none). Non-2xx responses throw [SettingsApiException]
  /// with the server's message, or [fallbackError] when it sent none.
  Future<Object?> send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
    required String fallbackError,
  }) async {
    var uri = _baseUri.resolve(path);
    if (query != null && query.isNotEmpty) {
      uri = uri.replace(queryParameters: query);
    }
    Future<http.Response> sendWith(String token) {
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

    http.Response response;
    try {
      var token = await _accessTokenProvider();
      response = await sendWith(token);
      if (response.statusCode == 401) {
        token = await _accessTokenProvider(forceRefresh: true);
        response = await sendWith(token);
      }
    } on SettingsApiException {
      rethrow;
    } on http.ClientException {
      throw const SettingsApiException(
        'You appear to be offline. Check your connection and try again.',
      );
    }

    Object? decoded;
    try {
      decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    } catch (_) {
      decoded = null;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw SettingsApiException(
        errorMessageFrom(decoded) ?? fallbackError,
        statusCode: response.statusCode,
      );
    }
    return decoded is Map ? decoded['data'] : null;
  }
}

/// Reads `{"error": "…"}`, `{"error": {"message": "…"}}` or
/// `{"message": "…"}`.
String? errorMessageFrom(Object? decoded) {
  if (decoded is! Map) return null;
  final error = decoded['error'];
  if (error is String && error.trim().isNotEmpty) return error.trim();
  if (error is Map) {
    final message = error['message'];
    if (message is String && message.trim().isNotEmpty) return message.trim();
  }
  final message = decoded['message'];
  if (message is String && message.trim().isNotEmpty) return message.trim();
  return null;
}

String? cleanText(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}
