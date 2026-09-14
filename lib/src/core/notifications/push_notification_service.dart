import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../features/notifications/data/notification_repository.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

/// Owns the OS-facing half of push notifications.
///
/// Firebase is initialized only on configured mobile targets. The service is
/// activated after authentication so a device token can never be registered
/// without an authenticated tenant/user context.
class PushNotificationService {
  PushNotificationService._();

  static final instance = PushNotificationService._();

  static const _channel = AndroidNotificationChannel(
    'supercampus_updates',
    'SuperCampus updates',
    description: 'Campus, academic, wallet, order and gatepass updates.',
    importance: Importance.high,
  );

  final _localNotifications = FlutterLocalNotificationsPlugin();
  final _deepLinks = StreamController<String>.broadcast();
  StreamSubscription<String>? _tokenRefreshSubscription;
  NotificationRepository? _repository;
  String? _registeredToken;
  String? _pendingDeepLink;
  bool _ready = false;

  Stream<String> get deepLinks => _deepLinks.stream;
  bool get supported => !kIsWeb && Platform.isAndroid;

  Future<bool> initialize() async {
    if (_ready) return true;
    if (!supported) return false;
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      await _localNotifications.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@drawable/ic_notification'),
        ),
        onDidReceiveNotificationResponse: (response) {
          _emitDeepLink(response.payload);
        },
      );
      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(_channel);

      FirebaseMessaging.onMessage.listen(_showForegroundNotification);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleRemoteMessage);
      final initialMessage = await FirebaseMessaging.instance
          .getInitialMessage();
      if (initialMessage != null) _rememberDeepLink(initialMessage);
      _ready = true;
      return true;
    } catch (error, stack) {
      _report(error, stack, 'initializing Firebase messaging');
      return false;
    }
  }

  Future<void> activate(NotificationRepository repository) async {
    if (!supported) return;
    if (!await initialize()) return;
    _repository = repository;
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) await _registerToken(token);
      await _tokenRefreshSubscription?.cancel();
      _tokenRefreshSubscription = FirebaseMessaging.instance.onTokenRefresh
          .listen(
            (token) => unawaited(_registerToken(token)),
            onError: (Object error, StackTrace stack) {
              _report(error, stack, 'refreshing an FCM device token');
            },
          );
      final pending = _pendingDeepLink;
      _pendingDeepLink = null;
      _emitDeepLink(pending);
    } catch (error, stack) {
      _report(error, stack, 'activating Firebase messaging');
    }
  }

  Future<void> deactivate() async {
    await _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = null;
    final repository = _repository;
    final token = _registeredToken;
    _repository = null;
    _registeredToken = null;
    if (!supported || !_ready) return;
    if (repository != null && token != null) {
      try {
        await repository
            .unregisterDevice(token)
            .timeout(const Duration(seconds: 3));
      } catch (_) {
        // The backend also expires invalid tokens. Sign-out must still finish
        // when the phone is offline.
      }
    }
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {
      // A new token will be requested at the next authenticated activation.
    }
  }

  void _report(Object error, StackTrace stack, String action) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'push notifications',
        context: ErrorDescription(action),
      ),
    );
  }

  Future<void> _registerToken(String token) async {
    final repository = _repository;
    if (repository == null) return;
    try {
      await repository.registerDevice(
        token: token,
        platform: 'android',
        deviceName: Platform.localHostname,
        locale: Platform.localeName,
      );
      _registeredToken = token;
    } catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'push notifications',
          context: ErrorDescription('registering an FCM device token'),
        ),
      );
    }
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    await _localNotifications.show(
      id: message.messageId?.hashCode ?? message.hashCode,
      title: notification.title ?? 'SuperCampus',
      body: notification.body ?? '',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'supercampus_updates',
          'SuperCampus updates',
          channelDescription:
              'Campus, academic, wallet, order and gatepass updates.',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: message.data['deepLink']?.toString(),
    );
  }

  void _handleRemoteMessage(RemoteMessage message) {
    _emitDeepLink(message.data['deepLink']?.toString());
  }

  void _rememberDeepLink(RemoteMessage message) {
    final value = message.data['deepLink']?.toString();
    if (value != null && value.isNotEmpty) _pendingDeepLink = value;
  }

  void _emitDeepLink(String? value) {
    if (value == null || value.trim().isEmpty) return;
    if (_repository == null) {
      _pendingDeepLink = value;
      return;
    }
    _deepLinks.add(value.trim());
  }
}
