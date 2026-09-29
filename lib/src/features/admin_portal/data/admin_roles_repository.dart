import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../authentication/data/auth_http_client.dart';
import '../../authentication/data/auth_repository.dart';

/// A tenant role as the Admin Desk manages it.
class RoleDefinition {
  const RoleDefinition({
    required this.id,
    required this.key,
    required this.name,
    this.team = '',
    this.description = '',
    this.portalFamily = 'staff',
    this.protected = false,
    this.system = false,
    this.active = true,
    this.assignable = true,
    this.memberCount = 0,
    this.appPermissions = const {},
    this.websitePermissions = const {},
  });

  factory RoleDefinition.fromJson(Map<String, dynamic> json) {
    Map<String, String> grants(Object? value) => {
      for (final item in (value as List? ?? const []).whereType<Map>())
        if ((item['key']?.toString() ?? '').isNotEmpty)
          item['key'].toString(): item['scope']?.toString() ?? 'all',
    };
    final bySurface = json['permissionsBySurface'];
    final surfaces = bySurface is Map ? bySurface : const {};
    return RoleDefinition(
      id: json['id']?.toString() ?? '',
      key: json['key']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      team: json['team']?.toString() ?? '',
      description: json['scope']?.toString() ?? '',
      portalFamily: json['portalFamily']?.toString() ?? 'staff',
      protected: json['protected'] == true,
      system: json['system'] == true,
      active: json['active'] != false,
      assignable: json['assignable'] != false,
      memberCount: (json['memberCount'] as num?)?.toInt() ?? 0,
      appPermissions: grants(surfaces['app']),
      websitePermissions: grants(surfaces['website'] ?? json['permissions']),
    );
  }

  final String id;
  final String key;
  final String name;
  final String team;
  final String description;
  final String portalFamily;

  /// Protected roles cannot be changed at all.
  final bool protected;

  /// System roles can be edited but never deleted.
  final bool system;
  final bool active;

  /// Whether the signed-in administrator may shape or hand out this role.
  final bool assignable;
  final int memberCount;

  /// Permission key to scope, per surface.
  final Map<String, String> appPermissions;
  final Map<String, String> websitePermissions;

  bool get editable => !protected && assignable;
  bool get deletable => editable && !system;

  /// Every permission the role holds on either surface.
  Set<String> get permissionKeys => {
    ...appPermissions.keys,
    ...websitePermissions.keys,
  };
}

/// A permission from the tenant's catalogue.
class PermissionDefinition {
  const PermissionDefinition({
    required this.key,
    required this.moduleKey,
    required this.featureKey,
    required this.action,
    required this.name,
    this.description = '',
  });

  factory PermissionDefinition.fromJson(Map<String, dynamic> json) =>
      PermissionDefinition(
        key: json['key']?.toString() ?? '',
        moduleKey: json['moduleKey']?.toString() ?? '',
        featureKey: json['featureKey']?.toString() ?? '',
        action: json['action']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
      );

  final String key;
  final String moduleKey;
  final String featureKey;
  final String action;
  final String name;
  final String description;
}

/// Permissions a campus administrator may not put on a role: the `*`
/// wildcard and the platform's own. The server refuses them as well.
bool isReservedPermissionKey(String key) =>
    key == '*' || key == 'platform' || key.startsWith('platform.');

/// Groups the catalogue by module for the picker, in a stable order, keeping
/// only permissions that match [query] (name, key or description).
Map<String, List<PermissionDefinition>> groupPermissions(
  Iterable<PermissionDefinition> permissions, {
  String query = '',
}) {
  final needle = query.trim().toLowerCase();
  final groups = <String, List<PermissionDefinition>>{};
  final sorted = permissions
      .where((permission) => !isReservedPermissionKey(permission.key))
      .where(
        (permission) =>
            needle.isEmpty ||
            '${permission.name} ${permission.key} ${permission.description}'
                .toLowerCase()
                .contains(needle),
      )
      .toList()
    ..sort((a, b) {
      final module = a.moduleKey.compareTo(b.moduleKey);
      return module != 0 ? module : a.key.compareTo(b.key);
    });
  for (final permission in sorted) {
    groups.putIfAbsent(permission.moduleKey, () => []).add(permission);
  }
  return groups;
}

/// Turns a module key such as `vendor_management` into "Vendor management".
String moduleLabel(String moduleKey) {
  final words = moduleKey
      .replaceAll(RegExp(r'[-_.]+'), ' ')
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList();
  if (words.isEmpty) return 'Other';
  final first = words.first;
  return [
    first[0].toUpperCase() + first.substring(1),
    ...words.skip(1),
  ].join(' ');
}

