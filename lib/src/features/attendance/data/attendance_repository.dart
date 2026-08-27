import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../authentication/data/auth_http_client.dart';
import '../../authentication/data/auth_repository.dart';

class AttendanceRepository {
  AttendanceRepository({
    required String baseUrl,
    String? accessToken,
    AccessTokenProvider? accessTokenProvider,
    http.Client? client,
  }) : assert(
         accessToken != null || accessTokenProvider != null,
         'Provide an access token or token provider.',
       ),
       _baseUri = Uri.parse(baseUrl.trim().replaceAll(RegExp(r'/+$'), '')),
       _accessToken = accessToken,
       _accessTokenProvider = accessTokenProvider,
       _client = client ?? createAuthHttpClient();

  final Uri _baseUri;
  final String? _accessToken;
  final AccessTokenProvider? _accessTokenProvider;
  final http.Client _client;

  Uri _uri(String path, [Map<String, String>? query]) =>
      _baseUri.resolve(path).replace(queryParameters: query);

  String _localCalendarDate() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  Future<Map<String, dynamic>> summary(String studentUserId) async => _data(
    await _authorizedRequest(
      (headers) => _client.get(
        _uri('/api/v1/operations/attendance/summary/$studentUserId'),
        headers: headers,
      ),
    ),
  );

  Future<List<Map<String, dynamic>>> wards() async {
    final data = _data(
      await _authorizedRequest(
        (headers) => _client.get(
          _uri('/api/v1/operations/attendance/wards'),
          headers: headers,
        ),
      ),
    );
    return _maps(data['wards']);
  }

  /// Today's published classes assigned to the signed-in faculty member.
  ///
  /// This deliberately comes from the attendance endpoint, not the broader
  /// academic assignment context. Department and advisor visibility must never
  /// make another teacher's class available for attendance.
  Future<List<Map<String, dynamic>>> teachingClasses() async {
    final data = _data(
      await _authorizedRequest(
        (headers) => _client.get(
          // The API server runs in UTC while a campus day follows the device's
          // local calendar. Around midnight in India, relying on the server's
          // default returned yesterday's timetable and the subsequent session
          // creation was correctly rejected as belonging to another weekday.
          _uri('/api/v1/operations/attendance/classes', {
            'heldOn': _localCalendarDate(),
          }),
          headers: headers,
        ),
      ),
    );
    return _maps(data['classes']);
  }

  /// Classes assigned to the signed-in faculty member in today's published
  /// timetable.
  ///
  /// Academic assignments describe what a faculty member may teach during a
  /// term; they do not answer what is happening today. The dashboard therefore
  /// reads the principal's published timetable context and joins entries to
  /// their slots before presenting "Your classes today".
  Future<List<Map<String, dynamic>>> todayTimetableClasses() async {
    final data = _data(
      await _authorizedRequest(
        (headers) => _client.get(
          _uri('/api/v1/operations/attendance/classes', {
            'heldOn': _localCalendarDate(),
          }),
          headers: headers,
        ),
      ),
    );
    return _maps(data['classes']);
  }

  Future<List<Map<String, dynamic>>> roster({
    String? sectionId,
    List<String> sectionIds = const [],
  }) async {
    final data = _data(
      await _authorizedRequest(
        (headers) => _client.get(
          _uri('/api/v1/operations/attendance/roster', {
            if (sectionId != null && sectionId.isNotEmpty)
              'sectionId': sectionId,
            if (sectionIds.isNotEmpty) 'sectionIds': sectionIds.join(','),
          }),
          headers: headers,
        ),
      ),
    );
    return _maps(data['students']);
  }

  Future<List<Map<String, dynamic>>> sessions() async {
    final data = _data(
      await _authorizedRequest(
        (headers) => _client.get(
          _uri('/api/v1/operations/attendance/sessions'),
          headers: headers,
        ),
      ),
    );
    return _maps(data['sessions']);
  }

