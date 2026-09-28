import 'dart:async';

import 'package:flutter/foundation.dart';

import 'canteen_owner_home.dart';

/// Lets the host's bottom navigation drive the owner workspace's sections.
///
/// While a shop workspace with a menu is on screen, the host shows a Menu tab
/// in place of Modules; everywhere else the bar keeps its Modules entry. What
/// the bar shows follows the workspace actually mounted, not the account's
/// role.
class OwnerWorkspaceNav extends ChangeNotifier {
  ValueChanged<OwnerSection>? _handler;
  var _menuAvailable = false;
  var _section = OwnerSection.orders;
  var _disposed = false;

  /// Whether the workspace on screen has a Menu section to open.
  bool get menuAvailable => _handler != null && _menuAvailable;

  /// The section the workspace is showing.
  OwnerSection get section => _section;

  /// Opens [section] in the mounted workspace.
  void show(OwnerSection section) => _handler?.call(section);

  /// Called by the workspace when it mounts.
  void attach(ValueChanged<OwnerSection> handler) {
    _handler = handler;
  }

  /// Called by the workspace when it goes away.
  void detach(ValueChanged<OwnerSection> handler) {
    if (_handler != handler) return;
    _handler = null;
    _menuAvailable = false;
    _section = OwnerSection.orders;
    _notifyLater();
  }

  /// Called by the workspace whenever what it shows changes.
  void report({required bool menuAvailable, required OwnerSection section}) {
    if (_menuAvailable == menuAvailable && _section == section) return;
    _menuAvailable = menuAvailable;
    _section = section;
    _notifyLater();
  }

  // Reports arrive while the tree is building or tearing down, when the host
  // cannot be marked dirty; the host catches up straight after.
  void _notifyLater() => scheduleMicrotask(() {
    if (!_disposed) notifyListeners();
  });

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
