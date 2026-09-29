import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

import '../../features/notifications/data/notification_repository.dart';

/// The image a push carries: FCM's Android `imageUrl`, else the `imageUrl`
/// data field the platform sends with every broadcast. Only web addresses.
String? pushImageUrl({String? androidImageUrl, Map<String, dynamic>? data}) {
  for (final candidate in [androidImageUrl, data?['imageUrl']?.toString()]) {
    final value = candidate?.trim() ?? '';
    if (value.startsWith('https://') || value.startsWith('http://')) {
      return value;
    }
  }
  return null;
}

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

  /// While the app is open FCM does not draw the notification itself, so it
  /// is drawn here — with the broadcast's picture in Android's big-picture
  /// style when one is attached. (In the background FCM draws it, image
  /// included, from `notification.image`.)
  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    final title = notification.title ?? 'SuperCampus';
    final body = notification.body ?? '';
    final picture = await _downloadPicture(
      pushImageUrl(
        androidImageUrl: notification.android?.imageUrl,
        data: message.data,
      ),
    );
    await _localNotifications.show(
      id: message.messageId?.hashCode ?? message.hashCode,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'supercampus_updates',
          'SuperCampus updates',
          channelDescription:
              'Campus, academic, wallet, order and gatepass updates.',
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: picture == null
              ? null
              : BigPictureStyleInformation(
                  ByteArrayAndroidBitmap(picture),
                  contentTitle: title,
                  summaryText: body,
                ),
        ),
      ),
      payload: message.data['deepLink']?.toString(),
    );
  }

  /// The picture's bytes, or null when there is none or it cannot be fetched
  /// quickly — the notification is then shown without it.
  Future<Uint8List?> _downloadPicture(String? url) async {
    if (url == null) return null;
    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        return null;
      }
      if (response.bodyBytes.length > 5 * 1024 * 1024) return null;
      return response.bodyBytes;
    } catch (_) {
      return null;
    }
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