  Future<Map<String, dynamic>> createSession({
    required String timetableEntryId,
    required String subjectName,
    required String periodLabel,
  }) async => _data(
    await _authorizedRequest(
      (headers) => _client.post(
        _uri('/api/v1/operations/attendance/sessions'),
        headers: headers,
        body: jsonEncode({
          'timetableEntryId': _uuidOrNull(timetableEntryId),
          'subjectName': subjectName,
          'periodLabel': periodLabel,
          'heldOn': _localCalendarDate(),
        }),
      ),
      json: true,
    ),
  );

  Future<void> saveEntries(
    String sessionId,
    List<Map<String, dynamic>> entries,
  ) async {
    _data(
      await _authorizedRequest(
        (headers) => _client.put(
          _uri('/api/v1/operations/attendance/sessions/$sessionId/entries'),
          headers: headers,
          body: jsonEncode({'entries': entries}),
        ),
        json: true,
      ),
    );
  }

  Future<void> publish(String sessionId) async {
    _data(
      await _authorizedRequest(
        (headers) => _client.post(
          _uri('/api/v1/operations/attendance/sessions/$sessionId/publish'),
          headers: headers,
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> reports() async {
    final data = _data(
      await _authorizedRequest(
        (headers) => _client.get(
          _uri('/api/v1/operations/attendance/reports'),
          headers: headers,
        ),
      ),
    );
    return _maps(data['reports']);
  }

  Future<Map<String, dynamic>> createReport() async {
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 7));
    return _data(
      await _authorizedRequest(
        (headers) => _client.post(
          _uri('/api/v1/operations/attendance/reports'),
          headers: headers,
          body: jsonEncode({
            'title': 'Weekly attendance report',
            'periodStart': start.toIso8601String().substring(0, 10),
            'periodEnd': now.toIso8601String().substring(0, 10),
          }),
        ),
        json: true,
      ),
    );
  }

  Future<void> submitReport(String reportId) async {
    _data(
      await _authorizedRequest(
        (headers) => _client.post(
          _uri('/api/v1/operations/attendance/reports/$reportId/submit'),
          headers: headers,
        ),
      ),
    );
  }

  Map<String, String> _headers(String token, {bool json = false}) => {
    'authorization': 'Bearer $token',
    'x-client-surface': 'app',
    'accept': 'application/json',
    if (json) 'content-type': 'application/json',
  };

  Future<http.Response> _authorizedRequest(
    Future<http.Response> Function(Map<String, String> headers) send, {
    bool json = false,
  }) async {
    var token = await _resolveAccessToken();
    var response = await send(_headers(token, json: json));
    if (response.statusCode == 401 && _accessTokenProvider != null) {
      token = await _resolveAccessToken(forceRefresh: true);
      response = await send(_headers(token, json: json));
    }
    return response;
  }

  Future<String> _resolveAccessToken({bool forceRefresh = false}) async {
    final provider = _accessTokenProvider;
    if (provider != null) return provider(forceRefresh: forceRefresh);
    return _accessToken!;
  }

  Map<String, dynamic> _data(http.Response response) {
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const AttendanceException('Attendance returned invalid data.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = decoded['error'];
      throw AttendanceException(
        error is Map
            ? error['message']?.toString() ?? 'Request failed.'
            : 'Request failed.',
      );
    }
    final data = decoded['data'];
    if (data is! Map<String, dynamic>) {
      throw const AttendanceException('Attendance response is missing data.');
    }
    return data;
  }
}

class AttendanceException implements Exception {
  const AttendanceException(this.message);
  final String message;
}

List<Map<String, dynamic>> _maps(dynamic value) => value is List
    ? value.whereType<Map<String, dynamic>>().toList(growable: false)
    : const [];

String? _uuidOrNull(String? value) =>
    value != null && RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(value)
    ? value
    : null;

int _number(Object? value) =>
    value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;
