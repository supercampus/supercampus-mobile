import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/module_navigation_buttons.dart';
import '../../../core/widgets/swipe_action_card.dart';
import '../../scanner/presentation/scan_qr_screen.dart';
import '../data/canteen_models.dart';
import 'widgets/canteen_order_detail_page.dart';
import 'widgets/canteen_surface.dart';
import 'widgets/shop_mode_switch.dart';
import 'widgets/menu_item_art.dart';
import 'widgets/order_status_badge.dart';
import '../../../core/utils/user_facing_error.dart';

/// Order-only workspace for staff assigned to a canteen as captains.
///
/// Menu and shop administration deliberately stay in the owner's workspace.
class CanteenCaptainHome extends StatefulWidget {
  const CanteenCaptainHome({
    super.key,
    required this.store,
    required this.onExitModule,
    required this.onSignOut,
    required this.onRefresh,
    required this.onModeChanged,
    required this.onOrderStatusChanged,
    this.onScanOrder,
    this.onProfileTap,
    this.photoUrl,
    this.displayName,
    this.isMainHome = false,
  });

  final CanteenStore store;
  final VoidCallback onExitModule;
  final VoidCallback onSignOut;
  final Future<void> Function() onRefresh;
  final Future<void> Function(CanteenStaffMode mode) onModeChanged;
  final Future<void> Function(
    String orderId,
    CanteenOrderStatus status, {
    int? lineIndex,
  })
  onOrderStatusChanged;
  /// Hands a pickup QR to the counter; resolves with the order as it now
  /// stands, so the confirmation can say what moved.
  final Future<CanteenOrder?> Function(String qrPayload)? onScanOrder;
  final VoidCallback? onProfileTap;
  final String? photoUrl;
  final String? displayName;
  final bool isMainHome;

  @override
  State<CanteenCaptainHome> createState() => _CanteenCaptainHomeState();
}

class _CanteenCaptainHomeState extends State<CanteenCaptainHome> {
  /// This screen's own messenger, so confirmations appear inside it, above
  /// its bottom bar, rather than on an enclosing page behind that bar.
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();

  ScaffoldMessengerState get _messenger =>
      _messengerKey.currentState ?? ScaffoldMessenger.of(context);

