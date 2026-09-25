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
import 'canteen_menu_item_editor_screen.dart';

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
  });

  final CanteenStore store;
  final VoidCallback onExitModule;
  final VoidCallback onSignOut;
  final Future<void> Function() onRefresh;
  final Future<void> Function(CanteenStaffMode mode) onModeChanged;
  final Future<void> Function(bool open) onShopOpenChanged;
  final Future<void> Function(String orderId, CanteenOrderStatus status)
  onOrderStatusChanged;
  final Future<void> Function(CanteenMenuItem item, bool create) onSaveMenuItem;
  final Future<void> Function(String itemId) onDeleteMenuItem;
  final Future<String> Function(Uint8List bytes, String filename) onUploadMedia;

  @override
  State<CanteenOwnerHome> createState() => _CanteenOwnerHomeState();
}

class _CanteenOwnerHomeState extends State<CanteenOwnerHome> {
  var _index = 0;
  var _busy = false;
  String? _selectedShopKey;

  List<CanteenShop> get _assignedShops {
    final assigned = widget.store.assignedShopKeys.toSet();
    return widget.store.shops
        .where((shop) => shop.isActive && assigned.contains(shop.shopKey))
        .toList();
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
  }

  @override
  void didUpdateWidget(covariant CanteenOwnerHome oldWidget) {
    super.didUpdateWidget(oldWidget);
    _selectedShopKey = _activeShopKey;
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
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
    final scopedStore = widget.store.copyWith(
      menu: scopedMenu,
      orders: scopedOrders,
    );
    final pages = [
      _OwnerOrders(
        store: scopedStore,
        busy: _busy,
        onRefresh: () => _run(widget.onRefresh),
        onStatus: (id, status) =>
            _run(() => widget.onOrderStatusChanged(id, status)),
      ),
      _OwnerMenu(
        items: scopedMenu,
        busy: _busy,
        onEdit: _editItem,
        onDelete: (id) => _run(() => widget.onDeleteMenuItem(id)),
      ),
      OwnerCaptainSalesAnalytics(
        store: scopedStore,
        busy: _busy,
        onRefresh: () => _run(widget.onRefresh),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        leading: ModuleBackButton(onPressed: widget.onExitModule),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Shop operations'),
            Text(
              'Owner workspace',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Counter controls',
            icon: const Icon(Icons.tune),
            onPressed: _busy ? null : _openCounterControls,
          ),
        ],
      ),
      body: Column(
        children: [
          _AssignedShopSelector(
            shops: _assignedShops,
            selectedShopKey: shopKey,
            onSelected: (value) => setState(() {
              _selectedShopKey = value;
            }),
          ),
          // These are sections of this page, not app navigation, so they sit
          // at the top of it. A second bar at the bottom would land underneath
          // the one the host already floats there.
          _SectionTabs(
            index: _index,
            onChanged: (value) => setState(() => _index = value),
          ),
          if (_busy) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: Padding(
              // Clear the floating nav so the last row of a list stays readable.
              padding: EdgeInsets.only(
                bottom:
                    CampusNavBar.heightFor(context) +
                    MediaQuery.paddingOf(context).bottom,
              ),
              child: IndexedStack(index: _index, children: pages),
            ),
          ),
        ],
      ),
      floatingActionButton: _index == 1
          ? Padding(
              padding: EdgeInsets.only(
                bottom:
                    CampusNavBar.heightFor(context) +
                    MediaQuery.paddingOf(context).bottom,
              ),
              child: FloatingActionButton(
                tooltip: 'Add menu item',
                onPressed: _busy ? null : () => _editItem(null),
                child: const Icon(Icons.add),
              ),
            )
          : null,
    );
  }

  /// Working or eating, and whether the counter is taking orders. Both are
  /// occasional decisions rather than things to read at a glance, so they live
  /// one tap away instead of taking a strip off the top of every screen.
  Future<void> _openCounterControls() async {
    var state = widget.store.staffState;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Counter controls',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                _OwnerControlBar(
                  state: state,
                  busy: _busy,
                  // The sheet answers immediately and the request follows, so a
                  // toggle never sits looking unpressed while the round trip
                  // completes.
                  onMode: (mode) {
                    setSheetState(
                      () => state = CanteenStaffState(
                        mode: mode,
                        shopOpen: state.shopOpen,
                      ),
                    );
                    _run(() => widget.onModeChanged(mode));
                  },
                  onShopOpen: (open) {
                    setSheetState(
                      () => state = CanteenStaffState(
                        mode: state.mode,
                        shopOpen: open,
                      ),
                    );
                    _run(() => widget.onShopOpenChanged(open));
                  },
                ),
              ],
            ),
          ),
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
              onSelected: (_) => onSelected(shop.shopKey),
            );
          },
        ),
      ),
    );
  }
}

