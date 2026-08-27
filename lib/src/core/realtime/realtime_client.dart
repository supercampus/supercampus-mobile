import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import 'realtime_event.dart';

enum RealtimeConnectionStatus { disconnected, connecting, connected }

typedef RealtimeAccessTokenProvider =
    Future<String> Function({bool forceRefresh});

/// One authenticated realtime connection shared by every mobile module.
///
/// Events are invalidation signals: REST remains authoritative and consumers
/// refetch after receiving a relevant event. Socket failures never clear local
/// state or end the user's session.
class RealtimeClient {
  RealtimeClient({
    required String baseUrl,
    required RealtimeAccessTokenProvider accessTokenProvider,
    http.Client? httpClient,
    bool? preferPolling,
  }) : _baseUri = _normalizeBaseUri(baseUrl),
       _accessTokenProvider = accessTokenProvider,
       _httpClient = httpClient ?? http.Client(),
       _preferPolling = preferPolling ?? kIsWeb;

  final Uri _baseUri;
  final RealtimeAccessTokenProvider _accessTokenProvider;
  final http.Client _httpClient;
  final bool _preferPolling;
  final Random _random = Random();
  final StreamController<RealtimeEvent> _events =
      StreamController<RealtimeEvent>.broadcast(sync: true);
  final StreamController<RealtimeConnectionStatus> _statuses =
      StreamController<RealtimeConnectionStatus>.broadcast(sync: true);
  final Set<String> _seenEventIds = <String>{};
  final List<String> _seenEventOrder = <String>[];

  WebSocketChannel? _channel;
  StreamSubscription<Object?>? _socketSubscription;
  Timer? _reconnectTimer;
  Timer? _pollTimer;
  bool _shouldRun = false;
  bool _foreground = true;
  bool _connecting = false;
  bool _disposed = false;
  int _attempt = 0;
  int _generation = 0;
  int _changeSequence = 0;
  RealtimeConnectionStatus _status = RealtimeConnectionStatus.disconnected;

  Stream<RealtimeEvent> get events => _events.stream;
  Stream<RealtimeConnectionStatus> get statuses => _statuses.stream;
  RealtimeConnectionStatus get status => _status;

  Future<void> start() async {
    if (_disposed) return;
    _shouldRun = true;
    _foreground = true;
    await _connect();
  }

  Future<void> resume() async {
    if (_disposed) return;
    _foreground = true;
    if (_shouldRun) await _connect();
  }

  Future<void> pause() => _closeSocket(keepRunning: true);

  Future<void> stop() => _closeSocket(keepRunning: false);

  Future<void> _connect() async {
    if (_disposed ||
        !_shouldRun ||
        !_foreground ||
        _connecting ||
        _channel != null) {
      return;
    }

    if (_preferPolling) {
      await _pollChanges();
      return;
    }

    _connecting = true;
    _setStatus(RealtimeConnectionStatus.connecting);
    final generation = ++_generation;
    try {
      final accessToken = await _accessTokenProvider(forceRefresh: false);
      final realtimeToken = await _requestRealtimeToken(accessToken);
      if (!_isCurrent(generation)) return;

      final socketUri = _baseUri.replace(
        scheme: _baseUri.scheme == 'https' ? 'wss' : 'ws',
        path: '/api/v1/realtime/ws',
        queryParameters: <String, String>{'access_token': realtimeToken},
      );
      final channel = WebSocketChannel.connect(socketUri);
      await channel.ready;
      if (!_isCurrent(generation)) {
        await channel.sink.close();
        return;
      }

      _channel = channel;
      _attempt = 0;
      _setStatus(RealtimeConnectionStatus.connected);
      _socketSubscription = channel.stream.listen(
        _onMessage,
        onError: (_) => _handleSocketClosed(generation),
        onDone: () => _handleSocketClosed(generation),
        cancelOnError: true,
      );
    } catch (_) {
      if (_isCurrent(generation)) _scheduleReconnect();
    } finally {
      if (generation == _generation) _connecting = false;
    }
  }

  /// Browsers use the authenticated change feed instead of a cross-origin
  /// WebSocket. It carries the same invalidation events without exposing a JWT
  /// in a socket URL, and it remains reliable behind proxies that do not keep
  /// upgrade connections alive (notably in-app and iOS web browsers).
  Future<void> _pollChanges() async {
    if (_disposed ||
        !_shouldRun ||
        !_foreground ||
        _connecting ||
        !_preferPolling) {
      return;
    }

    _connecting = true;
    _setStatus(RealtimeConnectionStatus.connecting);
    final generation = ++_generation;
    try {
      var token = await _accessTokenProvider(forceRefresh: false);
      var response = await _requestChanges(token);
      if (response.statusCode == 401) {
        token = await _accessTokenProvider(forceRefresh: true);
        response = await _requestChanges(token);
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('Realtime change feed request failed.');
      }
      if (!_isCurrent(generation)) return;

      final decoded = jsonDecode(response.body);
      final data = decoded is Map ? decoded['data'] : null;
      final changes = data is Map ? data['changes'] : null;
      if (changes is List) {
        for (final value in changes.whereType<Map>()) {
          final change = Map<String, dynamic>.from(value);
          final sequence = switch (change['sequence']) {
            final num number => number.toInt(),
            final Object value => int.tryParse(value.toString()) ?? 0,
            _ => 0,
          };
          if (sequence <= _changeSequence) continue;
          _changeSequence = sequence;
          _onMessage(<String, dynamic>{
            'id': 'change-$sequence',
            'type': change['eventType']?.toString() ?? 'realtime.change',
            'version': 1,
            'occurred_at':
                change['createdAt']?.toString() ??
                DateTime.now().toUtc().toIso8601String(),
            'data': <String, dynamic>{
              'module': change['module']?.toString() ?? '',
              'sequence': sequence,
            },
          });
        }
      }
      _attempt = 0;
      _setStatus(RealtimeConnectionStatus.connected);
    } catch (_) {
      if (_isCurrent(generation)) {
        _setStatus(RealtimeConnectionStatus.disconnected);
      }
    } finally {
      if (generation == _generation) {
        _connecting = false;
        _schedulePoll();
      }
    }
  }

