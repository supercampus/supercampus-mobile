import 'dart:convert';

import 'package:http/http.dart' as http;

typedef MaintenanceAccessTokenProvider =
    Future<String> Function({bool forceRefresh});

class MaintenanceWindow {
  const MaintenanceWindow({
    required this.enabled,
    this.active = false,
    this.startsAt,
    this.endsAt,
    this.message = '',
  });

  final bool enabled;
  final bool active;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final String message;

  factory MaintenanceWindow.fromJson(Map<String, dynamic> json) {
    return MaintenanceWindow(
      enabled: json['enabled'] == true || json['active'] == true,
      active: json['active'] == true,
      startsAt: DateTime.tryParse(
        json['startsAt']?.toString() ?? '',
      )?.toLocal(),
      endsAt: DateTime.tryParse(json['endsAt']?.toString() ?? '')?.toLocal(),
      message: json['message']?.toString() ?? '',
    );
  }

  static const inactive = MaintenanceWindow(enabled: false);
}

class MaintenanceRepository {
  MaintenanceRepository({
    required String baseUrl,
    MaintenanceAccessTokenProvider? accessTokenProvider,
    http.Client? client,
  }) : _baseUri = Uri.parse(baseUrl.replaceFirst(RegExp(r'/$'), '')),
       _accessTokenProvider = accessTokenProvider,
       _client = client ?? http.Client();

  final Uri _baseUri;
  final MaintenanceAccessTokenProvider? _accessTokenProvider;
  final http.Client _client;

  Future<MaintenanceWindow> publicStatus() async {
    final response = await _client.get(_uri('/api/maintenance'));
    return _decode(response);
  }

  Future<MaintenanceWindow> adminStatus() async {
    return _authorized('GET', '/api/v1/admin/maintenance');
  }

  Future<MaintenanceWindow> save({
    required bool enabled,
    required DateTime startsAt,
    required DateTime endsAt,
    required String message,
  }) async {
    return _authorized(
      'PUT',
      '/api/v1/admin/maintenance',
      body: {
        'enabled': enabled,
        'startsAt': startsAt.toUtc().toIso8601String(),
        'endsAt': endsAt.toUtc().toIso8601String(),
        'message': message,
      },
    );
  }

  Future<MaintenanceWindow> _authorized(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final provider = _accessTokenProvider;
    if (provider == null) {
      throw StateError('Administrator session is required.');
    }
    final token = await provider(forceRefresh: false);
    final headers = {
      'authorization': 'Bearer $token',
      'content-type': 'application/json',
      'x-client-surface': 'app',
    };
    var response = await _send(method, path, headers, body);
    if (response.statusCode == 401) {
      headers['authorization'] = 'Bearer ${await provider(forceRefresh: true)}';
      response = await _send(method, path, headers, body);
    }
    return _decode(response);
  }

  Future<http.Response> _send(
    String method,
    String path,
    Map<String, String> headers,
    Map<String, dynamic>? body,
  ) {
    final encoded = body == null ? null : jsonEncode(body);
    return method == 'PUT'
        ? _client.put(_uri(path), headers: headers, body: encoded)
        : _client.get(_uri(path), headers: headers);
  }

  MaintenanceWindow _decode(http.Response response) {
    Map<String, dynamic>? decoded;
    try {
      decoded = jsonDecode(response.body) as Map<String, dynamic>;
    } on Object {
      decoded = null;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        decoded?['error']?.toString() ?? 'The maintenance request failed.',
      );
    }
    final data = decoded?['data'];
    return data is Map<String, dynamic>
        ? MaintenanceWindow.fromJson(data)
        : MaintenanceWindow.inactive;
  }

  Uri _uri(String path) => _baseUri.replace(path: path);
}
