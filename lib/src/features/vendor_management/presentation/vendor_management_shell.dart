import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/access/effective_permissions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/user_facing_error.dart';
import '../../../core/widgets/module_navigation_buttons.dart';
import '../../authentication/data/auth_repository.dart';
import '../data/mock_vendor_repository.dart';
import '../data/vendor_models.dart';
import '../data/vendor_repository.dart';

part 'sales_dashboard_page.dart';
part 'sales_orders_page.dart';
part 'vendor_common.dart';
part 'vendors_page.dart';

/// Campus shops workspace: the sales dashboard, the shop register and the
/// order ledger. Each tab exists only when the viewer's grants cover it.
class VendorManagementShell extends StatefulWidget {
  const VendorManagementShell({
    super.key,
    required this.session,
    required this.onExitModule,
    this.repository,
    this.permissions,
    this.institutionName,
  });

  final UserSession session;
  final VoidCallback onExitModule;

  /// Null in builds without a campus server: the pages then read as empty,
  /// never as sample data.
  final VendorRepository? repository;

  /// The viewer's grants. Decides which tabs exist; null (tests without a
  /// backend) shows everything.
  final EffectivePermissions? permissions;

  /// The tenant this dashboard describes, e.g. "Madras Engineering College".
  final String? institutionName;

  @override
  State<VendorManagementShell> createState() => _VendorManagementShellState();
}

class _VendorManagementShellState extends State<VendorManagementShell> {
  var _tab = _VendorTab.dashboard;
  var _orderQuery = const _OrderQuery();
  List<StoreSales> _stores = const [];
  VoidCallback? _addShop;

  late final VendorRepository _repository =
      widget.repository ?? const OfflineVendorRepository();

  EffectivePermissions? get _grants => widget.permissions;

  bool _can(String resource, String action, [String module = 'vendor_management']) =>
      _grants == null || _grants!.can(module, resource, action);

  /// The shop register (`/canteen/shops`) is vendor administration.
  bool get _canReadShops => _can('vendors', 'read');
  bool get _canCreateShops => _can('vendors', 'create');
  bool get _canUpdateShops => _can('vendors', 'update');

  /// Mirrors the grants `/canteen/sales-dashboard` accepts.
  bool get _canReadSales =>
      _can('vendors', 'read') ||
      _can('analytics', 'read', 'canteen') ||
      _can('orders', 'manage', 'canteen');

  List<_VendorTab> get _tabs => [
    if (_canReadSales) _VendorTab.dashboard,
    if (_canReadShops) _VendorTab.vendors,
    if (_canReadSales) _VendorTab.orders,
  ];

  void _openOrders({OrderStatusFilter? status, String? shopKey}) {
    if (!_tabs.contains(_VendorTab.orders)) return;
    setState(() {
      _orderQuery = _OrderQuery(
        period: _orderQuery.period,
        status: status ?? OrderStatusFilter.all,
        shopKey: shopKey,
      );
      _tab = _VendorTab.orders;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _tabs;
    final current = tabs.contains(_tab)
        ? _tab
        : (tabs.isEmpty ? null : tabs.first);
    final index = current == null ? 0 : tabs.indexOf(current);
    return Scaffold(
      backgroundColor: context.palette.canvas,
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 0,
        leading: ModuleBackButton(onPressed: widget.onExitModule),
        title: Text(current?.title ?? 'Vendors & Orders'),
        actions: [
          if (current == _VendorTab.vendors && _canCreateShops)
            IconButton(
              tooltip: 'Add shop',
              onPressed: () => _addShop?.call(),
              icon: const Icon(Icons.add_rounded),
            ),
        ],
      ),
      // A navigation bar needs two destinations; one page stands on its own.
      bottomNavigationBar: tabs.length < 2
          ? null
          : NavigationBar(
              selectedIndex: index,
              onDestinationSelected: (v) => setState(() => _tab = tabs[v]),
              destinations: [
                for (final tab in tabs)
                  NavigationDestination(
                    icon: Icon(tab.icon),
                    selectedIcon: Icon(tab.selectedIcon),
                    label: tab.label,
                  ),
              ],
            ),
      body: current == null
          ? const _NoAccessState(
              message:
                  "You don't have access to shops or sales. Ask your "
                  'administrator if you need it.',
            )
          : IndexedStack(
              index: index,
              children: [for (final tab in tabs) _page(tab)],
            ),
    );
  }

  Widget _page(_VendorTab tab) => switch (tab) {
    _VendorTab.dashboard => _SalesDashboardPage(
      repository: _repository,
      institutionName: widget.institutionName,
      onStoresLoaded: (stores) => setState(() => _stores = stores),
      onOpenOrders: _openOrders,
    ),
    _VendorTab.vendors => _VendorsPage(
      repository: _repository,
      stores: _stores,
      canCreate: _canCreateShops,
      canUpdate: _canUpdateShops,
      onOpenOrders: (shopKey) => _openOrders(shopKey: shopKey),
      registerAddAction: (action) => _addShop = action,
    ),
    _VendorTab.orders => _SalesOrdersPage(
      repository: _repository,
      query: _orderQuery,
      stores: _stores,
      onQueryChanged: (query) => setState(() => _orderQuery = query),
    ),
  };
}

enum _VendorTab {
  dashboard(
    'Dashboard',
    'Sales Dashboard',
    Icons.insights_outlined,
    Icons.insights_rounded,
  ),
  vendors(
    'Vendors',
    'Vendors',
    Icons.storefront_outlined,
    Icons.storefront_rounded,
  ),
  orders(
    'Orders',
    'Orders',
    Icons.receipt_long_outlined,
    Icons.receipt_long_rounded,
  );

  const _VendorTab(this.label, this.title, this.icon, this.selectedIcon);

  final String label;
  final String title;
  final IconData icon;
  final IconData selectedIcon;
}
