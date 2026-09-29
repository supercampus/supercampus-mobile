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

/// Reads finance reports; the device renders them to PDF or CSV.
abstract class FinanceReportRepository {
  /// Shops and menu items for the parameter pickers.
  Future<ReportOptions> options();

  Future<FinanceReport> generate(ReportRequest request);
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

  Future<Map<String, dynamic>> _get(Uri uri) async {
    var token = await _accessTokenProvider();
    var response = await _client.get(uri, headers: _headers(token));
    if (response.statusCode == 401) {
      token = await _accessTokenProvider(forceRefresh: true);
      response = await _client.get(uri, headers: _headers(token));
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
      throw FinanceReportException(
        message.trim().isNotEmpty
            ? message
            : "The report couldn't be generated. Try again.",
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
