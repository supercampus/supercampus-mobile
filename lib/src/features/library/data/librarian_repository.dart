import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../authentication/data/auth_http_client.dart';
import '../../authentication/data/auth_repository.dart';

class LibrarianRequest {
  const LibrarianRequest({
    required this.id,
    required this.studentName,
    required this.zoneName,
    required this.visitStart,
    required this.visitEnd,
    required this.status,
    this.description,
    this.decisionNote,
    this.decidedAt,
    required this.createdAt,
  });

  final String id;
  final String studentName;
  final String zoneName;
  final DateTime visitStart;
  final DateTime visitEnd;
  final String status;
  final String? description;
  final String? decisionNote;
  final DateTime? decidedAt;
  final DateTime createdAt;
}

class LibrarianSettings {
  const LibrarianSettings({
    required this.slotCapacity,
    required this.activeBookings,
    required this.completedVisits,
  });
  final int slotCapacity;
  final int activeBookings;
  final int completedVisits;
  int get available => (slotCapacity - activeBookings).clamp(0, slotCapacity);
}

class LibraryAnnouncement {
  const LibraryAnnouncement({
    required this.id,
    required this.type,
    required this.announcementDate,
    required this.title,
    required this.message,
    required this.status,
    required this.createdByName,
    required this.createdAt,
    this.bookTitle,
    this.author,
    this.attachmentName,
    this.attachmentUrl,
    this.decisionNote,
  });
  final String id;
  final String type;
  final DateTime announcementDate;
  final String title;
  final String message;
  final String status;
  final String createdByName;
  final DateTime createdAt;
  final String? bookTitle;
  final String? author;
  final String? attachmentName;
  final String? attachmentUrl;
  final String? decisionNote;
}

class LibrarianRepository {
  LibrarianRepository({
    required String baseUrl,
    required AccessTokenProvider accessTokenProvider,
    http.Client? client,
  }) : _baseUri = Uri.parse(baseUrl.endsWith('/') ? baseUrl : '$baseUrl/'),
       _accessTokenProvider = accessTokenProvider,
       _client = client ?? createAuthHttpClient();

  final Uri _baseUri;
  final AccessTokenProvider _accessTokenProvider;
  final http.Client _client;

  Uri _uri(String path) => _baseUri.resolve(path);

  Future<List<LibrarianRequest>> list() async {
    final response = await _request(
      (headers) => _client.get(
        _uri('/api/v1/operations/library/requests'),
        headers: headers,
      ),
    );
    final values = _data(response)['requests'];
    if (values is! List) return const [];
    return values
        .whereType<Map>()
        .map((value) => _requestModel(Map<String, dynamic>.from(value)))
        .toList(growable: false);
  }

  Future<LibrarianRequest> scan(String qrPayload) async {
    final response = await _request(
      (headers) => _client.post(
        _uri('/api/v1/operations/library/requests/scan'),
        headers: headers,
        body: jsonEncode({'qrPayload': qrPayload}),
      ),
      json: true,
    );
    return _requestModel(_data(response));
  }

  Future<LibrarianRequest> decide(
    String id,
    String decision, {
    String? note,
  }) async {
    final response = await _request(
      (headers) => _client.post(
        _uri('/api/v1/operations/library/requests/$id/decision'),
        headers: headers,
        body: jsonEncode({
          'decision': decision,
          if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
        }),
      ),
      json: true,
    );
    return _requestModel(_data(response));
  }

  Future<LibrarianSettings> settings() async {
    final response = await _request(
      (headers) => _client.get(
        _uri('/api/v1/operations/library/settings'),
        headers: headers,
      ),
    );
    final value = _data(response);
    return LibrarianSettings(
      slotCapacity: _integer(value['slotCapacity'], 500),
      activeBookings: _integer(value['activeBookings'], 0),
      completedVisits: _integer(value['completedVisits'], 0),
    );
  }

  Future<void> updateSlotCapacity(int value) async {
    final response = await _request(
      (headers) => _client.put(
        _uri('/api/v1/operations/library/settings'),
        headers: headers,
        body: jsonEncode({'slotCapacity': value}),
      ),
      json: true,
    );
    _data(response);
  }

