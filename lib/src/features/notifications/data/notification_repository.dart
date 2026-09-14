import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../authentication/data/auth_http_client.dart';
import '../../authentication/data/auth_repository.dart';

class AppNotification {
  const AppNotification({
    required this.id,
    required this.category,
    required this.eventType,
    required this.title,
    required this.body,
    required this.createdAt,
    this.deepLink,
    this.priority = 'normal',
    this.requiresAction = false,
    this.readAt,
    this.data = const {},
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id']?.toString() ?? '',
        category: json['category']?.toString() ?? 'general',
        eventType: json['eventType']?.toString() ?? 'general.notice',
        title: json['title']?.toString() ?? 'Notification',
        body: json['body']?.toString() ?? '',
        createdAt:
            DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        deepLink: json['deepLink']?.toString(),
        priority: json['priority']?.toString() ?? 'normal',
        requiresAction: json['requiresAction'] == true,
        readAt: DateTime.tryParse(json['readAt']?.toString() ?? ''),
        data: json['data'] is Map<String, dynamic>
            ? json['data'] as Map<String, dynamic>
            : const {},
      );

  final String id;
  final String category;
  final String eventType;
  final String title;
  final String body;
  final DateTime createdAt;
  final String? deepLink;
  final String priority;
  final bool requiresAction;
  final DateTime? readAt;
  final Map<String, dynamic> data;

  bool get isRead => readAt != null;
}

class NotificationInbox {
  const NotificationInbox({
    required this.notifications,
    required this.unreadCount,
  });

  final List<AppNotification> notifications;
  final int unreadCount;
}

class NotificationRepository {
  NotificationRepository({
    required String baseUrl,
    required AccessTokenProvider accessTokenProvider,
    http.Client? client,
  }) : _baseUri = Uri.parse(baseUrl.trim().replaceAll(RegExp(r'/+$'), '')),
       _accessTokenProvider = accessTokenProvider,
       _client = client ?? createAuthHttpClient();

  final Uri _baseUri;
  final AccessTokenProvider _accessTokenProvider;
  final http.Client _client;

  Uri _uri(String path) => _baseUri.resolve(path);

  Future<NotificationInbox> inbox() async {
    final data = await _request(
      (headers) => _client.get(
        _uri('/api/v1/operations/notifications'),
        headers: headers,
      ),
    );
    final rows = data['notifications'];
    return NotificationInbox(
      notifications: rows is List
          ? rows
                .whereType<Map<String, dynamic>>()
                .map(AppNotification.fromJson)
                .toList(growable: false)
          : const [],
      unreadCount: _number(data['unreadCount']),
    );
  }

  Future<void> markRead(String notificationId) async {
    await _request(
      (headers) => _client.post(
        _uri('/api/v1/operations/notifications/$notificationId/read'),
        headers: headers,
      ),
    );
  }

  Future<void> markAllRead() async {
    await _request(
      (headers) => _client.post(
        _uri('/api/v1/operations/notifications/read-all'),
        headers: headers,
      ),
    );
  }

  Future<void> registerDevice({
    required String token,
    required String platform,
    String? deviceName,
    String? locale,
  }) async {
    await _request(
      (headers) => _client.post(
        _uri('/api/v1/operations/notifications/devices'),
        headers: {...headers, 'content-type': 'application/json'},
        body: jsonEncode({
          'token': token,
          'platform': platform,
          'provider': 'fcm',
          if (deviceName != null) 'deviceName': deviceName,
          if (locale != null) 'locale': locale,
        }),
      ),
    );
  }

  Future<void> unregisterDevice(String token) async {
    await _request(
      (headers) => _client.delete(
        _uri('/api/v1/operations/notifications/devices'),
        headers: {...headers, 'content-type': 'application/json'},
        body: jsonEncode({'token': token}),
      ),
    );
  }

  Future<Map<String, dynamic>> _request(
    Future<http.Response> Function(Map<String, String> headers) send,
  ) async {
    var token = await _accessTokenProvider();
    var response = await send(_headers(token));
    if (response.statusCode == 401) {
      token = await _accessTokenProvider(forceRefresh: true);
      response = await send(_headers(token));
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const NotificationException('Notifications returned invalid data.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = decoded['error'];
      throw NotificationException(
        error is String ? error : 'The notification request failed.',
      );
    }
    final data = decoded['data'];
    if (data is! Map<String, dynamic>) {
      throw const NotificationException(
        'The notification response is missing data.',
      );
    }
    return data;
  }

  Map<String, String> _headers(String token) => {
    'authorization': 'Bearer $token',
    'x-client-surface': 'app',
    'accept': 'application/json',
  };
}

class NotificationException implements Exception {
  const NotificationException(this.message);
  final String message;
}

int _number(Object? value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;
