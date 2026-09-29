import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../authentication/data/auth_http_client.dart';
import '../../authentication/data/auth_repository.dart';
import 'finance_report.dart';

class FinanceReportException implements Exception {
  const FinanceReportException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The server has no outbound email configured, so nothing was sent.
class ReportEmailUnavailable extends FinanceReportException {
  const ReportEmailUnavailable([
    super.message = 'Email is not configured on the server',
  ]);
}

/// Reads finance reports; the device renders them to PDF or CSV.
abstract class FinanceReportRepository {
  /// Shops and menu items for the parameter pickers.
  Future<ReportOptions> options();

  Future<FinanceReport> generate(ReportRequest request);

  /// Emails the report's files to [recipients]; the server writes the
  /// summary into the message itself.
  Future<ReportEmailResult> email(
    ReportRequest request, {
    required List<String> recipients,
    required List<ReportAttachment> attachments,
    String? note,
  });
}

class BackendFinanceReportRepository implements FinanceReportRepository {
  BackendFinanceReportRepository({
    required String baseUrl,
    required AccessTokenProvider accessTokenProvider,
    http.Client? client,
  }) : _baseUri = Uri.parse(baseUrl.replaceFirst(RegExp(r'/$'), '')),
       _accessTokenProvider = accessTokenProvider,
       _client = client ?? createAuthHttpClient();

  final Uri _baseUri;
  final AccessTokenProvider _accessTokenProvider;
  final http.Client _client;

  @override
  Future<ReportOptions> options() async {
    final data = await _get(
      _baseUri.replace(path: '/api/v1/operations/reports/options'),
    );
    return ReportOptions.fromJson(data);
  }

  @override
  Future<FinanceReport> generate(ReportRequest request) async {
    final data = await _get(
      _baseUri.replace(
        path: '/api/v1/operations/reports/${Uri.encodeComponent(request.kind)}',
        queryParameters: request.toQuery(),
      ),
    );
    return FinanceReport.fromJson(data);
  }

  @override
  Future<ReportEmailResult> email(
    ReportRequest request, {
    required List<String> recipients,
    required List<ReportAttachment> attachments,
    String? note,
  }) async {
    final uri = _baseUri.replace(
      path:
          '/api/v1/operations/reports/${Uri.encodeComponent(request.kind)}/email',
    );
    final body = jsonEncode({
      ...request.toQuery(),
      'recipients': recipients,
      'attachments': [
        for (final file in attachments)
          {
            'filename': file.fileName,
            'contentType': file.contentType,
            'base64': base64Encode(file.bytes),
          },
      ],
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    });
    final data = await _send(
      (token) => _client.post(
        uri,
        headers: {..._headers(token), 'content-type': 'application/json'},
        body: body,
      ),
      failure: "The report couldn't be emailed. Try again.",
    );
    return ReportEmailResult.fromJson(data);
  }

  Future<Map<String, dynamic>> _get(Uri uri) => _send(
    (token) => _client.get(uri, headers: _headers(token)),
    failure: "The report couldn't be generated. Try again.",
  );

  Future<Map<String, dynamic>> _send(
    Future<http.Response> Function(String token) request, {
    required String failure,
  }) async {
    var token = await _accessTokenProvider();
    var response = await request(token);
    if (response.statusCode == 401) {
      token = await _accessTokenProvider(forceRefresh: true);
      response = await request(token);
    }
    Map<String, dynamic>? body;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) body = decoded;
    } catch (_) {}
    if (response.statusCode == 403) {
      throw const FinanceReportException(
        'Your account is not allowed to generate finance reports.',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = body?['error'];
      final message = switch (error) {
        Map() => error['message']?.toString() ?? '',
        String() => error,
        _ => body?['message']?.toString() ?? '',
      };
      // A 503 about email means no mail transport; any other 503 is a
      // passing outage, reported like every other failure.
      if (response.statusCode == 503 &&
          message.toLowerCase().contains('email')) {
        throw ReportEmailUnavailable(message.trim());
      }
      throw FinanceReportException(
        message.trim().isNotEmpty ? message : failure,
      );
    }
    final data = body?['data'];
    if (data is! Map<String, dynamic>) {
      throw const FinanceReportException(
        'The report service returned an unreadable response.',
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
