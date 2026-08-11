import 'package:flutter/material.dart';

import '../../authentication/data/auth_repository.dart';
import '../data/canteen_models.dart';
import '../data/canteen_repository.dart';
import '../data/mock_canteen_repository.dart';
import 'canteen_cart_screen.dart';
import 'canteen_orders_screen.dart';
import 'canteen_scanner_screen.dart';
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

  @override
  void initState() {
    super.initState();
    _repository =
        widget.repository ??
        MockCanteenRepository(
          studentName: widget.session.displayName,
          email: widget.session.email,
        );
    _selectedIndex = widget.initialAction == 'orders' ? 1 : 0;
    _loadStore();
  }

  Future<void> _loadStore() async {
    setState(() => _error = null);
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
      if (mounted) {
        setState(() {
          _error =
              'The canteen menu is unavailable. Check your connection and retry.';
        });
      }
    }
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

  Future<OrderPlacementResult> _placeOrder(FulfilmentMode mode) async {
    final result = await _repository.placeOrder(
      lines: _cartLines(),
      fulfilmentMode: mode,
    );
    if (!mounted) return result;
    final store = _store!;
    setState(() {
      _store = store.copyWith(
        walletBalance: result.balance,
        orders: [result.order, ...store.orders],
        walletTransactions: [result.transaction, ...store.walletTransactions],
      );
      _cart.clear();
      _selectedIndex = 1;
    });
    return result;
  }

  Future<WalletTopUpResult> _topUpWallet(double amount) async {
    final result = await _repository.topUpWallet(amount);
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
      return const Scaffold(
        body: Center(
          child: SizedBox.square(
            dimension: 30,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
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
      ),
      CanteenOrdersScreen(orders: store.orders),
      const CanteenScannerScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: pages),
    );
  }
}
