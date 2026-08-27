import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/module_navigation_buttons.dart';
import '../../../core/widgets/swipe_action_card.dart';
import '../data/canteen_models.dart';
import 'widgets/canteen_surface.dart';

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
  });

  final CanteenStore store;
  final VoidCallback onExitModule;
  final VoidCallback onSignOut;
  final Future<void> Function() onRefresh;
  final Future<void> Function(CanteenStaffMode mode) onModeChanged;
  final Future<void> Function(String orderId, CanteenOrderStatus status)
  onOrderStatusChanged;

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
      ),
      _CaptainHistory(orders: history, onRefresh: () => _run(widget.onRefresh)),
      _CaptainProfile(
        store: widget.store,
        busy: _busy,
        onMode: (mode) => _run(() => widget.onModeChanged(mode)),
        onSignOut: widget.onSignOut,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        leading: ModuleBackButton(onPressed: widget.onExitModule),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Canteen captain'),
            Text(
              working ? 'Work mode' : 'Eat mode',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh orders',
            onPressed: _busy ? null : () => _run(widget.onRefresh),
            icon: const Icon(Icons.refresh),
          ),
          ModuleHomeButton(onPressed: widget.onExitModule),
        ],
      ),
      body: Column(
        children: [
          if (_busy) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: IndexedStack(index: _index, children: pages),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Orders',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
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
  });

  final List<CanteenOrder> orders;
  final bool working;
  final bool busy;
  final Future<void> Function() onRefresh;
  final void Function(String id, CanteenOrderStatus status) onStatus;

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
            const _ModeNotice()
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
    return SwipeActionCard(
      enabled: enabled,
      forward: next == null
          ? null
          : SwipeAction(
              label: next.$2,
              icon: next.$3,
              color: AppColors.primary,
              onCommit: () => onStatus(order.id, next.$1),
            ),
      backward: order.status.canReject
          ? SwipeAction(
              label: 'Reject',
              icon: Icons.close_rounded,
              color: const Color(0xFFB42318),
              onCommit: () => onStatus(order.id, CanteenOrderStatus.rejected),
            )
          : null,
      child: CanteenSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primary.withValues(alpha: .1),
                  foregroundColor: AppColors.primary,
                  child: Text(_initials(order.customerName)),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.customerName ?? 'Campus user',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '#${order.displayId}${order.tokenNumber == null ? '' : ' · Token ${order.tokenNumber}'}',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  order.status.label,
                  style: const TextStyle(color: AppColors.primary),
                ),
              ],
            ),
            const Divider(height: 25),
            for (final line in order.lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  children: [
                    Text(
                      '${line.quantity}×',
                      style: const TextStyle(color: AppColors.primary),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(line.item.name)),
                    Text(formatCurrency(line.total)),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.swipe_outlined,
                  size: 17,
                  color: AppColors.muted,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    next == null ? 'Order settled' : 'Swipe right: ${next.$2}',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ),
                Text(
                  formatCurrency(order.total),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
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
                            Text(
                              '#${order.displayId} · ${order.status.label} · ${formatShortDate(order.createdAt)}',
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
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

class _CaptainProfile extends StatelessWidget {
  const _CaptainProfile({
    required this.store,
    required this.busy,
    required this.onMode,
    required this.onSignOut,
  });

  final CanteenStore store;
  final bool busy;
  final void Function(CanteenStaffMode mode) onMode;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final mode = store.staffState.mode;
    final shopNames = store.shops
        .where((shop) => store.assignedShopKeys.contains(shop.shopKey))
        .map((shop) => shop.name)
        .join(', ');
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 28),
      children: [
        Text(
          'Captain profile',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4200FF), Color(0xFF9600FF)],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 31,
                backgroundColor: Colors.white.withValues(alpha: .18),
                foregroundColor: Colors.white,
                child: Text(
                  store.user.initials,
                  style: const TextStyle(fontSize: 22),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      store.user.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      store.user.email,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      shopNames.isEmpty
                          ? 'Canteen captain'
                          : '$shopNames · Captain',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        CanteenSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Eat / work mode',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 5),
              const Text(
                'Work shows the live counter queue. Eat pauses order handling.',
                style: TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 14),
              SegmentedButton<CanteenStaffMode>(
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
                selected: {mode},
                onSelectionChanged: busy
                    ? null
                    : (selection) => onMode(selection.first),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: onSignOut,
          icon: const Icon(Icons.logout),
          label: const Text('Sign out'),
        ),
      ],
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
  const _ModeNotice();

  @override
  Widget build(BuildContext context) => const CanteenSurface(
    child: Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(Icons.restaurant_outlined, size: 39, color: AppColors.primary),
          SizedBox(height: 10),
          Text(
            'You are in eat mode',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 5),
          Text(
            'Switch to Work in Profile to handle orders.',
            style: TextStyle(color: AppColors.muted),
          ),
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