  Future<http.Response> _requestChanges(String token) => _httpClient
      .get(
        _baseUri
            .resolve('/api/v1/operations/changes')
            .replace(
              queryParameters: <String, String>{
                'after': '$_changeSequence',
                'limit': '100',
              },
            ),
        headers: <String, String>{
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'x-client-surface': 'app',
        },
      )
      .timeout(const Duration(seconds: 10));

  void _schedulePoll() {
    if (_disposed || !_shouldRun || !_foreground || !_preferPolling) return;
    _pollTimer?.cancel();
    _pollTimer = Timer(
      const Duration(seconds: 5),
      () => unawaited(_pollChanges()),
    );
  }

  Future<String> _requestRealtimeToken(String accessToken) async {
    final response = await _httpClient
        .post(
          _baseUri.resolve('/api/auth/realtime-token'),
          headers: <String, String>{
            'Authorization': 'Bearer $accessToken',
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'x-client-surface': 'app',
          },
          body: '{}',
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode == 401) {
      final freshToken = await _accessTokenProvider(forceRefresh: true);
      final retry = await _httpClient
          .post(
            _baseUri.resolve('/api/auth/realtime-token'),
            headers: <String, String>{
              'Authorization': 'Bearer $freshToken',
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'x-client-surface': 'app',
            },
            body: '{}',
          )
          .timeout(const Duration(seconds: 10));
      return _readRealtimeToken(retry);
    }
    return _readRealtimeToken(response);
  }

  String _readRealtimeToken(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Realtime token request failed.');
    }
    final decoded = jsonDecode(response.body);
    final data = decoded is Map ? decoded['data'] : null;
    final token = data is Map ? data['token']?.toString().trim() : null;
    if (token == null || token.isEmpty) {
      throw StateError('Realtime token response is invalid.');
    }
    return token;
  }

  void _onMessage(Object? message) {
    final event = RealtimeEvent.tryParse(message);
    if (event == null || _seenEventIds.contains(event.id)) return;
    _seenEventIds.add(event.id);
    _seenEventOrder.add(event.id);
    if (_seenEventOrder.length > 256) {
      _seenEventIds.remove(_seenEventOrder.removeAt(0));
    }
    _events.add(event);
  }

  void _handleSocketClosed(int generation) {
    if (generation != _generation) return;
    _socketSubscription = null;
    _channel = null;
    _connecting = false;
    _setStatus(RealtimeConnectionStatus.disconnected);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _setStatus(RealtimeConnectionStatus.disconnected);
    if (_disposed || !_shouldRun || !_foreground) return;
    _reconnectTimer?.cancel();
    final seconds = min(30, 1 << min(_attempt, 5));
    _attempt++;
    final jitter = _random.nextInt(500);
    _reconnectTimer = Timer(
      Duration(seconds: seconds, milliseconds: jitter),
      () => unawaited(_connect()),
    );
  }

  Future<void> _closeSocket({required bool keepRunning}) async {
    if (!keepRunning) _shouldRun = false;
    _foreground = keepRunning ? false : _foreground;
    _generation++;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _pollTimer?.cancel();
    _pollTimer = null;
    final subscription = _socketSubscription;
    final channel = _channel;
    _socketSubscription = null;
    _channel = null;
    _connecting = false;
    await subscription?.cancel();
    await channel?.sink.close();
    _setStatus(RealtimeConnectionStatus.disconnected);
  }

  bool _isCurrent(int generation) =>
      generation == _generation && !_disposed && _shouldRun && _foreground;

  void _setStatus(RealtimeConnectionStatus value) {
    if (_status == value || _disposed) return;
    _status = value;
    _statuses.add(value);
  }

  Future<void> dispose() async {
    if (_disposed) return;
    await stop();
    _disposed = true;
    _httpClient.close();
    await _events.close();
    await _statuses.close();
  }

  static Uri _normalizeBaseUri(String value) {
    var uri = Uri.parse(value);
    if (kIsWeb &&
        (uri.host == '127.0.0.1' || uri.host == 'localhost') &&
        (Uri.base.host == '127.0.0.1' || Uri.base.host == 'localhost')) {
      uri = uri.replace(host: Uri.base.host);
    }
    return uri;
  }
}
