import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/widgets/campus_nav_bar.dart';
import 'canteen_owner_home.dart';

/// Lets the host's bottom navigation drive the owner workspace's sections,
/// and the host's profile sheet open or close the workspace's counter.
///
/// While a shop workspace is on screen, the host's bar carries its sections
/// (Home, Menu, Settled, Sales) in place of Modules; everywhere else the bar
/// keeps its Modules entry. What the bar shows follows the workspace actually
/// mounted, not the account's role.
class OwnerWorkspaceNav extends ChangeNotifier {
  ValueChanged<OwnerSection>? _handler;
  Future<void> Function(bool open)? _counterHandler;
  var _sections = const <OwnerSection>[];
  var _section = OwnerSection.orders;
  bool? _counterOpen;
  var _counterBusy = false;
  var _disposed = false;

  /// Whether a workspace is mounted.
  bool get attached => _handler != null;

  /// The sections the mounted workspace offers, in bar order; empty when
  /// none is mounted.
  List<OwnerSection> get sections => attached ? _sections : const [];

  /// Whether the workspace on screen has a Menu section to open.
  bool get menuAvailable => sections.contains(OwnerSection.menu);

  /// The section the workspace is showing.
  OwnerSection get section => _section;

  /// Whether the workspace's counter is taking orders; null when no workspace
  /// is mounted or the account has no counter of its own (someone overseeing
  /// the shops, or staff not yet assigned to one).
  bool? get counterOpen => attached ? _counterOpen : null;

  /// Whether a change is in flight in the workspace.
  bool get counterBusy => _counterBusy;

  /// Opens [section] in the mounted workspace.
  void show(OwnerSection section) => _handler?.call(section);

  /// Opens or closes the mounted workspace's counter.
  Future<void> setCounterOpen(bool open) async {
    final handler = _counterHandler;
    if (handler == null || !attached) return;
    await handler(open);
  }

  /// Called by the workspace when it mounts.
  void attach(
    ValueChanged<OwnerSection> handler, {
    Future<void> Function(bool open)? onCounterOpenChanged,
  }) {
    _handler = handler;
    _counterHandler = onCounterOpenChanged;
  }

  /// Called by the workspace when it goes away.
  void detach(ValueChanged<OwnerSection> handler) {
    if (_handler != handler) return;
    _handler = null;
    _counterHandler = null;
    _sections = const [];
    _section = OwnerSection.orders;
    _counterOpen = null;
    _counterBusy = false;
    _notifyLater();
  }

  /// Called by the workspace whenever what it shows changes.
  void report({
    required List<OwnerSection> sections,
    required OwnerSection section,
    bool? counterOpen,
    bool counterBusy = false,
  }) {
    if (listEquals(_sections, sections) &&
        _section == section &&
        _counterOpen == counterOpen &&
        _counterBusy == counterBusy) {
      return;
    }
    _sections = List.unmodifiable(sections);
    _section = section;
    _counterOpen = counterOpen;
    _counterBusy = counterBusy;
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

/// The bar id of a workspace section.
String ownerNavId(OwnerSection section) => switch (section) {
  OwnerSection.orders => 'home',
  OwnerSection.menu => 'menu',
  OwnerSection.settled => 'settled',
  OwnerSection.sales => 'sales',
};

/// The workspace's destinations for [CampusNavBar], in [sections] order.
List<CampusNavItem> ownerNavItems(
  List<OwnerSection> sections,
  ValueChanged<OwnerSection> onSelect,
) => [
  for (final section in sections)
    switch (section) {
      OwnerSection.orders => CampusNavItem(
        id: ownerNavId(section),
        label: 'Home',
        icon: const Icon(Icons.home_outlined),
        selectedIcon: const Icon(Icons.home_rounded),
        onTap: () => onSelect(section),
      ),
      OwnerSection.menu => CampusNavItem(
        id: ownerNavId(section),
        label: 'Menu',
        icon: const Icon(Icons.restaurant_menu_outlined),
        selectedIcon: const Icon(Icons.restaurant_menu_rounded),
        onTap: () => onSelect(section),
      ),
      OwnerSection.settled => CampusNavItem(
        id: ownerNavId(section),
        label: 'Settled',
        icon: const Icon(Icons.receipt_long_outlined),
        selectedIcon: const Icon(Icons.receipt_long_rounded),
        onTap: () => onSelect(section),
      ),
      OwnerSection.sales => CampusNavItem(
        id: ownerNavId(section),
        label: 'Sales',
        icon: const Icon(Icons.bar_chart_outlined),
        selectedIcon: const Icon(Icons.bar_chart_rounded),
        onTap: () => onSelect(section),
      ),
    },
];
