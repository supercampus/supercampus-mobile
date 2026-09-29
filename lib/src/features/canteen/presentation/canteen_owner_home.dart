import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/campus_nav_bar.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/module_navigation_buttons.dart';
import '../../../core/widgets/swipe_action_card.dart';
import '../data/canteen_models.dart';
import 'widgets/canteen_surface.dart';
import 'widgets/menu_item_art.dart';
import 'widgets/order_status_badge.dart';
import 'widgets/owner_captain_sales_analytics.dart';
import 'widgets/settled_orders_page.dart';
import 'widgets/unassigned_counter_notice.dart';
import 'canteen_menu_item_editor_screen.dart';
import 'owner_workspace_nav.dart';
import '../../../core/utils/user_facing_error.dart';

class CanteenOwnerHome extends StatefulWidget {
  const CanteenOwnerHome({
    super.key,
    required this.store,
    required this.onExitModule,
    required this.onSignOut,
    required this.onRefresh,
    required this.onModeChanged,
    required this.onShopOpenChanged,
    required this.onOrderStatusChanged,
    required this.onSaveMenuItem,
    required this.onDeleteMenuItem,
    required this.onUploadMedia,
    this.isMainHome = false,
    this.onProfileTap,
    this.photoUrl,
    this.displayName,
    this.email,
    this.nav,
    this.loadShopAnalytics,
    this.loadCaptainDetail,
  });

  /// Loads the Sales destination's figures from the server for a date range;
  /// without it the page rolls up the orders already in [store].
  final ShopAnalyticsLoader? loadShopAnalytics;

  /// Loads one captain's page (figures, daily trend and orders) from the
  /// server; without it the page is rolled up from [store]'s orders.
  final CaptainDetailLoader? loadCaptainDetail;

  /// Lets the host's bottom bar open this workspace's sections and its
  /// profile sheet open or close the counter. Without it the workspace
  /// floats its own bar.
  final OwnerWorkspaceNav? nav;

  final CanteenStore store;
  final VoidCallback onExitModule;
  final VoidCallback onSignOut;
  final Future<void> Function() onRefresh;
  final Future<void> Function(CanteenStaffMode mode) onModeChanged;
  final Future<void> Function(bool open) onShopOpenChanged;
  final Future<void> Function(
    String orderId,
    CanteenOrderStatus status, {
    int? lineIndex,
  })
  onOrderStatusChanged;
  final Future<void> Function(CanteenMenuItem item, bool create) onSaveMenuItem;
  final Future<void> Function(String itemId) onDeleteMenuItem;
  final Future<String> Function(Uint8List bytes, String filename) onUploadMedia;
  final bool isMainHome;
  final VoidCallback? onProfileTap;
  final String? photoUrl;
  final String? displayName;
  final String? email;

  @override
  State<CanteenOwnerHome> createState() => _CanteenOwnerHomeState();
}

/// The workspace's sections, in the order the bottom bar shows them: Home
/// (the live queue), Menu, Settled orders and Sales.
enum OwnerSection { orders, menu, settled, sales }

/// Which sections a shop shows to this account.
///
/// Whoever works a shop's counter — its owner or operator, i.e. someone
/// assigned to it — gets the queue, the menu, its settled orders and the
/// figures. Someone who holds
/// the shop-configuration grant without being assigned to that shop is
/// overseeing it: the queue is the counter's job, so they see the figures, and
/// for a food counter the menu. Stationery and laundry are run entirely from
/// their own counters.
@visibleForTesting
List<OwnerSection> ownerSectionsFor(CanteenStore store, CanteenShop? shop) {
  final shopKey = shop?.shopKey;
  final overseeing =
      store.canConfigureShops &&
      (shopKey == null || !store.assignedShopKeys.contains(shopKey));
  if (!overseeing) return OwnerSection.values;
  final category = '${shop?.category ?? ''} ${shop?.shopKey ?? ''}'
      .toLowerCase();
  final isFood = !category.contains('station') && !category.contains('laundry');
  return [if (isFood) OwnerSection.menu, OwnerSection.sales];
}

class _CanteenOwnerHomeState extends State<CanteenOwnerHome> {
  var _section = OwnerSection.orders;
  var _busy = false;
  String? _selectedShopKey;

  List<CanteenShop> get _assignedShops {
    final assigned = widget.store.assignedShopKeys.toSet();
    final filtered = widget.store.shops
        .where(
          (shop) =>
              shop.isActive &&
              (assigned.isEmpty || assigned.contains(shop.shopKey)),
        )
        .toList();
    if (filtered.isNotEmpty) return filtered;
    return widget.store.shops.where((shop) => shop.isActive).toList();
  }