  var _index = 0;
  var _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      if (mounted) {
        _messenger.showSnackBar(
          SnackBar(
            content: Text(userFacingError(error)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _scanOrder() async {
    final payload = await openScanQr(context, title: 'Scan order QR');
    if (payload == null || !mounted) return;
    await _run(() async {
      final order = await widget.onScanOrder!(payload);
      if (mounted) {
        _messenger.showSnackBar(
          SnackBar(
            content: Text(order?.scanSummary ?? 'Order scanned'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.success,
          ),
        );
      }
    });
  }

  /// The signed-in person, the Work / Shop choice and sign-out.
  void _openFallbackProfileSheet(BuildContext context) {
    showShopAccountSheet(
      context,
      name: widget.displayName ?? widget.store.user.name,
      email: widget.store.user.email,
      photoUrl: widget.photoUrl,
      mode: widget.store.staffState.mode,
      onModeChanged: (mode) => _run(() => widget.onModeChanged(mode)),
      onSignOut: widget.onSignOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.store.orders
        .where((order) => order.status.isActive)
        .toList(growable: false);
    final history =
        widget.store.orders
            .where((order) => !order.status.isActive)
            .toList(growable: false)
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final working = widget.store.staffState.mode == CanteenStaffMode.work;
    final pages = [
      _CaptainQueue(
        orders: active,
        working: working,
        busy: _busy,
        onRefresh: () => _run(widget.onRefresh),
        onStatus: (id, status, {lineIndex}) => _run(
          () => widget.onOrderStatusChanged(id, status, lineIndex: lineIndex),
        ),
        onSwitchToWork: () => _run(() => widget.onModeChanged(CanteenStaffMode.work)),
      ),
      _CaptainHistory(orders: history, onRefresh: () => _run(widget.onRefresh)),
    ];

    final avatarInitials = _initials(widget.displayName ?? widget.store.user.name);

    final scaffold = Scaffold(
      appBar: AppBar(
        titleSpacing: widget.isMainHome ? null : 0,
        leading: widget.isMainHome ? null : ModuleBackButton(onPressed: widget.onExitModule),
        automaticallyImplyLeading: !widget.isMainHome,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Canteen captain'),
            InkWell(
              borderRadius: BorderRadius.circular(4),
              onTap: _busy
                  ? null
                  : () => _run(() => widget.onModeChanged(
                        working ? CanteenStaffMode.eat : CanteenStaffMode.work,
                      )),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    working ? 'Work mode' : 'Shop mode',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.swap_horiz_rounded, size: 14),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: widget.onProfileTap ?? () => _openFallbackProfileSheet(context),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                backgroundImage: widget.photoUrl != null && widget.photoUrl!.isNotEmpty
                    ? NetworkImage(widget.photoUrl!)
                    : null,
                child: widget.photoUrl == null || widget.photoUrl!.isEmpty
                    ? (avatarInitials.isNotEmpty
                        ? Text(
                            avatarInitials,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          )
                        : Icon(Icons.person, size: 20, color: context.adaptive(light: Colors.grey, dark: const Color(0xFF878995))))
                    : null,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_busy) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: IndexedStack(
              index: _index.clamp(0, 1),
              children: pages,
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index.clamp(0, 1),
        onDestinationSelected: (value) {
          if (value == 2) {
            if (!_busy && widget.onScanOrder != null) {
              _scanOrder();
            }
          } else {
            setState(() => _index = value);
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'Orders',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history_rounded),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.qr_code_scanner_rounded),
            selectedIcon: Icon(Icons.qr_code_scanner_rounded),
            label: 'Scan',
          ),
        ],
      ),
    );
    return ScaffoldMessenger(key: _messengerKey, child: scaffold);
  }
}

class _CaptainQueue extends StatelessWidget {
  const _CaptainQueue({
    required this.orders,
    required this.working,
    required this.busy,
    required this.onRefresh,
    required this.onStatus,
    this.onSwitchToWork,
  });

  final List<CanteenOrder> orders;
  final bool working;
  final bool busy;
  final Future<void> Function() onRefresh;
  final void Function(String id, CanteenOrderStatus status, {int? lineIndex})
  onStatus;
  final VoidCallback? onSwitchToWork;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 28),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Live orders',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${orders.length} waiting · tap a name to see items, swipe an item to move just that item',
                      style: TextStyle(color: context.palette.inkSecondary),
                    ),
                  ],
                ),
              ),
              _ModeBadge(working: working),
            ],
          ),
          const SizedBox(height: 18),
          if (!working)
            _ModeNotice(onSwitchToWork: onSwitchToWork)
          else if (orders.isEmpty)
            CanteenSurface(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 34),
                child: Column(
                  children: [
                    Icon(
                      Icons.room_service_outlined,
                      size: 40,
                      color: context.palette.brandInk,
                    ),
                    SizedBox(height: 12),
                    Text('No active food orders.'),
                  ],
                ),
              ),
            )
          else
            for (final group in groupOrdersByCustomer(orders))
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _CustomerOrdersGroup(
                  key: ValueKey('group_${group.customer}'),
                  group: group,
                  enabled: !busy,
                  onStatus: onStatus,
                ),
              ),
        ],
      ),
    );
  }
}

/// One customer's active orders, in queue order.
class CustomerOrderGroup {
  const CustomerOrderGroup({required this.customer, required this.orders});

  final String customer;
  final List<CanteenOrder> orders;

  /// Every food item still at the counter across the orders, one entry per
  /// item line with its index in the order. Delivered items drop out.
  List<(CanteenOrder, CartLine, int)> get items => [
    for (final order in orders)
      for (var i = 0; i < order.lines.length; i++)
        if (order.lineStatus(i).isActive) (order, order.lines[i], i),
  ];
}

/// Groups orders by customer, keeping the queue order of each customer's
/// first order.
List<CustomerOrderGroup> groupOrdersByCustomer(List<CanteenOrder> orders) {
  final grouped = <String, List<CanteenOrder>>{};
  for (final order in orders) {
    final name = order.customerName?.trim();
    final key = (name == null || name.isEmpty) ? 'Campus user' : name;
    grouped.putIfAbsent(key, () => <CanteenOrder>[]).add(order);
  }
  return [
    for (final entry in grouped.entries)
      CustomerOrderGroup(customer: entry.key, orders: entry.value),
  ];
}

