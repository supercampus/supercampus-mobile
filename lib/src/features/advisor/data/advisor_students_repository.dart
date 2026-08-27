import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../authentication/data/auth_http_client.dart';
import '../../authentication/data/auth_repository.dart';

class AdvisorStudent {
  const AdvisorStudent({
    required this.userId,
    required this.studentId,
    required this.number,
    required this.name,
    required this.departmentCode,
    required this.status,
    this.email,
    this.phone,
    this.departmentName,
    this.programmeName,
    this.academicYear,
    this.sectionName,
    this.campusName,
    this.photoUrl,
    this.profile = const {},
  });

  factory AdvisorStudent.fromJson(Map<String, dynamic> json) => AdvisorStudent(
    userId: json['studentUserId']?.toString() ?? '',
    studentId: json['studentId']?.toString() ?? '',
    number: json['studentNumber']?.toString() ?? '',
    name: json['studentName']?.toString() ?? 'Student',
    departmentCode: json['departmentCode']?.toString() ?? '',
    status: json['status']?.toString() ?? '',
    email: _text(json['email']),
    phone: _text(json['phone']),
    departmentName: _text(json['departmentName']),
    programmeName: _text(json['programmeName']),
    academicYear: _text(json['academicYear']),
    sectionName: _text(json['sectionName']),
    campusName: _text(json['campusName']),
    photoUrl: _text(json['photoUrl']),
    profile: json['profile'] is Map
        ? Map<String, dynamic>.from(json['profile'] as Map)
        : const {},
  );

  final String userId;
  final String studentId;
  final String number;
  final String name;
  final String departmentCode;
  final String status;
  final String? email;
  final String? phone;
  final String? departmentName;
  final String? programmeName;
  final String? academicYear;
  final String? sectionName;
  final String? campusName;
  final String? photoUrl;
  final Map<String, dynamic> profile;
}

enum AdvisorAssessmentKind { semester, internal, test }

class AdvisorAssessment {
  const AdvisorAssessment({
    required this.id,
    required this.kind,
    required this.title,
    required this.marksObtained,
    required this.maximumMarks,
    this.semester,
    this.notes,
    this.assessedOn,
  });

  factory AdvisorAssessment.fromJson(Map<String, dynamic> json) =>
      AdvisorAssessment(
        id: json['id']?.toString() ?? '',
        kind: AdvisorAssessmentKind.values.firstWhere(
          (value) => value.name == json['assessmentKind']?.toString(),
          orElse: () => AdvisorAssessmentKind.test,
        ),
        title: json['title']?.toString() ?? 'Assessment',
        semester: _integer(json['semester']),
        marksObtained: _number(json['marksObtained']),
        maximumMarks: _number(json['maximumMarks']),
        notes: _text(json['notes']),
        assessedOn: DateTime.tryParse(json['assessedOn']?.toString() ?? ''),
      );

  final String id;
  final AdvisorAssessmentKind kind;
  final String title;
  final int? semester;
  final double marksObtained;
  final double maximumMarks;
  final String? notes;
  final DateTime? assessedOn;
}

class AdvisorAssessmentInput {
  const AdvisorAssessmentInput({
    required this.kind,
    required this.title,
    required this.marksObtained,
    required this.maximumMarks,
    this.semester,
    this.notes,
    this.assessedOn,
  });

  final AdvisorAssessmentKind kind;
  final String title;
  final int? semester;
  final double marksObtained;
  final double maximumMarks;
  final String? notes;
  final DateTime? assessedOn;

  Map<String, dynamic> toJson() => {
    'assessmentKind': kind.name,
    'title': title.trim(),
    'semester': semester,
    'marksObtained': marksObtained,
    'maximumMarks': maximumMarks,
    'notes': _text(notes),
    'assessedOn': assessedOn?.toIso8601String().split('T').first,
  };
}

abstract interface class AdvisorStudentsSource {
  Future<List<AdvisorStudent>> loadStudents();

  Future<List<AdvisorAssessment>> loadAssessments(String studentId);

  Future<AdvisorAssessment> saveAssessment(
    String studentId,
    AdvisorAssessmentInput input, {
    String? assessmentId,
  });
}

