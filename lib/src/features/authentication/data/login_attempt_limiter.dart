import 'dart:convert';
import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

/// Locks the sign-in screen after repeated incorrect passwords.
///
/// The third wrong password inside [failureWindow] locks sign-in for
/// [baseLockout]; every further wrong password doubles the lock, up to
/// [maxLockout]. A successful sign-in clears the record. The same policy is
/// enforced per account by the platform API, so this lock is the user-facing
/// half of that rule, not the security boundary.
///
/// State is persisted, so reloading the page or restarting the app does not
/// reset the lock.
class LoginAttemptLimiter {
  LoginAttemptLimiter({
    this.maxFailures = 3,
    this.baseLockout = const Duration(seconds: 30),
    this.maxLockout = const Duration(minutes: 15),
    this.failureWindow = const Duration(minutes: 15),
    DateTime Function()? clock,
    SharedPreferences? preferences,
  }) : _clock = clock ?? DateTime.now,
       _preferences = preferences;

  static const _storageKey = 'auth.login_attempts.v1';

  final int maxFailures;
  final Duration baseLockout;
  final Duration maxLockout;
  final Duration failureWindow;
  final DateTime Function() _clock;
  SharedPreferences? _preferences;

  int _failures = 0;
  DateTime? _windowStartedAt;
  DateTime? _lockedUntil;

  /// Restores the persisted record. Safe to skip: without it the limiter
  /// still works for the lifetime of this screen.
  Future<void> restore() async {
    try {
      _preferences ??= await SharedPreferences.getInstance();
      final raw = _preferences!.getString(_storageKey);
      if (raw == null) return;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      _failures = (json['failures'] as num?)?.toInt() ?? 0;
      _windowStartedAt = _parse(json['windowStartedAt']);
      _lockedUntil = _parse(json['lockedUntil']);
    } catch (_) {
      // Unreadable or unavailable storage: start from a clean record.
    }
  }

  bool get isLocked => lockoutRemaining > Duration.zero;

  Duration get lockoutRemaining {
    final until = _lockedUntil;
    if (until == null) return Duration.zero;
    final remaining = until.difference(_clock());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Wrong passwords still allowed before the next lock.
  int get attemptsRemaining {
    _expireWindow();
    return math.max(0, maxFailures - _failures);
  }

  /// Records a wrong password and returns the lock it triggered, if any.
  Duration? recordFailure() {
    _expireWindow();
    final now = _clock();
    _windowStartedAt ??= now;
    _failures++;
    Duration? lockout;
    if (_failures >= maxFailures) {
      lockout = lockoutFor(_failures);
      _lockedUntil = now.add(lockout);
    }
    _persist();
    return lockout;
  }

  void recordSuccess() {
    _failures = 0;
    _windowStartedAt = null;
    _lockedUntil = null;
    _persist();
  }

  /// Lock applied when the [failures]th wrong password is recorded.
  Duration lockoutFor(int failures) {
    final doublings = math.max(0, failures - maxFailures);
    // Cap the exponent so the shift cannot overflow before the clamp.
    final seconds = baseLockout.inSeconds * (1 << math.min(doublings, 20));
    return Duration(seconds: math.min(seconds, maxLockout.inSeconds));
  }

  void _expireWindow() {
    final started = _windowStartedAt;
    if (started == null || isLocked) return;
    if (_clock().difference(started) >= failureWindow) {
      _failures = 0;
      _windowStartedAt = null;
      _lockedUntil = null;
    }
  }

  void _persist() {
    final preferences = _preferences;
    if (preferences == null) return;
    final value = jsonEncode({
      'failures': _failures,
      'windowStartedAt': _windowStartedAt?.toUtc().toIso8601String(),
      'lockedUntil': _lockedUntil?.toUtc().toIso8601String(),
    });
    preferences.setString(_storageKey, value).ignore();
  }

  static DateTime? _parse(Object? value) =>
      value is String ? DateTime.tryParse(value)?.toLocal() : null;
}
