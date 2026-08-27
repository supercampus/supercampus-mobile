import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../authentication/data/auth_http_client.dart';
import '../../authentication/data/auth_repository.dart';

enum GateDirection { entry, exit }

extension GateDirectionLabel on GateDirection {
  String get apiValue => name;
  String get label => this == GateDirection.entry ? 'Gate in' : 'Gate out';
}

class SecurityGateMovement {
  const SecurityGateMovement({
    required this.id,
    required this.userId,
    required this.direction,
    required this.checkpoint,
    required this.createdAt,
    this.requestId,
    this.visitorPassId,
    this.holderName,
    this.passType,
    this.validUntil,
  });

  final String id;
  final String userId;
  final String? requestId;
  final String? visitorPassId;
  final GateDirection direction;
  final String checkpoint;
  final DateTime createdAt;
  final String? holderName;
  final String? passType;
  final DateTime? validUntil;
}

abstract interface class SecurityGateRepository {
  Future<List<SecurityGateMovement>> recentMovements();

  Future<SecurityGateMovement> scan({
    required String qrPayload,
    required GateDirection direction,
    required String checkpoint,
  });
}

class SecurityGateException implements Exception {
  const SecurityGateException(this.message);

  final String message;

  @override
  String toString() => message;
}

class BackendSecurityGateRepository implements SecurityGateRepository {
  BackendSecurityGateRepository({
    required String baseUrl,
    required AccessTokenProvider accessTokenProvider,
    http.Client? client,
  }) : _baseUri = _normalizeBaseUri(baseUrl),
       _accessTokenProvider = accessTokenProvider,
       _client = client ?? createAuthHttpClient();

  final Uri _baseUri;
  final AccessTokenProvider _accessTokenProvider;
  final http.Client _client;

  Uri _uri(String path) => _baseUri.resolve(path);

  @override
  Future<List<SecurityGateMovement>> recentMovements() async {
    final response = await _authorizedRequest(
      (headers) => _client.get(
        _uri('/api/v1/operations/gatepass/overview'),
        headers: headers,
      ),
    );
    final data = _data(response);
    final movements = data['movements'];
    if (movements is! List) return const [];
    return movements
        .whereType<Map<String, dynamic>>()
        .map(_movement)
        .take(30)
        .toList(growable: false);
  }

  @override
  Future<SecurityGateMovement> scan({
    required String qrPayload,
    required GateDirection direction,
    required String checkpoint,
  }) async {
    final code = qrPayload.trim();
    if (code.isEmpty) {
      throw const SecurityGateException('Scan a gatepass QR first.');
    }
    final response = await _authorizedRequest(
      (headers) => _client.post(
        _uri('/api/v1/operations/gatepass/scan'),
        headers: headers,
        body: jsonEncode({
          'qrPayload': code,
          'direction': direction.apiValue,
          'checkpoint': checkpoint.trim(),
        }),
      ),
      json: true,
    );
    return _movement(_data(response));
  }

  SecurityGateMovement _movement(Map<String, dynamic> value) {
    return SecurityGateMovement(
      id: _text(value['id']),
      userId: _text(value['userId'], fallback: 'Campus visitor'),
      requestId: _nullableText(value['requestId']),
      visitorPassId: _nullableText(value['visitorPassId']),
      holderName: _nullableText(value['holderName']),
      passType: _nullableText(value['passType']),
      validUntil: DateTime.tryParse(
        value['validUntil']?.toString() ?? '',
      )?.toLocal(),
      direction: _text(value['direction']) == 'exit'
          ? GateDirection.exit
          : GateDirection.entry,
      checkpoint: _text(value['checkpoint'], fallback: 'Main gate'),
      createdAt:
          DateTime.tryParse(value['createdAt']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
    );
  }

  Future<http.Response> _authorizedRequest(
    Future<http.Response> Function(Map<String, String> headers) send, {
    bool json = false,
  }) async {
    var token = await _accessTokenProvider();
    var response = await send(_headers(token, json: json));
    if (response.statusCode == 401) {
      token = await _accessTokenProvider(forceRefresh: true);
      response = await send(_headers(token, json: json));
    }
    return response;
  }

  Map<String, String> _headers(String token, {bool json = false}) => {
    'authorization': 'Bearer $token',
    'x-client-surface': 'app',
    'accept': 'application/json',
    if (json) 'content-type': 'application/json',
  };

  Map<String, dynamic> _data(http.Response response) {
    Map<String, dynamic>? body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      body = null;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = body?['error'];
      final serverMessage = switch (error) {
        final String value => value,
        final Map<String, dynamic> value => _text(value['message']),
        _ => '',
      };
      final fallback = switch (response.statusCode) {
        403 => 'This account does not have gate-scanner access.',
        404 => 'This QR is invalid, expired, or already unavailable.',
        409 => 'This gate movement conflicts with the current pass state.',
        >= 500 => 'The gatepass service is temporarily unavailable.',
        _ => 'The gatepass scan failed (${response.statusCode}).',
      };
      throw SecurityGateException(
        serverMessage.trim().isEmpty ? fallback : serverMessage,
      );
    }
    final data = body?['data'];
    if (data is! Map<String, dynamic>) {
      throw const SecurityGateException(
        'The gatepass service returned an incomplete response.',
      );
    }
    return data;
  }
}

class MockSecurityGateRepository implements SecurityGateRepository {
  final List<SecurityGateMovement> _movements = [];

  @override
  Future<List<SecurityGateMovement>> recentMovements() async =>
      List.unmodifiable(_movements);

  @override
  Future<SecurityGateMovement> scan({
    required String qrPayload,
    required GateDirection direction,
    required String checkpoint,
  }) async {
    if (qrPayload.trim().isEmpty) {
      throw const SecurityGateException('Scan a gatepass QR first.');
    }
    final movement = SecurityGateMovement(
      id: 'scan-${DateTime.now().millisecondsSinceEpoch}',
      userId: 'Demo campus member',
      direction: direction,
      checkpoint: checkpoint,
      createdAt: DateTime.now(),
    );
    _movements.insert(0, movement);
    return movement;
  }
}

Uri _normalizeBaseUri(String value) {
  final trimmed = value.trim().replaceAll(RegExp(r'/+$'), '');
  final uri = Uri.tryParse(trimmed);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    throw ArgumentError.value(value, 'baseUrl', 'Enter a valid API base URL.');
  }
  return uri;
}

String _text(dynamic value, {String fallback = ''}) =>
    value is String && value.trim().isNotEmpty ? value.trim() : fallback;
String? _nullableText(dynamic value) {
  final text = _text(value);
  return text.isEmpty ? null : text;
}
