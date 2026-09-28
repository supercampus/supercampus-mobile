import 'dart:async';

import 'package:flutter/foundation.dart';

/// The two places of the laundry counter's workspace.
enum LaundrySection { home, history }

/// Lets the host's bottom navigation drive the laundry counter's workspace.
///
/// While the laundry workspace is on screen the host shows a History tab in
/// place of Modules; everywhere else the bar keeps its Modules entry. Like
/// [OwnerWorkspaceNav], what the bar shows follows the workspace actually
/// mounted, not the account's role.
class LaundryWorkspaceNav extends ChangeNotifier {
  ValueChanged<LaundrySection>? _handler;
  var _section = LaundrySection.home;
  var _disposed = false;

  /// Whether the laundry workspace is mounted.
  bool get available => _handler != null;

  /// The section the workspace is showing.
  LaundrySection get section => _section;

  /// Opens [section] in the mounted workspace.
  void show(LaundrySection section) => _handler?.call(section);

  /// Called by the workspace when it mounts.
  void attach(ValueChanged<LaundrySection> handler) {
    _handler = handler;
    _notifyLater();
  }

  /// Called by the workspace when it goes away.
  void detach(ValueChanged<LaundrySection> handler) {
    if (_handler != handler) return;
    _handler = null;
    _section = LaundrySection.home;
    _notifyLater();
  }

  /// Called by the workspace whenever the section it shows changes.
  void report(LaundrySection section) {
    if (_section == section) return;
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