  Future<List<LibraryAnnouncement>> announcements() async {
    final response = await _request(
      (headers) => _client.get(
        _uri('/api/v1/operations/library/announcements'),
        headers: headers,
      ),
    );
    final values = _data(response)['announcements'];
    if (values is! List) return const [];
    return values
        .whereType<Map>()
        .map((value) => _announcement(Map<String, dynamic>.from(value)))
        .toList(growable: false);
  }

  Future<LibraryAnnouncement> createAnnouncement({
    required String type,
    required DateTime announcementDate,
    required String title,
    required String message,
    String? bookTitle,
    String? author,
    String? attachmentName,
    String? attachmentUrl,
  }) async {
    final response = await _request(
      (headers) => _client.post(
        _uri('/api/v1/operations/library/announcements'),
        headers: headers,
        body: jsonEncode({
          'announcementType': type.trim(),
          'announcementDate': _dateOnly(announcementDate),
          'title': title,
          'message': message,
          if (bookTitle?.trim().isNotEmpty == true) 'bookTitle': bookTitle,
          if (author?.trim().isNotEmpty == true) 'author': author,
          if (attachmentName?.trim().isNotEmpty == true)
            'attachmentName': attachmentName,
          if (attachmentUrl?.trim().isNotEmpty == true)
            'attachmentUrl': attachmentUrl,
        }),
      ),
      json: true,
    );
    return _announcement(_data(response));
  }

  Future<void> decideAnnouncement(
    String id,
    String decision, {
    String? note,
  }) async {
    final response = await _request(
      (headers) => _client.post(
        _uri('/api/v1/operations/library/announcements/$id/decision'),
        headers: headers,
        body: jsonEncode({
          'decision': decision,
          if (note?.trim().isNotEmpty == true) 'note': note,
        }),
      ),
      json: true,
    );
    _data(response);
  }

  Future<http.Response> _request(
    Future<http.Response> Function(Map<String, String>) send, {
    bool json = false,
  }) async {
    var token = await _accessTokenProvider(forceRefresh: false);
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
    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = decoded['error'];
      throw StateError(
        error is Map && error['message'] is String
            ? error['message'] as String
            : 'Library request failed (${response.statusCode}).',
      );
    }
    final data = decoded['data'];
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  LibrarianRequest _requestModel(Map<String, dynamic> value) =>
      LibrarianRequest(
        id: value['id'] as String,
        studentName: value['studentName'] as String? ?? 'Student',
        zoneName:
            value['zoneName'] as String? ?? 'Central Library - Reading Hall',
        visitStart: DateTime.parse(value['visitStart'] as String).toLocal(),
        visitEnd: DateTime.parse(value['visitEnd'] as String).toLocal(),
        status: value['status'] as String? ?? 'pending',
        description: value['description'] as String?,
        decisionNote: value['decisionNote'] as String?,
        decidedAt: _dateOrNull(value['decidedAt']),
        createdAt: _dateOrNull(value['createdAt']) ?? DateTime.now(),
      );

  LibraryAnnouncement _announcement(Map<String, dynamic> value) =>
      LibraryAnnouncement(
        id: value['id'] as String,
        type: value['announcementType'] as String? ?? 'Announcement',
        announcementDate:
            _dateOrNull(value['announcementDate']) ?? DateTime.now(),
        title: value['title'] as String? ?? 'Library update',
        message: value['message'] as String? ?? '',
        status: value['status'] as String? ?? 'pending',
        createdByName: value['createdByName'] as String? ?? 'Librarian',
        createdAt: _dateOrNull(value['createdAt']) ?? DateTime.now(),
        bookTitle: value['bookTitle'] as String?,
        author: value['author'] as String?,
        attachmentName: value['attachmentName'] as String?,
        attachmentUrl: value['attachmentUrl'] as String?,
        decisionNote: value['decisionNote'] as String?,
      );

  int _integer(dynamic value, int fallback) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? fallback;

  String _dateOnly(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  DateTime? _dateOrNull(dynamic value) =>
      DateTime.tryParse(value?.toString() ?? '')?.toLocal();
}