  String? get _activeShopKey {
    final shops = _assignedShops;
    if (shops.isEmpty) return null;
    if (shops.any((shop) => shop.shopKey == _selectedShopKey)) {
      return _selectedShopKey;
    }
    return shops.first.shopKey;
  }

  @override
  void initState() {
    super.initState();
    _selectedShopKey = _activeShopKey;
    widget.nav?.attach(_showSection, onCounterOpenChanged: _setCounterOpen);
  }

  @override
  void didUpdateWidget(covariant CanteenOwnerHome oldWidget) {
    super.didUpdateWidget(oldWidget);
    _selectedShopKey = _activeShopKey;
    if (oldWidget.nav != widget.nav) {
      oldWidget.nav?.detach(_showSection);
      widget.nav?.attach(_showSection, onCounterOpenChanged: _setCounterOpen);
    }
  }

  @override
  void dispose() {
    widget.nav?.detach(_showSection);
    super.dispose();
  }

  void _showSection(OwnerSection section) {
    if (mounted) setState(() => _section = section);
  }

  /// Opening and closing is the counter's call: an account overseeing the
  /// shops, or staff not yet given a counter, has none of its own.
  bool get _hasCounter =>
      widget.store.assignedShopKeys.isNotEmpty &&
      !widget.store.shopAssignmentPending;

