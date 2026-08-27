import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'auth_http_client.dart';
import 'auth_repository.dart';

class BackendAuthRepository implements AuthRepository {
  BackendAuthRepository({required String baseUrl, http.Client? client})
    : _baseUri = _normalizeBaseUri(baseUrl),
      _client = client ?? createAuthHttpClient();

  final Uri _baseUri;
  final http.Client _client;

  @override
  Future<UserSession> signIn({
    required String email,
    required String password,
    required String tenantDomain,
    UserRole? roleHint,
  }) async {
    // Not `late final`: a server too old to know `sessionMode` rejects the
    // first attempt, and the retry reassigns this.
    late http.Response response;
    try {
      response = await _postLogin(
        email: email,
        password: password,
        tenantDomain: tenantDomain,
        tokenMode: true,
      );
      if (_isLegacySessionModeRejection(response)) {
        response = await _postLogin(
          email: email,
          password: password,
          tenantDomain: tenantDomain,
          tokenMode: false,
        );
      }
    } on http.ClientException catch (error) {
      throw AuthenticationException(_connectionMessage(error, _baseUri));
    }
    if (response.statusCode == 401) {
      throw const AuthenticationException(
        'The username or password you entered is incorrect.',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthenticationException(_errorMessage(response));
    }

    return _sessionFromResponse(
      response,
      fallbackEmail: email,
      // Only reached when the server returns neither a role nor a portal
      // family. Least privilege is the right guess in that case.
      fallbackRole: roleHint ?? UserRole.student,
    );
  }

  @override
  Future<UserSession> refresh(UserSession session) async {
    final refreshToken = session.refreshToken;
    late final http.Response response;
    try {
      response = await _client.post(
        _uri('/api/auth/refresh'),
        headers: const {
          'content-type': 'application/json',
          'x-client-surface': 'app',
        },
        body: refreshToken == null || refreshToken.isEmpty
            ? null
            : jsonEncode({'refreshToken': refreshToken}),
      );
    } on http.ClientException catch (error) {
      throw AuthenticationException(_connectionMessage(error, _baseUri));
    }
    if (response.statusCode == 401) {
      throw const AuthenticationException(
        'Your session has expired. Sign in again.',
        sessionExpired: true,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthenticationException(_errorMessage(response));
    }

    return _sessionFromResponse(
      response,
      fallbackEmail: session.email,
      fallbackRole: session.role,
      fallbackRefreshToken: refreshToken,
    );
  }

  UserSession _sessionFromResponse(
    http.Response response, {
    required String fallbackEmail,
    required UserRole fallbackRole,
    String? fallbackRefreshToken,
  }) {
    final Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } on FormatException {
      throw const AuthenticationException(
        'The API returned an unreadable session response.',
      );
    }
    final data = body['data'];
    if (data is! Map<String, dynamic>) {
      throw const AuthenticationException(
        'The API login response is missing session data.',
      );
    }
    final student = data['student'];
    if (student is! Map<String, dynamic>) {
      throw const AuthenticationException(
        'The API login response is missing user data.',
      );
    }
    final roles = (data['roles'] as List? ?? const [])
        .map((value) => value.toString())
        .toList();
    final primaryRole = roles.isNotEmpty
        ? roles.first
        : (student['role']?.toString() ?? fallbackRole.name);
    final portalFamilies = (student['portalFamilies'] as List? ?? const [])
        .map((value) => _portalFamilyFromBackend(value.toString()))
        .whereType<PortalFamily>()
        .toSet()
        .toList();
    final activePortalFamily = portalFamilies.isEmpty
        ? _portalFamilyForLegacyRole(
            _roleFromBackend(primaryRole, fallback: fallbackRole),
          )
        : portalFamilies.first;

    return UserSession(
      email: student['email']?.toString() ?? fallbackEmail,
      displayName: student['name']?.toString() ?? fallbackEmail,
      role: _roleForPortalFamily(activePortalFamily, primaryRole),
      roleId: primaryRole,
      roleName: _humanize(primaryRole),
      idNumber: student['roll']?.toString(),
      departmentOrWard: student['dept']?.toString(),
      photoUrl: student['photoUrl']?.toString(),
      departmentId: student['departmentId']?.toString(),
      sectionId:
          student['sectionId']?.toString() ?? student['section']?.toString(),
      staffId: student['staffId']?.toString(),
      jwtToken: data['accessToken']?.toString(),
      refreshToken: data['refreshToken']?.toString() ?? fallbackRefreshToken,
      accessTokenExpiresAt: DateTime.tryParse(
        data['expiresAt']?.toString() ?? '',
      ),
      portalFamilies: portalFamilies.isEmpty
          ? [activePortalFamily]
          : portalFamilies,
      activePortalFamily: activePortalFamily,
      roleIds: roles,
    );
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    await _client.post(
      _uri('/api/auth/forgot-password'),
      headers: const {'content-type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
  }

  Future<http.Response> _postLogin({
    required String email,
    required String password,
    required String tenantDomain,
    required bool tokenMode,
  }) {
    final body = <String, String>{'email': email, 'password': password};
    if (tokenMode) body['sessionMode'] = 'token';
    return _client.post(
      _uri('/api/auth/login'),
      headers: {
        'content-type': 'application/json',
        'x-tenant-id': tenantDomain,
        'x-client-surface': 'app',
      },
      body: jsonEncode(body),
    );
  }

  Uri _uri(String path) => _baseUri.replace(path: path);
}

Uri _normalizeBaseUri(String baseUrl) {
  final uri = Uri.parse(baseUrl.replaceFirst(RegExp(r'/$'), ''));
  if (kIsWeb && _isLoopbackHost(uri.host) && _isLoopbackHost(Uri.base.host)) {
    return uri.replace(host: Uri.base.host);
  }
  if (!kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android &&
      _isLoopbackHost(uri.host)) {
    return uri.replace(host: '10.0.2.2');
  }
  return uri;
}

bool _isLoopbackHost(String host) => host == '127.0.0.1' || host == 'localhost';

String _errorMessage(http.Response response) {
  try {
    final body = jsonDecode(response.body);
    if (body is Map<String, dynamic>) {
      final error = body['error'];
      if (error is String && error.isNotEmpty) return error;
      final message = body['message'];
      if (message is String && message.isNotEmpty) return message;
    }
  } catch (_) {
    // Fall through to the status-based message.
  }
  return 'Unable to sign in right now. (${response.statusCode})';
}

bool _isLegacySessionModeRejection(http.Response response) {
  if (response.statusCode != 400 && response.statusCode != 422) return false;
  final body = response.body.toLowerCase();
  return body.contains('sessionmode') && body.contains('unknown field');
}

String _connectionMessage(http.ClientException error, Uri baseUri) {
  final origin = baseUri.replace(path: '', query: '', fragment: '').toString();
  if (kReleaseMode) {
    return 'The SuperCampus API is unavailable at $origin. Check your connection and try again.';
  }
  final detail = error.message.trim();
  if (detail.isEmpty) {
    return 'The SuperCampus API is unavailable at $origin.';
  }
  return 'The SuperCampus API is unavailable at $origin. $detail';
}

UserRole _roleFromBackend(String role, {required UserRole fallback}) {
  final normalized = role.toLowerCase().replaceAll('-', '_');
  if (normalized.contains('admin')) return UserRole.admin;
  if (normalized.contains('security')) return UserRole.security;
  if (normalized.contains('parent')) return UserRole.parent;
  if (normalized.contains('allocator')) return UserRole.timetableAllocator;
  if (normalized.contains('faculty') || normalized.contains('staff')) {
    return UserRole.staff;
  }
  if (normalized.contains('student')) return UserRole.student;
  return fallback;
}

PortalFamily? _portalFamilyFromBackend(String value) =>
    switch (value.trim().toLowerCase()) {
      'student' => PortalFamily.student,
      'parent' => PortalFamily.parent,
      'staff' => PortalFamily.staff,
      'admin' => PortalFamily.admin,
      _ => null,
    };

PortalFamily _portalFamilyForLegacyRole(UserRole role) => switch (role) {
  UserRole.student => PortalFamily.student,
  UserRole.parent => PortalFamily.parent,
  UserRole.admin => PortalFamily.admin,
  _ => PortalFamily.staff,
};

UserRole _roleForPortalFamily(PortalFamily family, String backendRole) =>
    switch (family) {
      PortalFamily.student => UserRole.student,
      PortalFamily.parent => UserRole.parent,
      PortalFamily.admin => UserRole.admin,
      PortalFamily.staff => _roleFromBackend(
        backendRole,
        fallback: UserRole.staff,
      ),
    };

String _humanize(String value) {
  return value
      .split(RegExp(r'[_\-.]+'))
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}
