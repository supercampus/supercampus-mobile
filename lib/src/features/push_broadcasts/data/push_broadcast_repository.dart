import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/access/effective_permissions.dart';
import '../../authentication/data/auth_http_client.dart';
import '../../authentication/data/auth_repository.dart';

/// Whoever may see push reach and broadcast history.
bool canViewPushBroadcasts(EffectivePermissions permissions) =>
    permissions.can('notifications', 'broadcast', 'read') ||
    permissions.can('notifications', 'broadcast', 'send');

/// Whoever may send a broadcast.
bool canSendPushBroadcasts(EffectivePermissions permissions) =>
    permissions.can('notifications', 'broadcast', 'send');

int _int(Object? value) => value is num ? value.toInt() : 0;

String? _text(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

class DevicePlatformCounts {
  const DevicePlatformCounts({this.android = 0, this.ios = 0, this.web = 0});

  factory DevicePlatformCounts.fromJson(Object? json) {
    final map = json is Map ? json : const {};
    return DevicePlatformCounts(
      android: _int(map['android']),
      ios: _int(map['ios']),
      web: _int(map['web']),
    );
  }

  final int android;
  final int ios;
  final int web;

  int get total => android + ios + web;
}

class PushDeliveryState {
  const PushDeliveryState({required this.configured, required this.message});

  factory PushDeliveryState.fromJson(Object? json) {
    final map = json is Map ? json : const {};
    return PushDeliveryState(
      configured: map['configured'] == true,
      message: _text(map['message']) ?? '',
    );
  }

  /// Whether the server can reach phones at all. When false a broadcast still
  /// lands in every recipient's in-app notification list.
  final bool configured;
  final String message;
}

class BroadcastRole {
  const BroadcastRole({
    required this.key,
    required this.name,
    required this.users,
    required this.pushEnabledUsers,
  });

  factory BroadcastRole.fromJson(Map<String, dynamic> json) => BroadcastRole(
    key: json['key']?.toString() ?? '',
    name: _text(json['name']) ?? json['key']?.toString() ?? '',
    users: _int(json['users']),
    pushEnabledUsers: _int(json['pushEnabledUsers']),
  );

  final String key;
  final String name;
  final int users;
  final int pushEnabledUsers;
}

class BroadcastAudienceStats {
  const BroadcastAudienceStats({
    required this.totalUsers,
    required this.pushEnabledUsers,
    required this.noPushTokenUsers,
    required this.totalTokens,
    required this.tokensByPlatform,
    required this.roles,
    required this.push,
    required this.canSend,
  });

  factory BroadcastAudienceStats.fromJson(Map<String, dynamic> json) =>
      BroadcastAudienceStats(
        totalUsers: _int(json['totalUsers']),
        pushEnabledUsers: _int(json['pushEnabledUsers']),
        noPushTokenUsers: _int(json['noPushTokenUsers']),
        totalTokens: _int(json['totalTokens']),
        tokensByPlatform: DevicePlatformCounts.fromJson(
          json['tokensByPlatform'],
        ),
        roles: [
          for (final role in (json['roles'] as List? ?? const []))
            if (role is Map<String, dynamic>) BroadcastRole.fromJson(role),
        ],
        push: PushDeliveryState.fromJson(json['push']),
        canSend: json['canSend'] == true,
      );

  final int totalUsers;
  final int pushEnabledUsers;
  final int noPushTokenUsers;
  final int totalTokens;
  final DevicePlatformCounts tokensByPlatform;
  final List<BroadcastRole> roles;
  final PushDeliveryState push;
  final bool canSend;
}

/// One person the audience builder can pick.
class BroadcastRecipient {
  const BroadcastRecipient({
    required this.id,
    required this.name,
    required this.email,
    this.roles = const [],
    this.department,
    this.year,
    this.roll,
    this.pushEnabled = false,
  });

  factory BroadcastRecipient.fromJson(Map<String, dynamic> json) =>
      BroadcastRecipient(
        id: json['id']?.toString() ?? '',
        name: _text(json['name']) ?? json['email']?.toString() ?? '',
        email: json['email']?.toString() ?? '',
        roles: [
          for (final role in (json['roles'] as List? ?? const []))
            role.toString(),
        ],
        department: _text(json['department']),
        year: _text(json['year']),
        roll: _text(json['roll']),
        pushEnabled: json['pushEnabled'] == true,
      );

  final String id;
  final String name;
  final String email;
  final List<String> roles;
  final String? department;
  final String? year;
  final String? roll;
  final bool pushEnabled;

  bool get isStudent => roles.contains('student');
}

class BroadcastDirectory {
  const BroadcastDirectory({
    required this.users,
    this.departments = const [],
    this.years = const [],
  });

  factory BroadcastDirectory.fromJson(Map<String, dynamic> json) =>
      BroadcastDirectory(
        users: [
          for (final user in (json['users'] as List? ?? const []))
            if (user is Map<String, dynamic>) BroadcastRecipient.fromJson(user),
        ],
        departments: [
          for (final value in (json['departments'] as List? ?? const []))
            value.toString(),
        ],
        years: [
          for (final value in (json['years'] as List? ?? const []))
            value.toString(),
        ],
      );

  final List<BroadcastRecipient> users;
  final List<String> departments;
  final List<String> years;
}

/// Who a broadcast will reach, as the server resolves it.
class BroadcastReach {
  const BroadcastReach({
    required this.recipients,
    required this.pushRecipients,
    required this.devices,
    required this.devicesByPlatform,
    this.pushConfigured = false,
    this.pushMessage = '',
  });

  factory BroadcastReach.fromJson(Map<String, dynamic> json) => BroadcastReach(
    recipients: _int(json['recipients']),
    pushRecipients: _int(json['pushRecipients']),
    devices: _int(json['devices']),
    devicesByPlatform: DevicePlatformCounts.fromJson(json['devicesByPlatform']),
    pushConfigured: json['pushConfigured'] == true,
    pushMessage: _text(json['pushMessage']) ?? '',
  );

  final int recipients;
  final int pushRecipients;
  final int devices;
  final DevicePlatformCounts devicesByPlatform;
  final bool pushConfigured;
  final String pushMessage;
}

class BroadcastDraft {
  const BroadcastDraft({
    required this.title,
    required this.body,
    this.imageUrl,
    this.roles = const [],
    this.userIds = const [],
  });

  final String title;
  final String body;
  final String? imageUrl;
  final List<String> roles;
  final List<String> userIds;

  bool get hasAudience => roles.isNotEmpty || userIds.isNotEmpty;

  Map<String, dynamic> toJson() => {
    'title': title.trim(),
    'body': body.trim(),
    if (imageUrl != null && imageUrl!.trim().isNotEmpty)
      'imageUrl': imageUrl!.trim(),
    'roles': roles,
    'userIds': userIds,
  };
}

class BroadcastRecord {
  const BroadcastRecord({
    required this.id,
    required this.title,
    required this.body,
    required this.audienceSummary,
    required this.createdAt,
    required this.sentByName,
    required this.recipients,
    required this.read,
    required this.pushStatus,
    required this.pushDevices,
    required this.pushSent,
    required this.pushFailed,
    required this.pushPending,
    this.imageUrl,
    this.sentByEmail,
  });

  factory BroadcastRecord.fromJson(Map<String, dynamic> json) {
    final push = json['push'] is Map ? json['push'] as Map : const {};
    final sentBy = json['sentBy'] is Map ? json['sentBy'] as Map : const {};
    return BroadcastRecord(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      imageUrl: _text(json['imageUrl']),
      audienceSummary: _text(json['audienceSummary']) ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '')?.toLocal() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      sentByName: _text(sentBy['name']) ?? 'Administrator',
      sentByEmail: _text(sentBy['email']),
      recipients: _int(json['recipients'] ?? json['inAppDelivered']),
      read: _int(json['read']),
      pushStatus: push['status']?.toString() ?? 'not_configured',
      pushDevices: _int(push['devices']),
      pushSent: _int(push['sent']),
      pushFailed: _int(push['failed']),
      pushPending: _int(push['pending']),
    );
  }

  final String id;
  final String title;
  final String body;
  final String? imageUrl;
  final String audienceSummary;
  final DateTime createdAt;
  final String sentByName;
  final String? sentByEmail;

  /// In-app notifications created; every recipient gets one.
  final int recipients;
  final int read;

  /// `queued`, `not_configured` or `no_devices`.
  final String pushStatus;
  final int pushDevices;
  final int pushSent;
  final int pushFailed;
  final int pushPending;

  /// A plain-words account of the phone half of the delivery.
  String get pushSummary {
    switch (pushStatus) {
      case 'not_configured':
        return 'Push not sent — not configured on the server';
      case 'no_devices':
        return 'No recipient has push turned on';
    }
    if (pushSent + pushFailed + pushPending == 0) {
      return 'Push queued for $pushDevices device${pushDevices == 1 ? '' : 's'}';
    }
    final parts = <String>[
      'Push sent to $pushSent of $pushDevices device${pushDevices == 1 ? '' : 's'}',
      if (pushFailed > 0) '$pushFailed failed',
      if (pushPending > 0) '$pushPending pending',
    ];
    return parts.join(' · ');
  }
}

