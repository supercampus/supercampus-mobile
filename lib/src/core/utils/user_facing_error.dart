/// Turns a caught error into text a person can read.
///
/// Repositories throw `Exception(message)`, `StateError(message)` and typed
/// exceptions with a `message` field. Printing them with `toString()` leaks the
/// Dart class prefix ("Exception: …", "Bad state: …") and the API's internal
/// wording into the UI. Every screen that shows an error should go through
/// [userFacingError] instead.
library;

/// Shown when the server refuses a request the viewer's grants don't cover.
const accessDeniedMessage = "You don't have access to this.";

const _genericFailure = 'Something went wrong. Please try again.';

/// Dart's own `toString()` prefixes, stripped repeatedly so a wrapped
/// "Exception: Exception: …" reads cleanly too.
const _prefixes = [
  'Exception: ',
  'Bad state: ',
  'StateError: ',
  'FormatException: ',
  'HttpException: ',
  'ClientException: ',
  'TimeoutException: ',
  'Invalid argument(s): ',
];

/// Readable text for [error]. [fallback] is used when nothing useful is left.
String userFacingError(Object? error, {String fallback = _genericFailure}) {
  if (error == null) return fallback;
  var text = _messageOf(error).trim();

  var stripped = true;
  while (stripped) {
    stripped = false;
    for (final prefix in _prefixes) {
      if (text.startsWith(prefix)) {
        text = text.substring(prefix.length).trim();
        stripped = true;
      }
    }
  }

  if (text.isEmpty || text == 'Exception' || text == 'null') return fallback;
  if (isAccessDeniedText(text)) return accessDeniedMessage;
  return text;
}

/// Whether [error] is the server refusing the viewer's grants (HTTP 403).
bool isAccessDenied(Object? error) =>
    error != null && isAccessDeniedText(_messageOf(error));

/// Matches the wording the platform API and the app's repositories use for a
/// refused permission check.
bool isAccessDeniedText(String text) {
  final lower = text.toLowerCase();
  return lower.contains('cannot access the requested tenant or resource') ||
      lower.contains('(403)') ||
      lower.contains('status 403') ||
      lower.contains('forbidden') ||
      lower.contains('missing permission') ||
      lower.contains('permission denied') ||
      lower.contains('not permitted');
}

String _messageOf(Object error) {
  // Typed exceptions across the app carry a `message`; read it without
  // importing every feature's exception type into core.
  try {
    final message = (error as dynamic).message;
    if (message is String && message.trim().isNotEmpty) return message;
  } catch (_) {
    // No `message` getter; fall through to toString().
  }
  return error.toString();
}
