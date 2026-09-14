import 'dart:async';

import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/core/notifications/exam_alert_service.dart';
import 'src/core/notifications/push_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Reads back the exam alerts the OS is still holding, so the app knows
  // which exams already have one. Not awaited: nothing on the first frame
  // depends on it, and a student who opens an exam before it finishes just
  // sees the alert appear a moment later.
  ExamAlertService.instance.init();
  // Never hold the first Flutter frame behind a native plugin. Some Android
  // devices can take a long time to initialize Google Play services; awaiting
  // Firebase here leaves the launch-window background visible as a blank grey
  // screen. Push activation is also retried after sign-in, so startup remains
  // functional even when Firebase is temporarily unavailable.
  runApp(const SupercampusApp());
  unawaited(PushNotificationService.instance.initialize());
}