class BackendAdvisorStudentsRepository implements AdvisorStudentsSource {
  BackendAdvisorStudentsRepository({
    required String baseUrl,
    required AccessTokenProvider accessTokenProvider,
    http.Client? client,
  }) : _baseUri = Uri.parse(baseUrl.trim().replaceAll(RegExp(r'/+$'), '')),
       _accessTokenProvider = accessTokenProvider,
       _client = client ?? createAuthHttpClient();

  final Uri _baseUri;
  final AccessTokenProvider _accessTokenProvider;
  final http.Client _client;

  @override
  Future<List<AdvisorStudent>> loadStudents() async {
    var token = await _accessTokenProvider();
    var response = await _get(token);
    if (response.statusCode == 401) {
      token = await _accessTokenProvider(forceRefresh: true);
      response = await _get(token);
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> ||
        response.statusCode < 200 ||
        response.statusCode >= 300) {
      throw const AdvisorStudentsException('Unable to load your students.');
    }
    final data = decoded['data'];
    final rows = data is Map ? data['students'] : null;
    if (rows is! List) return const [];
    return rows
        .whereType<Map>()
        .map((row) => AdvisorStudent.fromJson(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  @override
  Future<List<AdvisorAssessment>> loadAssessments(String studentId) async {
    var token = await _accessTokenProvider();
    var response = await _getAssessments(token, studentId);
    if (response.statusCode == 401) {
      token = await _accessTokenProvider(forceRefresh: true);
      response = await _getAssessments(token, studentId);
    }
    final decoded = _decodeResponse(response);
    final data = decoded['data'];
    final rows = data is Map ? data['assessments'] : null;
    if (rows is! List) return const [];
    return rows
        .whereType<Map>()
        .map(
          (row) => AdvisorAssessment.fromJson(Map<String, dynamic>.from(row)),
        )
        .toList(growable: false);
  }

  @override
  Future<AdvisorAssessment> saveAssessment(
    String studentId,
    AdvisorAssessmentInput input, {
    String? assessmentId,
  }) async {
    var token = await _accessTokenProvider();
    var response = await _sendAssessment(token, studentId, input, assessmentId);
    if (response.statusCode == 401) {
      token = await _accessTokenProvider(forceRefresh: true);
      response = await _sendAssessment(token, studentId, input, assessmentId);
    }
    final decoded = _decodeResponse(response);
    final data = decoded['data'];
    if (data is! Map) {
      throw const AdvisorStudentsException('Unable to save assessment marks.');
    }
    return AdvisorAssessment.fromJson(Map<String, dynamic>.from(data));
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> ||
        response.statusCode < 200 ||
        response.statusCode >= 300) {
      final message = decoded is Map && decoded['error'] is Map
          ? _text((decoded['error'] as Map)['message'])
          : null;
      throw AdvisorStudentsException(
        message ?? 'Unable to update student assessments.',
      );
    }
    return decoded;
  }

  Future<http.Response> _get(String token) => _client.get(
    _baseUri.resolve('/api/v1/operations/advisor/students'),
    headers: {
      'authorization': 'Bearer $token',
      'x-client-surface': 'app',
      'accept': 'application/json',
    },
  );

  Future<http.Response> _getAssessments(String token, String studentId) =>
      _client.get(_assessmentsUri(studentId), headers: _headers(token));

  Future<http.Response> _sendAssessment(
    String token,
    String studentId,
    AdvisorAssessmentInput input,
    String? assessmentId,
  ) {
    final assessmentsUri = _assessmentsUri(studentId);
    final uri = assessmentId == null
        ? assessmentsUri
        : Uri.parse('$assessmentsUri/$assessmentId');
    final body = jsonEncode(input.toJson());
    return assessmentId == null
        ? _client.post(uri, headers: _headers(token), body: body)
        : _client.put(uri, headers: _headers(token), body: body);
  }

  Uri _assessmentsUri(String studentId) => _baseUri.resolve(
    '/api/v1/operations/advisor/students/$studentId/assessments',
  );

  Map<String, String> _headers(String token) => {
    'authorization': 'Bearer $token',
    'x-client-surface': 'app',
    'accept': 'application/json',
    'content-type': 'application/json',
  };
}

class AdvisorStudentsException implements Exception {
  const AdvisorStudentsException(this.message);
  final String message;
}

String? _text(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

double _number(Object? value) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

int? _integer(Object? value) =>
    value is num ? value.toInt() : int.tryParse('$value');