  Future<void> _setCounterOpen(bool open) =>
      _run(() => widget.onShopOpenChanged(open));

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userFacingError(error))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shopKey = _activeShopKey;
    if (shopKey == null) {
      return Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          leading: ModuleBackButton(onPressed: widget.onExitModule),
          title: const Text('Shop operations'),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.storefront_outlined, size: 42),
                SizedBox(height: 14),
                Text(
                  'No shops assigned',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 8),
                Text(
                  'Ask your institution administrator to assign a shop to your account.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final scopedMenu = widget.store.menu
        .where((item) => item.effectiveShopKey == shopKey)
        .toList();
    final scopedOrders = widget.store.orders
        .where(
          (order) =>
              order.lines.any((line) => line.item.effectiveShopKey == shopKey),
        )
        .toList();
    // The server's analytics span every store this account can see. The tiles
    // sit above one store's queue, so they are recounted from that store's
    // orders; otherwise "2 pending" shows over an empty queue.
    final scopedStore = widget.store.copyWith(
      menu: scopedMenu,
      orders: scopedOrders,
      analytics: analyticsForOrders(scopedOrders),
    );
    CanteenShop? activeShop;
    for (final shop in _assignedShops) {
      if (shop.shopKey == shopKey) activeShop = shop;
    }
    final sections = ownerSectionsFor(widget.store, activeShop);
    final section = sections.contains(_section) ? _section : sections.first;
    final overseeing =
        widget.store.canConfigureShops && widget.store.assignedShopKeys.isEmpty;
    widget.nav?.report(
      sections: sections,
      section: section,
      counterOpen: _hasCounter
          ? (widget.store.staffState.shopOpen ?? true)
          : null,
      counterBusy: _busy,
    );
    final settledOrders =
        scopedOrders.where((order) => !order.status.isActive).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final pages = <OwnerSection, Widget>{
      OwnerSection.orders: _OwnerOrders(
        store: scopedStore,
        busy: _busy,
        onRefresh: () => _run(widget.onRefresh),
        onStatus: (id, status, {lineIndex}) => _run(
          () => widget.onOrderStatusChanged(id, status, lineIndex: lineIndex),
        ),
      ),
      OwnerSection.menu: _OwnerMenu(
        items: scopedMenu,
        busy: _busy,
        onAdd: () => _editItem(null),
        onEdit: _editItem,
        onDelete: (id) => _run(() => widget.onDeleteMenuItem(id)),
        onToggleAvailability: (item, isAvailable) => _run(
          () => widget.onSaveMenuItem(
            item.copyWith(isAvailable: isAvailable),
            false,
          ),
        ),
      ),
      OwnerSection.settled: RefreshIndicator(
        onRefresh: () => _run(widget.onRefresh),
        child: SettledOrdersView(
          orders: settledOrders,
          showTitle: true,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        ),
      ),
      OwnerSection.sales: OwnerCaptainSalesAnalytics(
        store: scopedStore,
        busy: _busy,
        onRefresh: () => _run(widget.onRefresh),
        shopKey: shopKey,
        shopName: activeShop?.name,
        loadAnalytics: widget.loadShopAnalytics,
        loadCaptainDetail: widget.loadCaptainDetail,
      ),
    };
    // Hosted, the bar is the host's; on its own (opened as a module) the
    // workspace floats the same bar itself.
    final ownBar =
        widget.nav == null &&
        sections.length > 1 &&
        !widget.store.shopAssignmentPending;

    return PopScope(
      // Back from Menu, Settled or Sales returns to the first section before
      // it leaves the workspace.
      canPop: section == sections.first,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _section = sections.first);
      },
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: widget.isMainHome ? null : 0,
          leading: widget.isMainHome
              ? null
              : ModuleBackButton(onPressed: widget.onExitModule),
          automaticallyImplyLeading: !widget.isMainHome,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Shop operations'),
              Text(
                overseeing ? 'Campus shops' : 'Owner workspace',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          actions: [
            // Work / Shop and opening the counter live in the profile, so the
            // app bar needs no controls of its own.
            Padding(
              padding: const EdgeInsets.only(right: 12, left: 4),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: widget.onProfileTap,
                child: CircleAvatar(
                  radius: 17,
                  backgroundColor: context.palette.brandInk.withValues(
                    alpha: 0.12,
                  ),
                  backgroundImage:
                      (widget.photoUrl != null && widget.photoUrl!.isNotEmpty)
                      ? NetworkImage(widget.photoUrl!)
                      : null,
                  child: (widget.photoUrl == null || widget.photoUrl!.isEmpty)
                      ? Icon(
                          Icons.person,
                          size: 20,
                          color: context.palette.brandInk,
                        )
                      : null,
                ),
              ),
            ),
          ],
        ),
        body: widget.store.shopAssignmentPending
            // Shop staff with no counter: say so rather than show another
            // shop's queue or an empty one.
            ? ListView(
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 28),
                children: [
                  UnassignedCounterNotice(
                    message: widget.store.unassignedCounterMessage,
                  ),
                ],
              )
            : Stack(
                children: [
                  Column(
                    children: [
                      if (_assignedShops.length > 1)
                        _AssignedShopSelector(
                          shops: _assignedShops,
                          selectedShopKey: shopKey,
                          onSelected: (value) => setState(() {
                            _selectedShopKey = value;
                          }),
                        ),
                      // The sections are destinations of the bottom bar,
                      // so the page carries no switcher of its own.
                      if (_busy) const LinearProgressIndicator(minHeight: 2),
                      Expanded(
                        child: Padding(
                          // Clear the floating nav so the last row of a list
                          // stays readable.
                          padding: EdgeInsets.only(
                            bottom:
                                CampusNavBar.heightFor(context) +
                                MediaQuery.paddingOf(context).bottom,
                          ),
                          child: IndexedStack(
                            index: sections.indexOf(section),
                            children: [
                              for (final value in sections) pages[value]!,
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (ownBar)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: MediaQuery.paddingOf(context).bottom + 10,
                      child: CampusNavBar(
                        selectedId: ownerNavId(section),
                        items: ownerNavItems(sections, _showSection),
                        showScan: false,
                        onHome: () => _showSection(sections.first),
                        onModules: () {},
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Future<void> _editItem(CanteenMenuItem? item) async {
    final result = await Navigator.of(context).push<CanteenMenuItem>(
      MaterialPageRoute(
        builder: (_) => CanteenMenuItemEditorScreen(
          item: item,
          shops: _assignedShops,
          selectedShopKey: _activeShopKey!,
          onUploadMedia: widget.onUploadMedia,
        ),
      ),
    );
    if (result != null) {
      await _run(() => widget.onSaveMenuItem(result, item == null));
    }
  }
}

class _AssignedShopSelector extends StatelessWidget {
  const _AssignedShopSelector({
    required this.shops,
    required this.selectedShopKey,
    required this.onSelected,
  });

  final List<CanteenShop> shops;
  final String selectedShopKey;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SizedBox(
        height: 58,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          scrollDirection: Axis.horizontal,
          itemCount: shops.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final shop = shops[index];
            return ChoiceChip(
              label: Text(shop.name),
              selected: shop.shopKey == selectedShopKey,
              showCheckmark: false,
              onSelected: (_) => onSelected(shop.shopKey),
            );
          },
        ),
      ),
    );
  }
}

class _OwnerOrders extends StatefulWidget {
  const _OwnerOrders({
    required this.store,
    required this.busy,
    required this.onRefresh,
    required this.onStatus,
  });

  final CanteenStore store;
  final bool busy;
  final VoidCallback onRefresh;
  final void Function(String id, CanteenOrderStatus status, {int? lineIndex})
  onStatus;

  @override
  State<_OwnerOrders> createState() => _OwnerOrdersState();
}

class _OwnerOrdersState extends State<_OwnerOrders> {
  CanteenStore get store => widget.store;
  bool get busy => widget.busy;
  VoidCallback get onRefresh => widget.onRefresh;
  void Function(String id, CanteenOrderStatus status, {int? lineIndex})
  get onStatus => widget.onStatus;

  @override
  Widget build(BuildContext context) {
    final active = store.orders
        .where((order) => order.status.isActive)
        .toList();
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          Row(
            children: [
              Expanded(
                child: _Metric(
                  label: 'Orders today',
                  value: '${store.analytics.ordersToday}',
                  icon: Icons.receipt_long_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Metric(
                  label: 'Revenue',
                  value: formatCurrency(store.analytics.revenueToday),
                  icon: Icons.payments_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Metric(
                  label: 'Pending',
                  value: '${store.analytics.pending}',
                  icon: Icons.pending_actions_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Live order queue',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          if (active.isEmpty)
            const CanteenSurface(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Center(child: Text('No active orders.')),
              ),
            )
          else
            // One card per food item still at the counter, each carrying its
            // order's number, so swiping moves only that item.
            for (final order in active)
              for (var i = 0; i < order.lines.length; i++)
                if (order.lineStatus(i).isActive)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _OwnerOrderCard(
                      key: ValueKey(
                        '${order.id}_${i}_${order.lineStatus(i).name}',
                      ),
                      order: order,
                      lineIndex: i,
                      busy: busy,
                      onStatus: onStatus,
                    ),
                  ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return CanteenSurface(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: context.palette.brandInk),
          const SizedBox(height: 9),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// One order in the live queue.
///
/// What the counter needs first is *what to cook*, so the items lead. Who
/// ordered it only matters once the food is made, so the name sits at the foot
/// of the card in a quieter voice.
///
/// The queue advances by pushing the card right — blue to start preparing,
/// amber when it is ready to serve, green when it goes out — and rejects by
/// pushing it left. The colour is the one the order is moving *to*, so the
/// backdrop tells you what will happen before you commit.
class _OwnerOrderCard extends StatelessWidget {
  const _OwnerOrderCard({
    super.key,
    required this.order,
    required this.busy,
    required this.onStatus,
    this.lineIndex,
  });

  final CanteenOrder order;

  /// When set, the card is this one food item of [order] and swiping moves
  /// only that item.
  final int? lineIndex;
  final bool busy;
  final void Function(String id, CanteenOrderStatus status, {int? lineIndex})
  onStatus;

  List<CartLine> get _lines =>
      lineIndex == null ? order.lines : [order.lines[lineIndex!]];

  /// The order as this card sees it: an item card carries its item's status.
  CanteenOrder get _shown => lineIndex == null
      ? order
      : order.copyWith(status: order.lineStatus(lineIndex!));

  /// How the next step should read. The state machine itself lives on the
  /// model, so it can be reasoned about without a widget.
  (CanteenOrderStatus, String, IconData)? get _advance {
    final next = lineIndex != null
        ? order.nextLineStep(lineIndex!)
        : (order.nextServiceStep ??
              (order.status.isActive ? CanteenOrderStatus.completed : null));
    if (next == null) return null;
    return switch (next) {
      CanteenOrderStatus.preparing => (
        next,
        'Preparing',
        Icons.local_fire_department_outlined,
      ),
      CanteenOrderStatus.ready => (
        next,
        'Ready for pickup',
        Icons.room_service_outlined,
      ),
      CanteenOrderStatus.completed => (
        next,
        'Delivered',
        Icons.check_circle_outline,
      ),
      _ => (
        CanteenOrderStatus.completed,
        'Delivered',
        Icons.check_circle_outline,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final advance = _advance;
    final advanceStatus = advance?.$1;
    final advanceGradient = advanceStatus != null
        ? OrderStatusGradients.forStatus(advanceStatus)
        : null;
    final advanceForeground = advanceStatus != null
        ? (advanceStatus == CanteenOrderStatus.preparing
              ? const Color(0xFF78350F)
              : Colors.white)
        : Colors.white;

    final lines = _lines;
    final firstItem = lines.firstOrNull?.item;

    return SwipeActionCard(
      enabled: !busy,
      dismissOnCommit: advance?.$1 == CanteenOrderStatus.completed,
      forward: advance == null
          ? null
          : SwipeAction(
              label: advance.$2,
              icon: advance.$3,
              color: advanceGradient?.colors.first ?? context.palette.brand,
              gradient: advanceGradient,
              foreground: advanceForeground,
              onCommit: () =>
                  onStatus(order.id, advance.$1, lineIndex: lineIndex),
            ),
      backward: !order.status.canReject
          ? null
          : SwipeAction(
              // Rejecting refunds the whole order, so it is named as such.
              label: lineIndex != null ? 'Reject order' : 'Reject',
              icon: Icons.close_rounded,
              color: const Color(0xFFEF4444),
              gradient: OrderStatusGradients.rejected,
              foreground: Colors.white,
              onCommit: () => onStatus(order.id, CanteenOrderStatus.rejected),
            ),
      child: CanteenSurface(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            ClipOval(
              child: SizedBox(
                width: 48,
                height: 48,
                child: firstItem != null
                    ? MenuItemArt(item: firstItem, size: 48)
                    : Container(
                        color: context.adaptive(
                          light: const Color(0xFFF1F5F9),
                          dark: const Color(0xFF1C1D23),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.restaurant_rounded,
                          size: 24,
                          color: context.palette.brandInk,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    order.customerName ?? 'Campus user',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: context.adaptive(
                        light: const Color(0xFF1E293B),
                        dark: const Color(0xFFF2F2F5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text.rich(
                    TextSpan(
                      children: [
                        for (int i = 0; i < lines.length; i++) ...[
                          if (i > 0)
                            TextSpan(
                              text: ', ',
                              style: TextStyle(
                                color: context.adaptive(
                                  light: const Color(0xFF64748B),
                                  dark: const Color(0xFFA3A5B0),
                                ),
                              ),
                            ),
                          TextSpan(
                            text: '${lines[i].quantity}× ',
                            style: TextStyle(
                              color: context.palette.brandInk,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          TextSpan(
                            text: lines[i].item.name,
                            style: TextStyle(
                              color: context.adaptive(
                                light: const Color(0xFF64748B),
                                dark: const Color(0xFFA3A5B0),
                              ),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            OrderNumberStatusBadge(order: _shown),
          ],
        ),
      ),
    );
  }
}

class _OwnerMenu extends StatefulWidget {
  const _OwnerMenu({
    required this.items,
    required this.busy,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleAvailability,
    required this.onAdd,
  });

  final List<CanteenMenuItem> items;
  final bool busy;
  final VoidCallback onAdd;
  final ValueChanged<CanteenMenuItem> onEdit;
  final ValueChanged<String> onDelete;
  final void Function(CanteenMenuItem item, bool isAvailable)
  onToggleAvailability;

  @override
  State<_OwnerMenu> createState() => _OwnerMenuState();
}

class _OwnerMenuState extends State<_OwnerMenu> {
  String _searchQuery = '';

  /// The food type shown; null shows every type.
  String? _type;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchQuery.trim().toLowerCase();
    final types = {
      for (final item in widget.items)
        if (item.category.trim().isNotEmpty) item.category.trim(),
    }.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final type = types.contains(_type) ? _type : null;
    final filtered = widget.items.where((item) {
      if (type != null && item.category.trim() != type) return false;
      if (query.isEmpty) return true;
      return item.name.toLowerCase().contains(query) ||
          item.category.toLowerCase().contains(query) ||
          item.description.toLowerCase().contains(query);
    }).toList();
    final narrowed = query.isNotEmpty || type != null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                'Menu management',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Text(
              narrowed
                  ? '${filtered.length} of ${widget.items.length} items'
                  : '${widget.items.length} items',
              style: TextStyle(
                fontSize: 12,
                color: context.palette.inkSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Type and Add item sit at the top, where the list starts.
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String?>(
                key: const ValueKey('owner-menu-type'),
                initialValue: type,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Type',
                  filled: true,
                  fillColor: context.adaptive(
                    light: const Color(0xFFF1F5F9),
                    dark: const Color(0xFF1C1D23),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('All types'),
                  ),
                  for (final value in types)
                    DropdownMenuItem<String?>(
                      value: value,
                      child: Text(value, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (value) => setState(() => _type = value),
              ),
            ),
            const SizedBox(width: 10),
            FilledButton.icon(
              key: const ValueKey('owner-menu-add'),
              onPressed: widget.busy ? null : widget.onAdd,
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add item'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Search bar for menu items
        TextField(
          controller: _searchController,
          onChanged: (val) => setState(() => _searchQuery = val),
          decoration: InputDecoration(
            hintText: 'Search menu items...',
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            filled: true,
            fillColor: context.adaptive(
              light: const Color(0xFFF1F5F9),
              dark: const Color(0xFF1C1D23),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (filtered.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 36),
            child: Center(
              child: Text(
                'No menu items found',
                style: TextStyle(
                  color: context.palette.inkSecondary,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        for (final item in filtered)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: CanteenSurface(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
              child: Row(
                children: [
                  MenuItemArt(item: item, size: 52),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (item.isInstant)
                              Container(
                                margin: const EdgeInsets.only(left: 6),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: context.adaptive(
                                    light: Colors.amber.shade100,
                                    dark: const Color(0x2EFFC107),
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Instant',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: context.adaptive(
                                      light: Colors.amber.shade900,
                                      dark: const Color(0xFFFCD34D),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Wraps on narrow phones instead of overflowing.
                        Wrap(
                          spacing: 0,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'Sell: ${formatCurrency(item.price)}',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12.5,
                                color: context.adaptive(
                                  light: const Color(0xFF1E293B),
                                  dark: const Color(0xFFF2F2F5),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Cost: ${formatCurrency(item.effectiveCost)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: context.palette.inkSecondary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: item.profit >= 0
                                    ? const Color(
                                        0xFF10B981,
                                      ).withValues(alpha: 0.12)
                                    : const Color(
                                        0xFFEF4444,
                                      ).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                item.profit >= 0
                                    ? '+${formatCurrency(item.profit)}'
                                    : formatCurrency(item.profit),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: item.profit >= 0
                                      ? context.adaptive(
                                          light: const Color(0xFF047857),
                                          dark: const Color(0xFF6EE7B7),
                                        )
                                      : context.adaptive(
                                          light: const Color(0xFFB91C1C),
                                          dark: const Color(0xFFFCA5A5),
                                        ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${item.category} · ${item.isAvailable ? 'Available' : 'Unavailable'}',
                          style: TextStyle(
                            fontSize: 11,
                            color: item.isAvailable
                                ? context.adaptive(
                                    light: const Color(0xFF087A53),
                                    dark: const Color(0xFF6EE7B7),
                                  )
                                : context.adaptive(
                                    light: const Color(0xFFB42318),
                                    dark: const Color(0xFFFCA5A5),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Availability on/off toggle right in the menu item card
                  Tooltip(
                    message: item.isAvailable
                        ? 'Available (tap to make unavailable)'
                        : 'Unavailable (tap to make available)',
                    child: Switch.adaptive(
                      value: item.isAvailable,
                      activeTrackColor: const Color(0xFF10B981),
                      onChanged: widget.busy
                          ? null
                          : (val) => widget.onToggleAvailability(item, val),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Edit item',
                    onPressed: widget.busy ? null : () => widget.onEdit(item),
                    icon: const Icon(Icons.edit_outlined, size: 20),
                  ),
                  IconButton(
                    tooltip: 'Delete item',
                    onPressed: widget.busy
                        ? null
                        : () => widget.onDelete(item.id),
                    icon: const Icon(Icons.delete_outline, size: 20),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Today's figures for [orders], counted the way the server counts them:
/// orders placed today, revenue from today's completed orders, and every
/// order still in the queue as pending.
@visibleForTesting
CanteenAnalytics analyticsForOrders(
  Iterable<CanteenOrder> orders, {
  DateTime? now,
}) {
  final today = now ?? DateTime.now();
  bool placedToday(CanteenOrder order) {
    final created = order.createdAt.toLocal();
    return created.year == today.year &&
        created.month == today.month &&
        created.day == today.day;
  }

  var ordersToday = 0;
  var revenueToday = 0.0;
  var pending = 0;
  for (final order in orders) {
    if (order.status.isActive) pending++;
    if (!placedToday(order)) continue;
    ordersToday++;
    if (order.status == CanteenOrderStatus.completed) {
      revenueToday += order.total;
    }
  }
  return CanteenAnalytics(
    ordersToday: ordersToday,
    revenueToday: revenueToday,
    pending: pending,
  );
}
