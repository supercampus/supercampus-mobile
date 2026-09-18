import '../access/module_catalog.dart';

/// Converts server notification routing metadata into a module the installed
/// mobile app can actually open. Keeping this in one place prevents foreground,
/// background and inbox taps from drifting apart.
String? notificationModuleId({
  String? deepLink,
  String? category,
  bool preferAttendanceModule = false,
}) {
  final path = deepLink?.trim() ?? '';
  if (path.startsWith('/academics/attendance')) {
    return preferAttendanceModule
        ? ModuleCatalog.attendance
        : ModuleCatalog.academics;
  }
  if (path.startsWith('/academics')) return ModuleCatalog.academics;
  if (path.startsWith('/shops') || path.startsWith('/canteen')) {
    return ModuleCatalog.canteen;
  }
  if (path.startsWith('/gatepass')) return ModuleCatalog.gatepass;
  if (path.startsWith('/tuition-fee')) return ModuleCatalog.tuitionFee;
  if (path.startsWith('/timetable')) return ModuleCatalog.timetable;
  if (path.startsWith('/examinations')) return ModuleCatalog.examination;
  if (path.startsWith('/library')) return ModuleCatalog.library;
  if (path.startsWith('/hostel')) return ModuleCatalog.hostel;

  return switch (category?.trim().toLowerCase()) {
    'attendance' =>
      preferAttendanceModule
          ? ModuleCatalog.attendance
          : ModuleCatalog.academics,
    'academics' => ModuleCatalog.academics,
    'wallet' || 'canteen' => ModuleCatalog.canteen,
    'security' || 'gatepass' => ModuleCatalog.gatepass,
    'fees' => ModuleCatalog.tuitionFee,
    'timetable' => ModuleCatalog.timetable,
    'examination' => ModuleCatalog.examination,
    'library' => ModuleCatalog.library,
    'hostel' => ModuleCatalog.hostel,
    _ => null,
  };
}

/// Extracts any initial module action that a notification implies (such as
/// opening "My orders" in the canteen module when an order update arrives).
String? notificationModuleAction({
  String? deepLink,
  String? category,
  String? eventType,
  String? title,
}) {
  final path = deepLink?.trim() ?? '';
  if (path.contains('/orders') || path.contains('/canteen/orders')) {
    return 'orders';
  }
  final cat = category?.trim().toLowerCase();
  final evt = eventType?.trim().toLowerCase() ?? '';
  final t = title?.trim().toLowerCase() ?? '';

  if (cat == 'canteen' ||
      evt.startsWith('order.') ||
      evt.startsWith('canteen.order') ||
      t.contains('order')) {
    return 'orders';
  }
  return null;
}
