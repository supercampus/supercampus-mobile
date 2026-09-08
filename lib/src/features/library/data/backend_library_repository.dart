import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../authentication/data/auth_http_client.dart';
import '../../authentication/data/auth_repository.dart';
import 'library_models.dart';
import 'library_repository.dart';

class BackendLibraryRepository implements LibraryRepository {
  BackendLibraryRepository({
    required String baseUrl,
    required AccessTokenProvider accessTokenProvider,
    http.Client? client,
  }) : _baseUri = Uri.parse(baseUrl.endsWith('/') ? baseUrl : '$baseUrl/'),
       _accessTokenProvider = accessTokenProvider,
       _client = client ?? createAuthHttpClient();

  final Uri _baseUri;
  final AccessTokenProvider _accessTokenProvider;
  final http.Client _client;
  final List<LibraryVisitPass> _bookings = [];
  int _slotCapacity = 500;

  Uri _uri(String path) => _baseUri.resolve(path);

  @override
  List<LibraryVisitPass> get bookings => List.unmodifiable(_bookings);

  @override
  Future<List<LibraryVisitPass>> loadBookings() async {
    final settingsResponse = await _request(
      (headers) => _client.get(
        _uri('/api/v1/operations/library/settings'),
        headers: headers,
      ),
    );
    final settings = _data(settingsResponse);
    _slotCapacity = settings['slotCapacity'] is num
        ? (settings['slotCapacity'] as num).toInt()
        : 500;
    final response = await _request(
      (headers) => _client.get(
        _uri('/api/v1/operations/library/requests'),
        headers: headers,
      ),
    );
    final data = _data(response);
    _bookings
      ..clear()
      ..addAll(
        _list(
          data['requests'],
        ).map((item) => _pass(Map<String, dynamic>.from(item as Map))),
      );
    return bookings;
  }

  @override
  int availableSlots({
    required DateTime date,
    required int startHour,
    required int startMinute,
    required int endHour,
    required int endMinute,
  }) {
    final start = DateTime(
      date.year,
      date.month,
      date.day,
      startHour,
      startMinute,
    );
    final end = DateTime(date.year, date.month, date.day, endHour, endMinute);
    final occupied = _bookings.where((booking) {
      if (booking.status == LibraryPassStatus.cancelled ||
          booking.status == LibraryPassStatus.rejected) {
        return false;
      }
      return booking.start.isBefore(end) && booking.end.isAfter(start);
    }).length;
    return (_slotCapacity - occupied).clamp(0, _slotCapacity);
  }

  @override
  Future<LibraryVisitPass> book({
    required DateTime date,
    required int startHour,
    required int startMinute,
    required int endHour,
    required int endMinute,
    String? description,
    String? zoneName,
  }) async {
    final start = DateTime(
      date.year,
      date.month,
      date.day,
      startHour,
      startMinute,
    );
    final end = DateTime(date.year, date.month, date.day, endHour, endMinute);
    final response = await _request(
      (headers) => _client.post(
        _uri('/api/v1/operations/library/requests'),
        headers: headers,
        body: jsonEncode({
          'visitStart': start.toUtc().toIso8601String(),
          'visitEnd': end.toUtc().toIso8601String(),
          if (description != null) 'description': description,
          if (zoneName != null) 'zoneName': zoneName,
        }),
      ),
      json: true,
    );
    final pass = _pass(_data(response));
    _bookings.insert(0, pass);
    return pass;
  }

  @override
  Future<LibraryVisitPass> cancelBooking(String id) async {
    final response = await _request(
      (headers) => _client.delete(
        _uri('/api/v1/operations/library/requests/$id'),
        headers: headers,
      ),
    );
    _data(response);
    await loadBookings();
    return _bookings.firstWhere((pass) => pass.id == id);
  }

  @override
  Future<LibraryVisitPass> earlyCheckOut(String id) => cancelBooking(id);

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

  List<dynamic> _list(dynamic value) => value is List ? value : const [];

  LibraryVisitPass _pass(Map<String, dynamic> value) {
    final start = DateTime.parse(value['visitStart'] as String).toLocal();
    final end = DateTime.parse(value['visitEnd'] as String).toLocal();
    final status = switch (value['status']) {
      'pending' => LibraryPassStatus.pending,
      'approved' => LibraryPassStatus.approved,
      'rejected' => LibraryPassStatus.rejected,
      'cancelled' => LibraryPassStatus.cancelled,
      'completed' => LibraryPassStatus.used,
      _ => LibraryPassStatus.pending,
    };
    return LibraryVisitPass(
      id: value['id'] as String,
      date: DateTime(start.year, start.month, start.day),
      start: start,
      end: end,
      durationMinutes: end.difference(start).inMinutes,
      status: status,
      qrToken: value['qrPayload'] as String? ?? '',
      zoneName:
          value['zoneName'] as String? ?? 'Central Library - Reading Hall',
      description: value['description'] as String?,
    );
  }
}
