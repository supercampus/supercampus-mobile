import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Why an alert could not be set, or [none] when it was.
enum AlertFailure {
  none,

  /// The user has notifications turned off for the app.
  denied,

  /// No notification support on this platform — desktop, web, a test.
  unsupported,

  /// The chosen moment has already passed.
  inThePast,
}

/// Schedules the one-off reminders a student sets against an exam.
///
/// The reminder is an operating-system notification rather than anything the
/// app draws, so it arrives whether or not SuperCampus is running — which is
/// the entire point of setting one the night before an exam.
///
/// Nothing is written to app storage: the pending notifications the OS is
/// already holding *are* the record, and [init] reads them back so a restart
/// still shows which exams have an alert on them.
class ExamAlertService extends ChangeNotifier {
  ExamAlertService._();

  static final ExamAlertService instance = ExamAlertService._();

  final _plugin = FlutterLocalNotificationsPlugin();

  /// Exam id to the moment its alert fires.
  final Map<String, DateTime> _alerts = {};

  bool _ready = false;

  static const _channel = AndroidNotificationDetails(
    'exam_alerts',
    'Exam alerts',
    channelDescription: 'Reminders you set for upcoming exams.',
    importance: Importance.max,
    priority: Priority.high,
  );

  static const _details = NotificationDetails(
    android: _channel,
    iOS: DarwinNotificationDetails(),
  );

  /// Safe to call more than once, and safe to call where there is no plugin
  /// at all — a failure here only means alerts cannot be set, so it must not
  /// take the app down with it.
  Future<void> init() async {
    if (_ready) return;

    try {
      tzdata.initializeTimeZones();

      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            // Asked for at the moment the student sets their first alert
            // instead, where the prompt has an obvious reason behind it.
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );

      await _restorePending();
      _ready = true;
    } catch (error, stack) {
      // A test binding or a desktop build has no plugin behind the channel.
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'exam alerts',
          context: ErrorDescription('initialising exam alerts'),
        ),
      );
    }
  }

  /// The OS is the source of truth for what is still pending, so a reinstall
  /// of the app's memory does not leave alerts the student cannot see.
  Future<void> _restorePending() async {
    final pending = await _plugin.pendingNotificationRequests();

    for (final request in pending) {
      final payload = request.payload;
      if (payload == null) continue;

      final parts = payload.split('|');
      if (parts.length != 2) continue;

      final millis = int.tryParse(parts[1]);
      if (millis == null) continue;

      _alerts[parts[0]] = DateTime.fromMillisecondsSinceEpoch(millis);
    }

    if (_alerts.isNotEmpty) notifyListeners();
  }

  /// When [examId]'s alert will fire, or null if it has none.
  DateTime? alertFor(String examId) => _alerts[examId];

  /// Replaces any alert already on [examId]. Returns [AlertFailure.none] when
  /// the notification is scheduled.
  Future<AlertFailure> setAlert({
    required String examId,
    required String title,
    required String body,
    required DateTime at,
  }) async {
    if (!at.isAfter(DateTime.now())) return AlertFailure.inThePast;
    if (!_ready) return AlertFailure.unsupported;

    try {
      if (!await _ensurePermission()) return AlertFailure.denied;

      await _plugin.zonedSchedule(
        id: _idFor(examId),
        title: title,
        body: body,
        // The instant, expressed in UTC. A one-off alert wants an exact
        // moment, and taking it as UTC keeps that moment right without the
        // app having to know which zone the phone is in.
        scheduledDate: tz.TZDateTime.from(at, tz.UTC),
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: '$examId|${at.millisecondsSinceEpoch}',
      );

      _alerts[examId] = at;
      notifyListeners();
      return AlertFailure.none;
    } catch (_) {
      return AlertFailure.unsupported;
    }
  }

  Future<void> cancelAlert(String examId) async {
    if (_alerts.remove(examId) == null) return;
    notifyListeners();

    try {
      await _plugin.cancel(id: _idFor(examId));
    } catch (_) {
      // Nothing was scheduled, so nothing is left to clean up.
    }
  }

  /// Asks for whatever this platform needs the first time an alert is set.
  /// Exact alarms are asked for too, but not insisted on — Android downgrades
  /// them to inexact ones, which is a late reminder rather than none.
  Future<bool> _ensurePermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      await android.requestExactAlarmsPermission();
      return granted ?? true;
    }

    final darwin = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();

    if (darwin != null) {
      final granted = await darwin.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }

    return true;
  }

  /// Notification ids are 32-bit signed, and the exam id is a string.
  int _idFor(String examId) => examId.hashCode & 0x7fffffff;
}