class _OwnerControlBar extends StatelessWidget {
  const _OwnerControlBar({
    required this.state,
    required this.busy,
    required this.onMode,
    required this.onShopOpen,
  });

  final CanteenStaffState state;
  final bool busy;
  final ValueChanged<CanteenStaffMode> onMode;
  final ValueChanged<bool> onShopOpen;

  @override
  Widget build(BuildContext context) {
    final open = state.shopOpen ?? true;
    return Material(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(
          children: [
            Expanded(
              child: SegmentedButton<CanteenStaffMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: CanteenStaffMode.work,
                    icon: Icon(Icons.storefront_outlined),
                    label: Text('Work'),
                  ),
                  ButtonSegment(
                    value: CanteenStaffMode.eat,
                    icon: Icon(Icons.restaurant_outlined),
                    label: Text('Eat'),
                  ),
                ],
                selected: {state.mode},
                onSelectionChanged: busy
                    ? null
                    : (selection) => onMode(selection.first),
              ),
            ),
            const SizedBox(width: 12),
            Tooltip(
              message: open ? 'Shop open' : 'Shop closed',
              child: Switch(value: open, onChanged: busy ? null : onShopOpen),
            ),
          ],
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
  final void Function(String id, CanteenOrderStatus status) onStatus;

  @override
  State<_OwnerOrders> createState() => _OwnerOrdersState();
}

class _OwnerOrdersState extends State<_OwnerOrders> {
  /// Settled orders stay folded away by default: the queue is the job, and
  /// history is a question you ask occasionally.
  bool _showSettled = false;

  CanteenStore get store => widget.store;
  bool get busy => widget.busy;
  VoidCallback get onRefresh => widget.onRefresh;
  void Function(String id, CanteenOrderStatus status) get onStatus =>
      widget.onStatus;

  @override
  Widget build(BuildContext context) {
    final active = store.orders
        .where((order) => order.status.isActive)
        .toList();
    final settled =
        store.orders.where((order) => !order.status.isActive).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
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
            for (final order in active)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _OwnerOrderCard(
                  key: ValueKey('${order.id}_${order.status.name}'),
                  order: order,
                  busy: busy,
                  onStatus: onStatus,
                ),
              ),
          const SizedBox(height: 22),
          _SettledSection(
            orders: settled,
            expanded: _showSettled,
            onToggle: () => setState(() => _showSettled = !_showSettled),
          ),
        ],
      ),
    );
  }
}

/// Everything the counter has already finished with.
///
/// Delivered and rejected orders used to vanish from the workspace the moment
/// they settled, which left no way to check what happened to an order or answer
/// a student asking about one.
class _SettledSection extends StatelessWidget {
  const _SettledSection({
    required this.orders,
    required this.expanded,
    required this.onToggle,
  });

  final List<CanteenOrder> orders;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: orders.isEmpty ? null : onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Text(
                  'Settled orders',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(width: 8),
                Text(
                  '${orders.length}',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (orders.isNotEmpty)
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: const Icon(
                      Icons.expand_more,
                      color: AppColors.muted,
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (orders.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text(
              'Nothing settled yet today.',
              style: TextStyle(color: AppColors.muted),
            ),
          )
        else if (expanded) ...[
          const SizedBox(height: 6),
          for (final order in orders)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _SettledOrderRow(order: order),
            ),
        ],
      ],
    );
  }
}

class _SettledOrderRow extends StatelessWidget {
  const _SettledOrderRow({required this.order});

  final CanteenOrder order;