class AdminRolesRepository {
  AdminRolesRepository({
    required String baseUrl,
    required AccessTokenProvider accessTokenProvider,
    http.Client? client,
  }) : _baseUri = Uri.parse(baseUrl.replaceFirst(RegExp(r'/$'), '')),
       _accessTokenProvider = accessTokenProvider,
       _client = client ?? createAuthHttpClient();

  final Uri _baseUri;
  final AccessTokenProvider _accessTokenProvider;
  final http.Client _client;

  Future<List<RoleDefinition>> listRoles() async {
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
        .map(RoleDefinition.fromJson)
        .toList();
  }

  Future<List<PermissionDefinition>> listPermissions() async {
    final data = await _request(
      (headers) => _client.get(
        _baseUri.resolve('/api/v1/authorization/permissions'),
        headers: headers,
      ),
    );
    final values = data['data'];
    if (values is! List) return const [];
    return values
        .whereType<Map<String, dynamic>>()
        .where((value) => value['active'] != false)
        .map(PermissionDefinition.fromJson)
        .toList();
  }

  /// Creates a role and returns its id.
  Future<String> createRole({
    required String key,
    required String name,
    String team = '',
    String description = '',
    String portalFamily = 'staff',
  }) async {
    final data = await _request(
      (headers) => _client.post(
        _baseUri.resolve('/api/v1/authorization/roles'),
        headers: {...headers, 'content-type': 'application/json'},
        body: jsonEncode({
          'key': key,
          'name': name.trim(),
          'team': team.trim(),
          'scope': description.trim(),
          'portalFamily': portalFamily,
          'surfaces': ['app', 'website'],
        }),
      ),
    );
    final value = data['data'];
    return value is Map ? value['id']?.toString() ?? '' : '';
  }

  Future<void> updateRole(
    String roleId, {
    String? name,
    String? description,
    String? team,
  }) async {
    await _request(
      (headers) => _client.put(
        _baseUri.resolve(
          '/api/v1/authorization/roles/${Uri.encodeComponent(roleId)}',
        ),
        headers: {...headers, 'content-type': 'application/json'},
        body: jsonEncode({
          if (name != null) 'name': name.trim(),
          if (description != null) 'scope': description.trim(),
          if (team != null) 'team': team.trim(),
        }),
      ),
    );
  }

  /// Replaces the role's permissions on both the app and the website, so a
  /// role means the same thing wherever its members sign in. [grants] maps
  /// permission key to scope.
  Future<void> setRolePermissions(
    String roleId,
    Map<String, String> grants,
  ) async {
    for (final surface in const ['app', 'website']) {
      await _request(
        (headers) => _client.put(
          _baseUri.resolve(
            '/api/v1/authorization/roles/${Uri.encodeComponent(roleId)}/permissions',
          ),
          headers: {...headers, 'content-type': 'application/json'},
          body: jsonEncode({
            'surface': surface,
            'permissions': [
              for (final entry in grants.entries)
                {'key': entry.key, 'scope': entry.value, 'constraints': {}},
            ],
          }),
        ),
      );
    }
  }

  /// Deletes a role. A role that still has members needs [reassignTo], the
  /// role they move to.
  Future<void> deleteRole(String roleId, {String? reassignTo}) async {
    final path =
        '/api/v1/authorization/roles/${Uri.encodeComponent(roleId)}'
        '${reassignTo == null ? '' : '?reassignTo=${Uri.encodeQueryComponent(reassignTo)}'}';
    await _request(
      (headers) => _client.delete(_baseUri.resolve(path), headers: headers),
    );
  }

  Future<Map<String, dynamic>> _request(
    Future<http.Response> Function(Map<String, String> headers) send,
  ) async {
    Map<String, String> headersFor(String token) => {
      'authorization': 'Bearer $token',
      'x-client-surface': 'app',
      'accept': 'application/json',
    };
    var response = await send(headersFor(await _accessTokenProvider()));
    if (response.statusCode == 401) {
      response = await send(
        headersFor(await _accessTokenProvider(forceRefresh: true)),
      );
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
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = body['error'];
      final message = error is Map<String, dynamic>
          ? error['message']?.toString()
          : error?.toString();
      throw Exception(
        message ??
            (text.isNotEmpty ? text : 'Request failed (${response.statusCode})'),
      );
    }
    return body;
  }
}
