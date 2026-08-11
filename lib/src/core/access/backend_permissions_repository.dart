import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../features/authentication/data/auth_repository.dart';
import 'effective_permissions.dart';
import 'permissions_repository.dart';

class BackendPermissionsRepository implements PermissionsRepository {
  BackendPermissionsRepository({required String baseUrl, http.Client? client})
    : _baseUri = _normalizeBaseUri(baseUrl),
      _client = client ?? http.Client();

  final Uri _baseUri;
  final http.Client _client;

  @override
  Future<EffectivePermissions> loadFor(UserSession session) async {
    final token = session.jwtToken;
    if (token == null || token.isEmpty) {
      throw const PermissionsException('A backend session token is required.');
    }

    // Bootstrap carries live tenant branding and permissions. Prevent browser
    // and intermediary caches from returning an older branding document.
    final response = await _client.get(
      _uri('/api/v1/bootstrap').replace(
        queryParameters: {
          '_sync': DateTime.now().millisecondsSinceEpoch.toString(),
        },
      ),
      headers: {
        'authorization': 'Bearer $token',
        'x-client-surface': 'app',
        'accept': 'application/json',
      },
    );
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const PermissionsException('This session cannot load app access.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const PermissionsException('Unable to load app access.');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>;
    return EffectivePermissions.fromJson({
      'grants': data['permissions'] ?? const [],
      'scopes': data['permissionScopes'] ?? const {},
      'tenantBrand': data['tenantBrand'] ?? const {},
    });
  }

  Uri _uri(String path) => _baseUri.replace(path: path);
}

Uri _normalizeBaseUri(String baseUrl) {
  final uri = Uri.parse(baseUrl.replaceFirst(RegExp(r'/$'), ''));
  if (!kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android &&
      (uri.host == '127.0.0.1' || uri.host == 'localhost')) {
    return uri.replace(host: '10.0.2.2');
  }
  return uri;
}

class PermissionsException implements Exception {
  const PermissionsException(this.message);

  final String message;

  @override
  String toString() => message;
}