class BroadcastSendResult {
  const BroadcastSendResult({
    required this.id,
    required this.inAppDelivered,
    required this.pushStatus,
    required this.pushMessage,
    required this.reach,
  });

  factory BroadcastSendResult.fromJson(Map<String, dynamic> json) {
    final push = json['push'] is Map ? json['push'] as Map : const {};
    return BroadcastSendResult(
      id: json['id']?.toString() ?? '',
      inAppDelivered: _int(json['inAppDelivered']),
      pushStatus: push['status']?.toString() ?? 'not_configured',
      pushMessage: _text(push['message']) ?? '',
      reach: BroadcastReach.fromJson(
        json['reach'] is Map<String, dynamic>
            ? json['reach'] as Map<String, dynamic>
            : const {},
      ),
    );
  }

  final String id;
  final int inAppDelivered;
  final String pushStatus;
  final String pushMessage;
  final BroadcastReach reach;
}

class PushBroadcastException implements Exception {
  const PushBroadcastException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract class PushBroadcastRepository {
  Future<BroadcastAudienceStats> audienceStats();

  Future<BroadcastDirectory> recipients();

  Future<BroadcastReach> preview({
    required List<String> roles,
    required List<String> userIds,
  });

  Future<BroadcastSendResult> send(BroadcastDraft draft);

  Future<List<BroadcastRecord>> history();
}

class BackendPushBroadcastRepository implements PushBroadcastRepository {
  BackendPushBroadcastRepository({
    required String baseUrl,
    required AccessTokenProvider accessTokenProvider,
    http.Client? client,
  }) : _baseUri = Uri.parse(baseUrl.trim().replaceAll(RegExp(r'/+$'), '')),
       _accessTokenProvider = accessTokenProvider,
       _client = client ?? createAuthHttpClient();

