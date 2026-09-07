import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import 'auth_repository.dart';

class SessionStore {
  SessionStore();

  static const _sessionKey = 'supercampus.auth.session.v1';
  static const _deviceKey = 'supercampus.auth.device.v1';

  String? _memoryDeviceId;

  Future<UserSession?> load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final encoded = preferences.getString(_sessionKey);
      if (encoded == null || encoded.isEmpty) return null;
      final value = jsonDecode(encoded);
      return value is Map<String, dynamic> ? UserSession.fromJson(value) : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> save(UserSession session) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_sessionKey, jsonEncode(session.toJson()));
    } catch (_) {
      // Storage can be disabled by a browser policy; the live session remains.
    }
  }

  Future<void> clear() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(_sessionKey);
    } catch (_) {
      // There is no stored session to clear when persistence is unavailable.
    }
  }

  Future<String> deviceId() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final saved = preferences.getString(_deviceKey);
      if (saved != null && saved.isNotEmpty) return saved;
      final id = _newDeviceId();
      await preferences.setString(_deviceKey, id);
      return id;
    } catch (_) {
      return _memoryDeviceId ??= _newDeviceId();
    }
  }

  String _newDeviceId() {
    final random = Random.secure();
    return List.generate(
      4,
      (_) => random.nextInt(0x100000000).toRadixString(16).padLeft(8, '0'),
    ).join();
  }
}
