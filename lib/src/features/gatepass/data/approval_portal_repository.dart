import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../authentication/data/auth_http_client.dart';
import '../../authentication/data/auth_repository.dart';
import 'gatepass_repository.dart';

class ApprovalChild {
  const ApprovalChild({
    required this.userId,
    required this.name,
    required this.email,
    required this.rollNumber,
    required this.department,
    required this.year,
    required this.hostel,
    required this.room,
    this.photoUrl,
  });

  final String userId;
  final String name;
  final String email;
  final String rollNumber;
  final String department;
  final String year;
  final String hostel;
  final String room;
  final String? photoUrl;
}

class ApprovalRequest {
  const ApprovalRequest({
    required this.id,
    required this.studentUserId,
    required this.studentName,
    required this.passType,
    required this.destination,
    required this.reason,
    required this.departureAt,
    required this.returnAt,
    required this.state,
    required this.createdAt,
    this.decisionNote,
    this.qrPayload,
  });

  final String id;
  final String studentUserId;
  final String studentName;
  final String passType;
  final String destination;
  final String reason;
  final DateTime departureAt;
  final DateTime returnAt;
  final String state;
  final DateTime createdAt;
  final String? decisionNote;
  final String? qrPayload;

  bool canDecide(String viewerKind) =>
      (viewerKind == 'parent' && state == 'pending_parent') ||
      (viewerKind == 'warden' && state == 'pending_warden') ||
      (viewerKind == 'advisor_or_hod' && state == 'pending_advisor_or_hod') ||
      (viewerKind == 'principal' && state == 'pending_principal');
}

class ApprovalPortalStore {
  const ApprovalPortalStore({
    required this.viewerKind,
    required this.children,
    required this.requests,
  });

  final String viewerKind;
  final List<ApprovalChild> children;
  final List<ApprovalRequest> requests;
}

abstract interface class ApprovalPortalRepository {
  Future<ApprovalPortalStore> load();

  Future<void> decide({
    required String requestId,
    required bool approved,
    String? note,
  });
}

class BackendApprovalPortalRepository implements ApprovalPortalRepository {
  BackendApprovalPortalRepository({
    required String baseUrl,
    String? accessToken,
    AccessTokenProvider? accessTokenProvider,
    http.Client? client,
  }) : assert(accessToken != null || accessTokenProvider != null),
       _baseUri = _normalise(baseUrl),
       _accessToken = accessToken,
       _accessTokenProvider = accessTokenProvider,
       _client = client ?? createAuthHttpClient();

  final Uri _baseUri;
  final String? _accessToken;
  final AccessTokenProvider? _accessTokenProvider;
  final http.Client _client;

  @override
  Future<ApprovalPortalStore> load() async {
    final response = await _request(
      (headers) => _client.get(
        _baseUri.resolve('/api/v1/operations/gatepass/overview'),
        headers: headers,
      ),
    );
    final data = _data(response);
    return ApprovalPortalStore(
      viewerKind: _text(data['viewerKind']),
      children: _list(
        data['children'],
      ).map((value) => _child(_map(value))).toList(growable: false),
      requests: _list(
        data['requests'],
      ).map((value) => _approval(_map(value))).toList(growable: false),
    );
  }

  @override
  Future<void> decide({
    required String requestId,
    required bool approved,
    String? note,
  }) async {
    await _request(
      (headers) => _client.post(
        _baseUri.resolve(
          '/api/v1/operations/gatepass/requests/$requestId/decision',
        ),
        headers: {...headers, 'content-type': 'application/json'},
        body: jsonEncode({
          'decision': approved ? 'approved' : 'rejected',
          if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
        }),
      ),
    );
  }

  Future<http.Response> _request(
    Future<http.Response> Function(Map<String, String>) send,
  ) async {
    var token = await _token();
    var response = await send(_headers(token));
    if (response.statusCode == 401 && _accessTokenProvider != null) {
      token = await _token(forceRefresh: true);
      response = await send(_headers(token));
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      var message = 'The gatepass approval request failed.';
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final error = body['error'];
        if (error is String && error.trim().isNotEmpty) message = error;
      } catch (_) {}
      throw GatepassException(message);
    }
    return response;
  }

  Map<String, String> _headers(String token) => {
    'authorization': 'Bearer $token',
    'x-client-surface': 'app',
    'accept': 'application/json',
  };

  Future<String> _token({bool forceRefresh = false}) async {
    final provider = _accessTokenProvider;
    return provider == null
        ? _accessToken!
        : provider(forceRefresh: forceRefresh);
  }

  Map<String, dynamic> _data(http.Response response) {
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = body['data'];
    if (data is! Map<String, dynamic>) {
      throw const GatepassException('The gatepass response is incomplete.');
    }
    return data;
  }

  ApprovalChild _child(Map<String, dynamic> value) => ApprovalChild(
    userId: _text(value['userId']),
    name: _text(value['name'], fallback: 'Student'),
    email: _text(value['email']),
    rollNumber: _text(value['rollNumber'], fallback: 'Not assigned'),
    department: _text(value['department'], fallback: 'Not assigned'),
    year: _text(value['year']),
    hostel: _text(value['hostel']),
    room: _text(value['room']),
    photoUrl: _nullableText(value['photoUrl']),
  );

  ApprovalRequest _approval(Map<String, dynamic> value) => ApprovalRequest(
    id: _text(value['id']),
    studentUserId: _text(value['requesterUserId']),
    studentName: _text(value['requesterName'], fallback: 'Student'),
    passType: _text(value['passType'], fallback: 'outpass'),
    destination: _text(value['destination']),
    reason: _text(value['reason']),
    departureAt: _date(value['departureAt']),
    returnAt: _date(value['returnAt']),
    state: _text(value['state']),
    createdAt: _date(value['createdAt']),
    decisionNote: _nullableText(value['decisionNote']),
    qrPayload: _nullableText(value['qrPayload']),
  );
}

Uri _normalise(String value) {
  final uri = Uri.tryParse(value.trim().replaceAll(RegExp(r'/+$'), ''));
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    throw ArgumentError.value(value, 'baseUrl', 'Enter a valid API base URL.');
  }
  return uri;
}

Map<String, dynamic> _map(dynamic value) =>
    value is Map<String, dynamic> ? value : <String, dynamic>{};
List<dynamic> _list(dynamic value) => value is List ? value : const [];
String _text(dynamic value, {String fallback = ''}) =>
    value is String && value.trim().isNotEmpty ? value.trim() : fallback;
String? _nullableText(dynamic value) {
  final text = _text(value);
  return text.isEmpty ? null : text;
}

DateTime _date(dynamic value) =>
    DateTime.tryParse(value?.toString() ?? '')?.toLocal() ?? DateTime.now();
