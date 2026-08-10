import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/core/notifications/exam_alert_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Reads back the exam alerts the OS is still holding, so the app knows
  // which exams already have one. Not awaited: nothing on the first frame
  // depends on it, and a student who opens an exam before it finishes just
  // sees the alert appear a moment later.
  ExamAlertService.instance.init();

  runApp(const SupercampusApp());
}
