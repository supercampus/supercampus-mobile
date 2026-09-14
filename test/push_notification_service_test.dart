import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/core/notifications/push_notification_service.dart';

void main() {
  test(
    'unsupported desktop platforms never initialize a Firebase plugin',
    () async {
      if (Platform.isAndroid) return;
      final service = PushNotificationService.instance;
      expect(service.supported, isFalse);
      expect(await service.initialize(), isFalse);
      await service.deactivate();
    },
  );
}
