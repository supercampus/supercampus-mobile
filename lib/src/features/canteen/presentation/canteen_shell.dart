import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/widgets/skeleton_loading.dart';
import '../../../screens/tuition_fee/razorpay_checkout.dart';
import '../../authentication/data/auth_repository.dart';
import '../data/backend_canteen_repository.dart';
import '../data/canteen_models.dart';
import '../data/canteen_repository.dart';
import '../data/mock_canteen_repository.dart';
import 'canteen_cart_screen.dart';
import 'canteen_captain_home.dart';
import 'canteen_owner_home.dart';
import 'canteen_orders_screen.dart';
import 'canteen_scanner_screen.dart';
import 'stationery_operator_home.dart';
import 'student_canteen_home.dart';
import 'student_canteen_profile_screen.dart';
import 'student_wallet_screen.dart';

class CanteenShell extends StatefulWidget {
  const CanteenShell({
    super.key,
    required this.session,
    required this.onExitModule,
    required this.onSignOut,
    this.repository,
    this.initialAction,
  });

  final StudentSession session;
  final VoidCallback onExitModule;
  final VoidCallback onSignOut;
  final CanteenRepository? repository;
  final String? initialAction;

  @override
  State<CanteenShell> createState() => _CanteenShellState();
}

class _CanteenShellState extends State<CanteenShell> {
  late final CanteenRepository _repository;
  final Map<String, int> _cart = {};
  CanteenStore? _store;
  String? _error;
  var _selectedIndex = 0;
  Timer? _refreshTimer;
  var _loadInProgress = false;
  var _ownerWorkMode = true;

  bool get _canUseWorkMode {
    final session = widget.session;
    return _store?.canManage == true &&
        session.role != UserRole.student &&
        session.activePortalFamily != PortalFamily.student;
  }

  bool get _isStationeryOperator {
    final roles = <String>{
      widget.session.roleKey,
      ...widget.session.roleIds,
    }.map((role) => role.trim().toLowerCase());
    return roles.contains('stationery_operator');
  }