/// A dropdown per customer: the header shows how many orders they placed;
/// opened, it lists every food item as its own card (scrollable), each
/// carrying its order's number. Swiping an item card moves only that item;
/// the order settles once every item is delivered.
class _CustomerOrdersGroup extends StatefulWidget {
  const _CustomerOrdersGroup({
    super.key,
    required this.group,
    required this.enabled,
    required this.onStatus,
  });

  final CustomerOrderGroup group;
  final bool enabled;
  final void Function(String id, CanteenOrderStatus status, {int? lineIndex})
  onStatus;

  @override
  State<_CustomerOrdersGroup> createState() => _CustomerOrdersGroupState();
}

class _CustomerOrdersGroupState extends State<_CustomerOrdersGroup> {
  var _open = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final group = widget.group;
    final items = group.items;
    final orderCount = group.orders.length;
    final initials = group.customer
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();

    return CanteenSurface(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            key: ValueKey('group_header_${group.customer}'),
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: palette.brandSoft,
                    child: Text(
                      initials.isEmpty ? '?' : initials,
                      style: TextStyle(
                        color: palette.brandInk,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.customer,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: palette.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${items.length} ${items.length == 1 ? 'item' : 'items'}'
                          ' · ${group.orders.map((o) => '#${o.displayId}').join(', ')}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: palette.inkSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    key: ValueKey('group_count_${group.customer}'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: palette.brand,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$orderCount',
                      style: TextStyle(
                        color: palette.onBrand,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: _open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: palette.inkSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_open)
            ConstrainedBox(
              // Tall enough for about four cards, then it scrolls.
              constraints: const BoxConstraints(maxHeight: 360),
              child: ListView.builder(
                shrinkWrap: true,
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final (order, line, lineIndex) = items[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _CaptainOrderCard(
                      key: ValueKey(
                        '${order.id}_${lineIndex}_${order.lineStatus(lineIndex).name}',
                      ),
                      order: order,
                      line: line,
                      lineIndex: lineIndex,
                      enabled: widget.enabled,
                      onStatus: widget.onStatus,
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _CaptainOrderCard extends StatelessWidget {
  const _CaptainOrderCard({
    super.key,
    required this.order,
    required this.enabled,
    required this.onStatus,
    this.line,
    this.lineIndex,
  });

  final CanteenOrder order;

  /// When set, the card shows only this food item of [order].
  final CartLine? line;

  /// The position of [line] in [order]; swiping then moves only that item.
  final int? lineIndex;

  /// The order as this card sees it: an item card carries its item's status.
  CanteenOrder get _shown => lineIndex == null
      ? order
      : order.copyWith(status: order.lineStatus(lineIndex!));
  final bool enabled;
  final void Function(String id, CanteenOrderStatus status, {int? lineIndex})
  onStatus;

  (CanteenOrderStatus, String, IconData)? get _next {
    final next = lineIndex != null
        ? order.nextLineStep(lineIndex!)
        : (order.nextServiceStep ??
            (order.status.isActive ? CanteenOrderStatus.completed : null));
    if (next == null) return null;
    return switch (next) {
      CanteenOrderStatus.preparing => (
        next,
        'Start preparing',
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
    final next = _next;
    final nextStatus = next?.$1;
    final nextGradient = nextStatus != null
        ? OrderStatusGradients.forStatus(nextStatus)
        : null;
    final nextForeground = nextStatus != null
        ? (nextStatus == CanteenOrderStatus.preparing
            ? const Color(0xFF78350F)
            : Colors.white)
        : Colors.white;

    final firstItem = line?.item ?? order.lines.firstOrNull?.item;
    // An item card shows just its own line; the customer is in the header.
    final shownLines = line != null ? [line!] : order.lines;
    final title = line != null
        ? line!.item.name
        : (order.customerName ?? 'Campus user');

    return SwipeActionCard(
      enabled: enabled,
      dismissOnCommit: next?.$1 == CanteenOrderStatus.completed,
      forward: next == null
          ? null
          : SwipeAction(
              label: next.$2,
              icon: next.$3,
              color: nextGradient?.colors.first ?? context.palette.brand,
              gradient: nextGradient,
              foreground: nextForeground,
              onCommit: () =>
                  onStatus(order.id, next.$1, lineIndex: lineIndex),
            ),
      backward: order.status.canReject
          ? SwipeAction(
              // Rejecting refunds the whole order, so it is named as such.
              label: lineIndex != null ? 'Reject order' : 'Reject',
              icon: Icons.close_rounded,
              color: const Color(0xFFEF4444),
              gradient: OrderStatusGradients.rejected,
              foreground: Colors.white,
              onCommit: () => onStatus(order.id, CanteenOrderStatus.rejected),
            )
          : null,
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
                        color: context.adaptive(light: const Color(0xFFF1F5F9), dark: const Color(0xFF1C1D23)),
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
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: context.adaptive(light: const Color(0xFF1E293B), dark: const Color(0xFFF2F2F5)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text.rich(
                    TextSpan(
                      children: [
                        for (int i = 0; i < shownLines.length; i++) ...[
                          if (i > 0)
                            TextSpan(
                              text: ', ',
                              style: TextStyle(color: context.adaptive(light: const Color(0xFF64748B), dark: const Color(0xFFA3A5B0))),
                            ),
                          TextSpan(
                            text: '${shownLines[i].quantity}× ',
                            style: TextStyle(
                              color: context.palette.brandInk,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          TextSpan(
                            text: line != null
                                ? formatCurrency(shownLines[i].total)
                                : shownLines[i].item.name,
                            style: TextStyle(
                              color: context.adaptive(light: const Color(0xFF64748B), dark: const Color(0xFFA3A5B0)),
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

class _CaptainHistory extends StatelessWidget {
  const _CaptainHistory({required this.orders, required this.onRefresh});

  final List<CanteenOrder> orders;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 28),
        children: [
          Text(
            'Order history',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Completed, rejected and cancelled orders',
            style: TextStyle(color: context.palette.inkSecondary),
          ),
          const SizedBox(height: 18),
          if (orders.isEmpty)
            const CanteenSurface(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: Text('No settled orders yet.')),
              ),
            )
          else
            for (final order in orders)
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: CanteenSurface(
                  key: ValueKey('captain-history-${order.id}'),
                  padding: const EdgeInsets.all(13),
                  onTap: () => openCanteenOrderDetail(context, order),
                  child: Row(
                    children: [
                      Icon(
                        order.status == CanteenOrderStatus.completed
                            ? Icons.check_circle_outline
                            : Icons.cancel_outlined,
                        color: order.status == CanteenOrderStatus.completed
                            ? context.palette.brandInk
                            : context.adaptive(light: const Color(0xFFB42318), dark: const Color(0xFFFCA5A5)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order.customerName ?? 'Campus user',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '#${order.displayId} · ${formatShortDate(order.createdAt)}',
                              style: TextStyle(
                                color: context.palette.inkSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      OrderStatusGradientBadge(
                        status: order.status,
                        fontSize: 10.5,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        formatCurrency(order.total),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: context.palette.inkTertiary,
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _ModeBadge extends StatelessWidget {
  const _ModeBadge({required this.working});
  final bool working;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: context.palette.brandInk.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      working ? 'WORK' : 'EAT',
      style: TextStyle(
        color: context.palette.brandInk,
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
    ),
  );
}

class _ModeNotice extends StatelessWidget {
  const _ModeNotice({this.onSwitchToWork});
  final VoidCallback? onSwitchToWork;

  @override
  Widget build(BuildContext context) => CanteenSurface(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        children: [
          Icon(Icons.restaurant_outlined, size: 39, color: context.palette.brandInk),
          const SizedBox(height: 10),
          const Text(
            'You are in Shop mode',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 5),
          Text(
            'Switch to Work mode to handle orders.',
            style: TextStyle(color: context.palette.inkSecondary),
          ),
          if (onSwitchToWork != null) ...[
            const SizedBox(height: 14),
            FilledButton.tonalIcon(
              onPressed: onSwitchToWork,
              icon: const Icon(Icons.work_outline_rounded, size: 18),
              label: const Text('Switch to Work mode'),
            ),
          ],
        ],
      ),
    ),
  );
}

String _initials(String? name) {
  final parts = (name ?? '')
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty);
  final value = parts.take(2).map((part) => part[0].toUpperCase()).join();
  return value.isEmpty ? 'U' : value;
}