  @override
  Widget build(BuildContext context) {
    final rejected =
        order.status == CanteenOrderStatus.rejected ||
        order.status == CanteenOrderStatus.cancelled;
    return CanteenSurface(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            rejected ? Icons.close_rounded : Icons.check_rounded,
            size: 18,
            color: rejected ? const Color(0xFFB42318) : AppColors.success,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.lines
                      .map(
                        (line) => line.quantity > 1
                            ? '${line.quantity} x ${line.item.name}'
                            : line.item.name,
                      )
                      .join(', '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.1,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '#${order.displayId} · ${order.customerName ?? 'Campus user'} · ${order.status.label}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            formatCurrency(order.total),
            style: const TextStyle(fontWeight: FontWeight.w700),
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
          Icon(icon, size: 19, color: AppColors.primary),
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
  });

  final CanteenOrder order;
  final bool busy;
  final void Function(String id, CanteenOrderStatus status) onStatus;

  /// How the next step should read. The state machine itself lives on the
  /// model, so it can be reasoned about without a widget.
  (CanteenOrderStatus, String, IconData)? get _advance {
    final next = order.nextServiceStep ??
        (order.status.isActive ? CanteenOrderStatus.completed : null);
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

    final firstItem = order.lines.firstOrNull?.item;

    return SwipeActionCard(
      enabled: !busy,
      dismissOnCommit: advance?.$1 == CanteenOrderStatus.completed,
      forward: advance == null
          ? null
          : SwipeAction(
              label: advance.$2,
              icon: advance.$3,
              color: advanceGradient?.colors.first ?? AppColors.primary,
              gradient: advanceGradient,
              foreground: advanceForeground,
              onCommit: () => onStatus(order.id, advance.$1),
            ),
      backward: !order.status.canReject
          ? null
          : SwipeAction(
              label: 'Reject',
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
                        color: const Color(0xFFF1F5F9),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.restaurant_rounded,
                          size: 24,
                          color: AppColors.primary,
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
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text.rich(
                    TextSpan(
                      children: [
                        for (int i = 0; i < order.lines.length; i++) ...[
                          if (i > 0)
                            const TextSpan(
                              text: ', ',
                              style: TextStyle(color: Color(0xFF64748B)),
                            ),
                          TextSpan(
                            text: '${order.lines[i].quantity}× ',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          TextSpan(
                            text: order.lines[i].item.name,
                            style: const TextStyle(
                              color: Color(0xFF64748B),
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
            OrderNumberStatusBadge(order: order),
          ],
        ),
      ),
    );
  }
}



class _OwnerMenu extends StatelessWidget {
  const _OwnerMenu({
    required this.items,
    required this.busy,
    required this.onEdit,
    required this.onDelete,
  });

  final List<CanteenMenuItem> items;
  final bool busy;
  final ValueChanged<CanteenMenuItem> onEdit;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Menu management', style: Theme.of(context).textTheme.titleLarge),
            Text(
              '${items.length} items',
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final item in items)
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
                                  color: Colors.amber.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Instant',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.amber.shade900,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              'Sell: ${formatCurrency(item.price)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12.5,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Cost: ${formatCurrency(item.effectiveCost)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.muted,
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
                                    ? const Color(0xFF10B981).withValues(alpha: 0.12)
                                    : const Color(0xFFEF4444).withValues(alpha: 0.12),
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
                                      ? const Color(0xFF047857)
                                      : const Color(0xFFB91C1C),
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
                                ? const Color(0xFF087A53)
                                : const Color(0xFFB42318),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Edit item',
                    onPressed: busy ? null : () => onEdit(item),
                    icon: const Icon(Icons.edit_outlined, size: 20),
                  ),
                  IconButton(
                    tooltip: 'Delete item',
                    onPressed: busy ? null : () => onDelete(item.id),
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

/// The owner workspace's own sections. They live at the top of the page: the
/// bottom of the screen belongs to the one navigation bar the host floats
/// there, and two bars stacked on each other was the bug this replaced.
class _SectionTabs extends StatelessWidget {
  const _SectionTabs({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<int>(
          segments: const [
            ButtonSegment(
              value: 0,
              icon: Icon(Icons.receipt_long_outlined),
              label: Text('Orders'),
            ),
            ButtonSegment(
              value: 1,
              icon: Icon(Icons.restaurant_menu_outlined),
              label: Text('Menu'),
            ),
            ButtonSegment(
              value: 2,
              icon: Icon(Icons.analytics_outlined),
              label: Text('Sales & Profit'),
            ),
          ],
          selected: {index},
          showSelectedIcon: false,
          onSelectionChanged: (value) => onChanged(value.first),
        ),
      ),
    );
  }
}
