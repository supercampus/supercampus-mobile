import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/core/access/module_catalog.dart';
import 'package:supercampus_mobile/src/core/notifications/notification_deep_link.dart';

void main() {
  test('every supported backend deep link opens its mobile module', () {
    expect(
      notificationModuleId(deepLink: '/academics/attendance'),
      ModuleCatalog.academics,
    );
    expect(
      notificationModuleId(
        deepLink: '/academics/attendance',
        preferAttendanceModule: true,
      ),
      ModuleCatalog.attendance,
    );
    expect(
      notificationModuleId(deepLink: '/shops/orders'),
      ModuleCatalog.canteen,
    );
    expect(notificationModuleId(deepLink: '/gatepass'), ModuleCatalog.gatepass);
    expect(
      notificationModuleId(deepLink: '/tuition-fee/payments'),
      ModuleCatalog.tuitionFee,
    );
    expect(
      notificationModuleId(deepLink: '/timetable/substitutions'),
      ModuleCatalog.timetable,
    );
    expect(
      notificationModuleId(deepLink: '/examinations/results'),
      ModuleCatalog.examination,
    );
    expect(notificationModuleId(deepLink: '/library'), ModuleCatalog.library);
    expect(notificationModuleId(deepLink: '/hostel'), ModuleCatalog.hostel);
  });

  test(
    'categories provide safe routing when a legacy row has no deep link',
    () {
      expect(notificationModuleId(category: 'wallet'), ModuleCatalog.canteen);
      expect(
        notificationModuleId(category: 'security'),
        ModuleCatalog.gatepass,
      );
      expect(notificationModuleId(category: 'fees'), ModuleCatalog.tuitionFee);
      expect(notificationModuleId(category: 'unknown'), isNull);
    },
  );
}
