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
          SnackBar(
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
      backgroundColor: context.palette.surfaceRaised,
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
                  color: context.adaptive(light: Colors.grey.shade300, dark: const Color(0xFF3A3B44)),
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
                style: TextStyle(fontSize: 14, color: context.adaptive(light: Colors.grey.shade600, dark: const Color(0xFFA3A5B0))),
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
            for (final order in orders)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _CaptainOrderCard(
                  key: ValueKey('${order.id}_${order.status.name}'),
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
    super.key,
    required this.order,
    required this.enabled,
    required this.onStatus,
  });

  final CanteenOrder order;
  final bool enabled;
  final void Function(String id, CanteenOrderStatus status) onStatus;

  (CanteenOrderStatus, String, IconData)? get _next {
    final next = order.nextServiceStep ??
        (order.status.isActive ? CanteenOrderStatus.completed : null);
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

    final firstItem = order.lines.firstOrNull?.item;

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
                    order.customerName ?? 'Campus user',
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
                        for (int i = 0; i < order.lines.length; i++) ...[
                          if (i > 0)
                            TextSpan(
                              text: ', ',
                              style: TextStyle(color: context.adaptive(light: const Color(0xFF64748B), dark: const Color(0xFFA3A5B0))),
                            ),
                          TextSpan(
                            text: '${order.lines[i].quantity}× ',
                            style: TextStyle(
                              color: context.palette.brandInk,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          TextSpan(
                            text: order.lines[i].item.name,
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
            OrderNumberStatusBadge(order: order),
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
                  padding: const EdgeInsets.all(13),
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
            'You are in eat mode',
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