  final Uri _baseUri;
  final AccessTokenProvider _accessTokenProvider;
  final http.Client _client;

  static const _root = '/api/v1/operations/notifications/broadcasts';

  @override
  Future<BroadcastAudienceStats> audienceStats() async =>
      BroadcastAudienceStats.fromJson(
        await _request('GET', '$_root/audience-stats'),
      );

  @override
  Future<BroadcastDirectory> recipients() async =>
      BroadcastDirectory.fromJson(await _request('GET', '$_root/recipients'));

  @override
  Future<BroadcastReach> preview({
    required List<String> roles,
    required List<String> userIds,
  }) async => BroadcastReach.fromJson(
    await _request(
      'POST',
      '$_root/preview',
      body: {'roles': roles, 'userIds': userIds},
    ),
  );

  @override
  Future<BroadcastSendResult> send(BroadcastDraft draft) async =>
      BroadcastSendResult.fromJson(
        await _request('POST', _root, body: draft.toJson()),
      );

  @override
  Future<List<BroadcastRecord>> history() async {
    final data = await _request('GET', _root);
    return [
      for (final item in (data['broadcasts'] as List? ?? const []))
        if (item is Map<String, dynamic>) BroadcastRecord.fromJson(item),
    ];
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final uri = _baseUri.replace(path: path);
    Future<http.Response> send(String token) {
      final headers = {
        'authorization': 'Bearer $token',
        'x-client-surface': 'app',
        'accept': 'application/json',
        if (body != null) 'content-type': 'application/json',
      };
      return method == 'POST'
          ? _client.post(uri, headers: headers, body: jsonEncode(body))
          : _client.get(uri, headers: headers);
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
      throw const PushBroadcastException(
        'Your account is not allowed to send push notifications.',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = decoded?['error'];
      final message = switch (error) {
        Map() => error['message']?.toString() ?? '',
        String() => error,
        _ => decoded?['message']?.toString() ?? '',
      };
      throw PushBroadcastException(
        message.trim().isNotEmpty
            ? message
            : 'The notification service is unavailable. Try again.',
      );
    }
    final data = decoded?['data'];
    if (data is! Map<String, dynamic>) {
      throw const PushBroadcastException(
        'The notification service returned an unreadable response.',
      );
    }
    return data;
  }
}
