import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../authentication/data/auth_http_client.dart';
import '../../authentication/data/auth_repository.dart';

enum StudentAssessmentKind { semester, internal, test }

class StudentAssessment {
  const StudentAssessment({
    required this.id,
    required this.kind,
    required this.title,
    required this.marksObtained,
    required this.maximumMarks,
    this.subjectCode,
    this.semester,
    this.notes,
    this.assessedOn,
    this.updatedAt,
  });

  factory StudentAssessment.fromJson(Map<String, dynamic> json) =>
      StudentAssessment(
        id: json['id']?.toString() ?? '',
        kind: StudentAssessmentKind.values.firstWhere(
          (value) => value.name == json['assessmentKind']?.toString(),
          orElse: () => StudentAssessmentKind.test,
        ),
        title: json['title']?.toString() ?? 'Assessment',
        subjectCode: _text(json['subjectCode']),
        semester: _integer(json['semester']),
        marksObtained: _number(json['marksObtained']),
        maximumMarks: _number(json['maximumMarks']),
        notes: _text(json['notes']),
        assessedOn: DateTime.tryParse(json['assessedOn']?.toString() ?? ''),
        updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
      );

  final String id;
  final StudentAssessmentKind kind;
  final String title;
  final String? subjectCode;
  final int? semester;
  final double marksObtained;
  final double maximumMarks;
  final String? notes;
  final DateTime? assessedOn;
  final DateTime? updatedAt;

  double get percentage => maximumMarks <= 0
      ? 0
      : (marksObtained / maximumMarks * 100).clamp(0, 100);
}

abstract interface class StudentAssessmentsSource {
  Future<List<StudentAssessment>> loadAssessments();
}

class BackendStudentAssessmentsRepository implements StudentAssessmentsSource {
  BackendStudentAssessmentsRepository({
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
  Future<List<StudentAssessment>> loadAssessments() async {
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
      final message = decoded is Map && decoded['error'] is Map
          ? _text((decoded['error'] as Map)['message'])
          : null;
      throw StudentAssessmentsException(
        message ?? 'Unable to load assessment marks.',
      );
    }
    final data = decoded['data'];
    final rows = data is Map ? data['assessments'] : null;
    if (rows is! List) return const [];
    return rows
        .whereType<Map>()
        .map(
          (row) => StudentAssessment.fromJson(Map<String, dynamic>.from(row)),
        )
        .toList(growable: false);
  }

  Future<http.Response> _get(String token) => _client.get(
    _baseUri.resolve('/api/v1/operations/student/assessments'),
    headers: {
      'authorization': 'Bearer $token',
      'x-client-surface': 'app',
      'accept': 'application/json',
    },
  );
}

class StudentAssessmentsException implements Exception {
  const StudentAssessmentsException(this.message);
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
