import 'package:http/http.dart' as http;

http.Client createPlatformAuthHttpClient() => _SessionCookieClient();

class _SessionCookieClient extends http.BaseClient {
  final http.Client _inner = http.Client();
  String? _sessionCookie;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final sessionCookie = _sessionCookie;
    if (sessionCookie != null && request.url.path.startsWith('/api/auth/')) {
      request.headers['cookie'] = 'sc_session=$sessionCookie';
    }

    final response = await _inner.send(request);
    final setCookie = response.headers['set-cookie'];
    if (setCookie != null) {
      final match = RegExp(
        r'(?:^|,\s*)sc_session=([^;,\s]*)',
      ).firstMatch(setCookie);
      if (match != null) {
        final value = match.group(1);
        _sessionCookie = value == null || value.isEmpty ? null : value;
      }
    }
    return response;
  }

  @override
  void close() => _inner.close();
}
