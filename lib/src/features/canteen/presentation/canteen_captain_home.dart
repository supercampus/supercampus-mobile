import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/module_navigation_buttons.dart';
import '../../../core/widgets/swipe_action_card.dart';
import '../../scanner/presentation/scan_qr_screen.dart';
import '../data/canteen_models.dart';
import 'widgets/canteen_surface.dart';
import 'widgets/menu_item_art.dart';
import 'widgets/order_status_badge.dart';

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
  final Future<void> Function(String orderId, CanteenOrderStatus status)
  onOrderStatusChanged;
  final Future<void> Function(String qrPayload)? onScanOrder;
  final VoidCallback? onProfileTap;
  final String? photoUrl;
  final String? displayName;
  final bool isMainHome;

  @override
  State<CanteenCaptainHome> createState() => _CanteenCaptainHomeState();
}

class _CanteenCaptainHomeState extends State<CanteenCaptainHome> {
  var _index = 0;
  var _busy = false;

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

  Future<void> _scanOrder() async {
    final payload = await openScanQr(context, title: 'Scan order QR');
    if (payload == null || !mounted) return;
    await _run(() async {
      await widget.onScanOrder!(payload);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order delivered successfully!'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.success,
          ),
        );
      }
    });
  }

  void _openFallbackProfileSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              CircleAvatar(
                radius: 40,
                backgroundColor: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                backgroundImage: widget.photoUrl != null && widget.photoUrl!.isNotEmpty
                    ? NetworkImage(widget.photoUrl!)
                    : null,
                child: widget.photoUrl == null || widget.photoUrl!.isEmpty
                    ? Text(
                        _initials(widget.displayName ?? widget.store.user.name),
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      )
                    : null,
              ),
              const SizedBox(height: 14),
              Text(
                widget.displayName ?? widget.store.user.name,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                widget.store.user.email,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),
              const Divider(height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.logout, color: Theme.of(ctx).colorScheme.error),
                title: Text(
                  'Sign out',
                  style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  widget.onSignOut();
                },
              ),
            ],
          ),
        ),
      ),
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
        onStatus: (id, status) =>
            _run(() => widget.onOrderStatusChanged(id, status)),
        onSwitchToWork: () => _run(() => widget.onModeChanged(CanteenStaffMode.work)),
      ),
      _CaptainHistory(orders: history, onRefresh: () => _run(widget.onRefresh)),
    ];

    final avatarInitials = _initials(widget.displayName ?? widget.store.user.name);

    return Scaffold(
      appBar: AppBar(
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
                    working ? 'Work mode' : 'Eat mode',
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
                        : const Icon(Icons.person, size: 20, color: Colors.grey))
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
  final void Function(String id, CanteenOrderStatus status) onStatus;
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
                      '${orders.length} waiting · swipe a card to update it',
                      style: const TextStyle(color: AppColors.muted),
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
            const CanteenSurface(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 34),
                child: Column(
                  children: [
                    Icon(
                      Icons.room_service_outlined,
                      size: 40,
                      color: AppColors.primary,
                    ),
                    SizedBox(height: 12),
                    Text('No active food orders.'),
                  ],
                ),
              ),
            )
          else
            for (final order in orders)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _CaptainOrderCard(
                  order: order,
                  enabled: !busy,
                  onStatus: onStatus,
                ),
              ),
        ],
      ),
    );
  }
}

class _CaptainOrderCard extends StatelessWidget {
  const _CaptainOrderCard({
    required this.order,
    required this.enabled,
    required this.onStatus,
  });

  final CanteenOrder order;
  final bool enabled;
  final void Function(String id, CanteenOrderStatus status) onStatus;

  (CanteenOrderStatus, String, IconData)? get _next {
    final next = order.status.nextServiceStep;
    return switch (next) {
      CanteenOrderStatus.preparing => (
        next!,
        'Start preparing',
        Icons.local_fire_department_outlined,
      ),
      CanteenOrderStatus.ready => (
        next!,
        'Mark ready',
        Icons.room_service_outlined,
      ),
      CanteenOrderStatus.completed => (
        next!,
        'Handed over',
        Icons.check_circle_outline,
      ),
      _ => null,
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
        ? OrderStatusGradients.textColorForStatus(nextStatus)
        : Colors.white;

    final firstItem = order.lines.firstOrNull?.item;

    return SwipeActionCard(
      enabled: enabled,
      forward: next == null
          ? null
          : SwipeAction(
              label: next.$2,
              icon: next.$3,
              color: nextGradient?.colors.first ?? AppColors.primary,
              gradient: nextGradient,
              foreground: nextForeground,
              onCommit: () => onStatus(order.id, next.$1),
            ),
      backward: order.status.canReject
          ? SwipeAction(
              label: 'Reject',
              icon: Icons.close_rounded,
              color: const Color(0xFFEF4444),
              gradient: OrderStatusGradients.rejected,
              foreground: Colors.white,
              onCommit: () => onStatus(order.id, CanteenOrderStatus.rejected),
            )
          : null,
      child: CanteenSurface(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: firstItem != null
                      ? MenuItemArt(item: firstItem, size: 44)
                      : Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.restaurant_rounded,
                            size: 22,
                            color: AppColors.primary,
                          ),
                        ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.customerName ?? 'Campus user',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '#${order.displayId}${order.tokenNumber == null ? '' : ' · Token ${order.tokenNumber}'} · ${formatCurrency(order.total)}',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                OrderStatusGradientBadge(status: order.status),
              ],
            ),
            const Divider(height: 18),
            for (int i = 0; i < order.lines.length; i++)
              Padding(
                padding: EdgeInsets.only(
                  bottom: i == order.lines.length - 1 ? 0 : 5,
                ),
                child: Row(
                  children: [
                    Text(
                      '${order.lines[i].quantity}×',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        order.lines[i].item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      formatCurrency(order.lines[i].total),
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
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
          const Text(
            'Completed, rejected and cancelled orders',
            style: TextStyle(color: AppColors.muted),
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
                  padding: const EdgeInsets.all(13),
                  child: Row(
                    children: [
                      Icon(
                        order.status == CanteenOrderStatus.completed
                            ? Icons.check_circle_outline
                            : Icons.cancel_outlined,
                        color: order.status == CanteenOrderStatus.completed
                            ? AppColors.primary
                            : const Color(0xFFB42318),
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
                              style: const TextStyle(
                                color: AppColors.muted,
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
      color: AppColors.primary.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      working ? 'WORK' : 'EAT',
      style: const TextStyle(
        color: AppColors.primary,
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
          const Icon(Icons.restaurant_outlined, size: 39, color: AppColors.primary),
          const SizedBox(height: 10),
          const Text(
            'You are in eat mode',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 5),
          const Text(
            'Switch to Work mode to handle orders.',
            style: TextStyle(color: AppColors.muted),
          ),
          if (onSwitchToWork != null) ...[
            const SizedBox(height: 14),
            FilledButton.tonalIcon(
              onPressed: onSwitchToWork,
              icon: const Icon(Icons.work_outline_rounded, size: 18),
              label: const Text('Switch to work mode'),
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