  @override
  void initState() {
    super.initState();
    _repository =
        widget.repository ??
        MockCanteenRepository(
          studentName: widget.session.displayName,
          email: widget.session.email,
        );
    _selectedIndex =
        const {'orders', 'order_history'}.contains(widget.initialAction)
        ? 1
        : 0;
    _loadStore();
    if (widget.repository != null) {
      _refreshTimer = Timer.periodic(
        const Duration(seconds: 3),
        (_) => _loadStore(silent: true),
      );
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadStore({bool silent = false}) async {
    if (_loadInProgress) return;
    _loadInProgress = true;
    if (!silent) setState(() => _error = null);
    try {
      final store = await _repository.loadStore();
      if (mounted) {
        setState(() => _store = store);
        if (widget.initialAction == 'wallet') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _openWallet(context);
          });
        }
      }
    } catch (_) {
      if (mounted && !silent) {
        setState(() {
          _error =
              'The canteen menu is unavailable. Check your connection and retry.';
        });
      }
    } finally {
      _loadInProgress = false;
    }
  }

  Future<void> _updateOwnerMode(CanteenStaffMode mode) async {
    final state = await _repository.updateStaffState(
      mode: mode,
      shopOpen: _store?.staffState.shopOpen,
    );
    if (!mounted || _store == null) return;
    setState(() {
      _ownerWorkMode = mode == CanteenStaffMode.work;
      _store = _store!.copyWith(staffState: state);
    });
  }

  Future<void> _updateShopOpen(bool open) async {
    final state = await _repository.updateStaffState(
      mode: CanteenStaffMode.work,
      shopOpen: open,
    );
    if (!mounted || _store == null) return;
    setState(() => _store = _store!.copyWith(staffState: state));
  }

  Future<void> _updateOrderStatus(
    String orderId,
    CanteenOrderStatus status,
  ) async {
    await _repository.updateOrderStatus(orderId, status);
    await _loadStore(silent: true);
  }

  Future<void> _saveMenuItem(CanteenMenuItem item, bool create) async {
    await _repository.saveMenuItem(item, create: create);
    await _loadStore(silent: true);
  }

  Future<void> _deleteMenuItem(String itemId) async {
    await _repository.deleteMenuItem(itemId);
    await _loadStore(silent: true);
  }

  void _addItem(CanteenMenuItem item) {
    final current = _cart[item.id] ?? 0;
    if (current >= 10) return;
    setState(() => _cart[item.id] = current + 1);
  }

  void _removeItem(CanteenMenuItem item) {
    final current = _cart[item.id] ?? 0;
    setState(() {
      if (current <= 1) {
        _cart.remove(item.id);
      } else {
        _cart[item.id] = current - 1;
      }
    });
  }

  List<CartLine> _cartLines() {
    final store = _store!;
    return store.menu
        .where((item) => (_cart[item.id] ?? 0) > 0)
        .map((item) => CartLine(item: item, quantity: _cart[item.id]!))
        .toList();
  }

  Future<OrderPlacementResult> _placeOrder() async {
    final result = await _repository.placeOrder(lines: _cartLines());
    if (!mounted) return result;
    final store = _store!;
    setState(() {
      // A cart spanning shops comes back as several orders, each with its own
      // QR, paid from the one wallet.
      _store = store.copyWith(
        walletBalance: result.balance,
        orders: [...result.orders, ...store.orders],
        walletTransactions: [
          ...result.transactions,
          ...store.walletTransactions,
        ],
      );
      _cart.clear();
      _selectedIndex = 1;
    });
    return result;
  }

  Future<WalletTopUpResult> _topUpWallet(double amount) async {
    final result = switch (_repository) {
      BackendCanteenRepository backend => await _payWalletTopUp(
        backend,
        amount,
      ),
      _ => await _repository.topUpWallet(amount),
    };
    if (!mounted) return result;
    final store = _store!;
    setState(() {
      _store = store.copyWith(
        walletBalance: result.balance,
        walletTransactions: [result.transaction, ...store.walletTransactions],
      );
    });
    return result;
  }

  Future<WalletTopUpResult> _payWalletTopUp(
    BackendCanteenRepository repository,
    double amount,
  ) async {
    try {
      final order = await repository.createWalletTopUpOrder(amount);
      final checkout = await const RazorpayCheckoutClient().open(
        keyId: order.keyId,
        orderId: order.id,
        amount: order.amount,
        currency: order.currency,
        name: 'SuperCampus',
        description: 'Campus shop wallet top-up',
        customerName: widget.session.displayName,
        customerEmail: widget.session.email,
      );
      return await repository.verifyWalletTopUp(
        paymentId: checkout.paymentId,
        orderId: checkout.orderId,
        signature: checkout.signature,
      );
    } on RazorpayCheckoutException catch (error) {
      throw CanteenException(error.message);
    }
  }

  Future<void> _openCart(BuildContext context) async {
    final store = _store!;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.94,
        child: CanteenCartScreen(
          menu: store.menu,
          cart: _cart,
          walletBalance: store.walletBalance,
          onAdd: _addItem,
          onRemove: _removeItem,
          onPlaceOrder: _placeOrder,
        ),
      ),
    );
  }

  Future<void> _openWallet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.84,
        child: StudentWalletSheet(store: _store!, onTopUp: _topUpWallet),
      ),
    );
  }

  Future<void> _openProfile(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => StudentCanteenProfileScreen(
          store: _store!,
          onOpenWallet: () => _openWallet(context),
          onSignOut: () {
            Navigator.of(context).pop();
            widget.onSignOut();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = _store;
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_off_outlined,
                  size: 44,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _loadStore,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (store == null) {
      return const Scaffold(body: SkeletonList(rows: 6, rowHeight: 84));
    }

    if (_isStationeryOperator) {
      return StationeryOperatorHome(
        store: store,
        initialAction: widget.initialAction,
        onExitModule: widget.onExitModule,
        onSignOut: widget.onSignOut,
        onRefresh: () => _loadStore(silent: true),
        onCounterStateChanged: _updateOwnerMode,
        onOrderStatusChanged: _updateOrderStatus,
        onSaveItem: (item) => _saveMenuItem(item, false),
        onUploadMedia: (bytes, filename) =>
            _repository.uploadMedia(bytes, filename: filename),
      );
    }

    if (store.canManage && !store.canManageMenu) {
      return CanteenCaptainHome(
        store: store,
        onExitModule: widget.onExitModule,
        onSignOut: widget.onSignOut,
        onRefresh: () => _loadStore(silent: true),
        onModeChanged: _updateOwnerMode,
        onOrderStatusChanged: _updateOrderStatus,
      );
    }

    if (_canUseWorkMode && _ownerWorkMode) {
      final ownerStore = store.staffState.mode == CanteenStaffMode.work
          ? store
          : store.copyWith(
              staffState: CanteenStaffState(
                mode: CanteenStaffMode.work,
                shopOpen: store.staffState.shopOpen,
              ),
            );
      return CanteenOwnerHome(
        store: ownerStore,
        onExitModule: widget.onExitModule,
        onSignOut: widget.onSignOut,
        onRefresh: () => _loadStore(silent: true),
        onModeChanged: _updateOwnerMode,
        onShopOpenChanged: _updateShopOpen,
        onOrderStatusChanged: _updateOrderStatus,
        onSaveMenuItem: _saveMenuItem,
        onDeleteMenuItem: _deleteMenuItem,
        onUploadMedia: (bytes, filename) =>
            _repository.uploadMedia(bytes, filename: filename),
      );
    }

    final pages = [
      StudentCanteenHome(
        store: store,
        cart: _cart,
        onAdd: _addItem,
        onRemove: _removeItem,
        onOpenCart: () => _openCart(context),
        onOpenWallet: () => _openWallet(context),
        onOpenProfile: () => _openProfile(context),
        onExitModule: widget.onExitModule,
        onWorkMode: _canUseWorkMode
            ? () => _updateOwnerMode(CanteenStaffMode.work)
            : null,
      ),
      CanteenOrdersScreen(
        orders: store.orders,
        onBack: () => setState(() => _selectedIndex = 0),
      ),
      CanteenScannerScreen(
        onScan: (payload) async {
          await _repository.scanOrder(payload);
          await _loadStore(silent: true);
        },
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: pages),
    );
  }
}
