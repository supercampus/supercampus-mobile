import 'package:flutter/foundation.dart';

/// Bumped whenever a realtime event says canteen, stationery or laundry data
/// changed (an order placed or moved, a wallet credited, a menu edited), so an
/// open store screen reloads straight away instead of polling every few
/// seconds.
final ValueNotifier<int> canteenRevision = ValueNotifier<int>(0);

bool isCanteenEvent(String type) =>
    type.startsWith('canteen.') || type.startsWith('laundry.');
