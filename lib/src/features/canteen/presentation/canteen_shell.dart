import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/skeleton_loading.dart';
import '../../../screens/tuition_fee/razorpay_checkout.dart';
import '../../authentication/data/auth_repository.dart';
import '../../library/data/librarian_repository.dart';
import '../../modules/presentation/today_glance.dart';
import '../data/backend_canteen_repository.dart';
import '../data/canteen_events.dart';
import '../data/canteen_models.dart';
import '../data/canteen_repository.dart';
import '../data/mock_canteen_repository.dart';
import '../data/shop_analytics.dart';
import '../data/wallet_pin_repository.dart';
import '../data/wallet_transaction_detail.dart';
import '../../scanner/presentation/scan_qr_screen.dart';
import 'canteen_cart_screen.dart';
import 'canteen_captain_home.dart';
import 'laundry_operator_home.dart';
import 'canteen_owner_home.dart';
import 'owner_workspace_nav.dart';
import 'canteen_orders_screen.dart';
import 'canteen_scanner_screen.dart';
import 'stationery_operator_home.dart';
import 'student_canteen_home.dart';
import 'student_wallet_screen.dart';
import 'widgets/shop_mode_switch.dart';

class CanteenShell extends StatefulWidget {
  const CanteenShell({
    super.key,
    required this.session,
    required this.onExitModule,
    required this.onSignOut,
    this.repository,
    this.initialAction,
    this.onAlertsTap,
    this.onProfileTap,
    this.hasAlerts = false,
    this.photoUrl,
    this.isMainHome = false,
    this.initialStaffMode,
    this.onStaffModeChanged,
    this.onOpenModule,
    this.glance,
    this.announcements,
    this.ownerNav,
  });

  final StudentSession session;
  final VoidCallback onExitModule;
  final VoidCallback onSignOut;
  final CanteenRepository? repository;
  final String? initialAction;
  final VoidCallback? onAlertsTap;
  final VoidCallback? onProfileTap;
  final bool hasAlerts;
  final String? photoUrl;
  final bool isMainHome;
  final CanteenStaffMode? initialStaffMode;
  final ValueChanged<CanteenStaffMode>? onStaffModeChanged;
  final ValueChanged<String>? onOpenModule;
  final GlanceFacts? glance;
  final List<LibraryAnnouncement>? announcements;

  /// Lets the host's bottom bar open the owner workspace's sections.
  final OwnerWorkspaceNav? ownerNav;

  @override
  State<CanteenShell> createState() => _CanteenShellState();
}

class _CanteenShellState extends State<CanteenShell> {
  late final CanteenRepository _repository;
  final Map<String, int> _cart = {};
  CanteenStore? _store;
  String? _error;
  var _selectedIndex = 0;
  var _openedOrdersFromHome = false;
  Timer? _refreshTimer;
  var _loadInProgress = false;
  var _ownerWorkMode = true;

  /// Everyone with a job in the shops or offices can switch between Work and
  /// Shop. Students only ever shop.
  bool get _canUseWorkMode {
    final session = widget.session;
    return (_hasCounterWork || session.isAccountant) &&
        session.role != UserRole.student &&
        session.activePortalFamily != PortalFamily.student;
  }

  /// Whether Work mode has a surface inside this module: a counter to run, or
  /// (with the shop-configuration grant) the shops to oversee. An accountant's
  /// work is the recharge desk, which lives outside it.
  bool get _hasCounterWork {
    final session = widget.session;
    return _store?.canManage == true ||
        session.isCaptain ||
        session.isCanteenOwner ||
        session.isStationeryOwner ||
        _isStationeryOperator ||
        _isLaundryOperator;
  }

  String? get _userId => _store?.user.id;

  bool get _isStationeryOperator {
    final lowerEmail = widget.session.email.trim().toLowerCase();
    if (lowerEmail == 'stationary@mec.local' ||
        lowerEmail == 'stationery@mec.local' ||
        lowerEmail.contains('stationery') ||
        lowerEmail.contains('stationary')) {
      return true;
    }
    if (widget.session.isStationeryOwner) {
      return true;
    }
    final roles = <String>{
      widget.session.roleKey,
      ...widget.session.roleIds,
    }.map((role) => role.trim().toLowerCase());
    return roles.contains('stationery_operator') ||
        roles.contains('stationery_owner') ||
        roles.contains('stationery') ||
        roles.contains('stationary');
  }

  bool get _isLaundryOperator =>
      widget.session.email.trim().toLowerCase() == 'laundry@mec.local' ||
      (!widget.session.isCanteenOwner &&
          _store?.canManage == true &&
          _store!.assignedShopKeys.contains('mec-laundry'));

  /// Whether the launching 'wallet' action has already opened the wallet.
  bool _walletActionHandled = false;

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
    _openedOrdersFromHome = false;
    // "shop" opens the module as a customer, whatever the last mode was.
    _ownerWorkMode = widget.initialAction == 'shop'
        ? false
        : widget.initialStaffMode == null
        ? true
        : widget.initialStaffMode == CanteenStaffMode.work;
    _loadStore();
    canteenRevision.addListener(_onCanteenChanged);
    if (widget.repository != null) {
      _refreshTimer = Timer.periodic(_fallbackRefresh, (_) => _loadStore(silent: true));
    }
  }

  @override
  void didUpdateWidget(CanteenShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialStaffMode != null &&
        widget.initialStaffMode != oldWidget.initialStaffMode) {
      _ownerWorkMode = widget.initialStaffMode == CanteenStaffMode.work;
    }
    if (widget.initialAction != oldWidget.initialAction) {
      // A new launching action may open the wallet again, once.
      _walletActionHandled = false;
      if (widget.initialAction == 'shop') _ownerWorkMode = false;
    }
    if (widget.initialAction != null &&
        oldWidget.initialAction != widget.initialAction) {
      if (const {'orders', 'order_history'}.contains(widget.initialAction)) {
        setState(() {
          _selectedIndex = 1;
          _openedOrdersFromHome = false;
        });
      } else if (widget.initialAction == 'menu') {
        setState(() => _selectedIndex = 0);
      }
    }
    if (oldWidget.repository != widget.repository) {
      _refreshTimer?.cancel();
      _refreshTimer = null;
      _repository =
          widget.repository ??
          MockCanteenRepository(
            studentName: widget.session.displayName,
            email: widget.session.email,
          );
      _loadStore(silent: _store != null);
      if (widget.repository != null) {
        _refreshTimer = Timer.periodic(_fallbackRefresh, (_) => _loadStore(silent: true));
      }
    }
  }

  /// Realtime `canteen.*` events reload the store as soon as something
  /// changes; this timer is only the fallback. It used to be the sole source
  /// and ran every 3 s, which was hundreds of requests per session.
  static const _fallbackRefresh = Duration(seconds: 15);

  void _onCanteenChanged() {
    if (mounted) _loadStore(silent: true);
  }

  @override
  void dispose() {
    canteenRevision.removeListener(_onCanteenChanged);
    _refreshTimer?.cancel();
    super.dispose();
  }

  /// Bumped whenever the counter changes an order on screen ahead of the
  /// server. A reload that started before such a change carries the old
  /// state, so it is dropped and fetched again rather than flashing back.
  var _localEdits = 0;

  Future<void> _loadStore({bool silent = false}) async {
    if (_loadInProgress) return;
    _loadInProgress = true;
    if (!silent) setState(() => _error = null);
    var stale = false;
    try {
      final edits = _localEdits;
      final store = await _repository.loadStore();
      stale = edits != _localEdits;
      if (mounted && !stale) {
        setState(() => _store = store);
        // Open the wallet once for the action that launched the module. The
        // store also reloads silently in the background; replaying the action
        // on every reload stacked a new wallet sheet each time, so closing it
        // appeared to do nothing.
        if (widget.initialAction == 'wallet' && !_walletActionHandled) {
          _walletActionHandled = true;
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
    if (stale && mounted) unawaited(_loadStore(silent: true));
  }

  /// Switches between Work and Shop. The screen answers at once; the stored
  /// preference follows. It is only a preference, so a failed save leaves the
  /// person where they asked to be rather than bouncing them back.
  Future<void> _updateOwnerMode(CanteenStaffMode mode) async {
    final working = mode == CanteenStaffMode.work;
    if (working && !_hasCounterWork) {
      // An accountant's work is the recharge desk, outside this module.
      widget.onStaffModeChanged?.call(mode);
      widget.onExitModule();
      return;
    }
    setState(() {
      _ownerWorkMode = working;
      _cart.clear();
      _selectedIndex = 0;
      _openedOrdersFromHome = false;
    });
    widget.onStaffModeChanged?.call(mode);
    try {
      // The counter's open state is not part of this choice.
      final state = await _repository.updateStaffState(mode: mode);
      if (!mounted || _store == null) return;
      setState(() {
        _store = _store!.copyWith(
          staffState: CanteenStaffState(
            mode: state.mode,
            shopOpen: state.shopOpen ?? _store!.staffState.shopOpen,
          ),
        );
      });
    } catch (_) {
      if (!mounted || _store == null) return;
      setState(() {
        _store = _store!.copyWith(
          staffState: CanteenStaffState(
            mode: mode,
            shopOpen: _store!.staffState.shopOpen,
          ),
        );
      });
    }
  }

  /// The store as a customer sees it: their own orders, their own laundry
  /// charges, and every shop. An operator's payload also carries their
  /// counter's queue and charges, which belong to Work.
  CanteenStore _shopView(CanteenStore store) {
    final me = _userId;
    if (me == null) return store;
    final ownsCharges = store.laundryCharges.any(
      (charge) => charge.claimedBy != null,
    );
    return store.copyWith(
      orders: [
        for (final order in store.orders)
          if (order.customerUserId == null || order.customerUserId == me) order,
      ],
      laundryCharges: ownsCharges
          ? [
              for (final charge in store.laundryCharges)
                if (charge.claimedBy == me) charge,
            ]
          : null,
    );
  }

  /// The store as the counter sees it: the person's own purchases from other
  /// shops are not part of their queue.
  CanteenStore _workView(CanteenStore store) {
    final me = _userId;
    final assigned = store.assignedShopKeys.toSet();
    if (me == null || assigned.isEmpty) return store;
    return store.copyWith(
      orders: [
        for (final order in store.orders)
          if (order.customerUserId != me ||
              order.lines.any(
                (line) => assigned.contains(line.item.effectiveShopKey),
              ))
            order,
      ],
    );
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
    CanteenOrderStatus status, {
    int? lineIndex,
  }) async {
    // The card moves the moment it is swiped; the server confirms behind it.
    // Waiting for the request and then a full store reload is what made a
    // swipe take seconds to show.
    final previous = _store;
    if (previous != null) {
      _localEdits++;
      setState(() {
        _store = previous.copyWith(
          orders: [
            for (final order in previous.orders)
              if (order.id != orderId)
                order
              else if (lineIndex != null && lineIndex < order.lines.length)
                order.withLineStatus(lineIndex, status)
              else
                order.copyWith(status: status),
          ],
        );
      });
    }
    try {
      await _repository.updateOrderStatus(
        orderId,
        status,
        lineIndex: lineIndex,
      );
    } catch (_) {
      // Put the card back where the server still has it.
      if (mounted && previous != null) {
        _localEdits++;
        setState(() => _store = previous);
      }
      rethrow;
    } finally {
      _localEdits++;
    }
    unawaited(_loadStore(silent: true));
  }

  Future<void> _saveMenuItem(CanteenMenuItem item, bool create) async {
    await _repository.saveMenuItem(item, create: create);
    await _loadStore(silent: true);
  }

  Future<void> _deleteMenuItem(String itemId) async {
    await _repository.deleteMenuItem(itemId);
    await _loadStore(silent: true);
  }

  Future<double> _updateLaundryPrice(double price) async {
    final saved = await _repository.updateLaundryPrice(price);
    await _loadStore(silent: true);
    return saved;
  }

  Future<LaundryCharge> _createLaundryCharge({
    required LaundryServiceType serviceType,
    required String name,
    required String description,
    required double quantity,
    double? price,
  }) async {
    final charge = await _repository.createLaundryCharge(
      serviceType: serviceType,
      name: name,
      description: description,
      quantity: quantity,
      price: price,
    );
    await _loadStore(silent: true);
    return charge;
  }

  Future<void> _payLaundryCharge(LaundryCharge charge) async {
    final result = await _repository.payLaundryCharge(charge.id);
    if (!mounted || _store == null) return;
    setState(() {
      _store = _store!.copyWith(
        walletBalances: {
          ..._store!.walletBalances,
          'mec-laundry': result.balance,
        },
        laundryCharges: [
          for (final value in _store!.laundryCharges)
            if (value.id == result.charge.id) result.charge else value,
        ],
        walletTransactions: [result.transaction, ..._store!.walletTransactions],
      );
    });
  }

  Future<void> _scanLaundryQr(BuildContext context) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final payload = await openScanQr(context, title: 'Scan laundry QR');
    if (payload == null || !mounted) return;
    try {
      final charge = await _repository.claimLaundryCharge(payload);
      await _loadStore(silent: true);
      if (!mounted) return;
      messenger?.showSnackBar(
        SnackBar(
          content: Text('Laundry charge "${charge.name}" added successfully.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      messenger?.showSnackBar(
        SnackBar(
          content: Text('$error'.replaceFirst('Exception: ', '')),
          behavior: SnackBarBehavior.floating,
        ),
      );
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

  Future<OrderPlacementResult> _placeOrder(String pinHash) async {
    final result = await _repository.placeOrder(
      lines: _cartLines(),
      pinHash: pinHash,
    );
    if (!mounted) return result;
    final store = _store!;
    setState(() {
      final newBalances = Map.of(store.walletBalances);
      for (final t in result.transactions) {
        newBalances[t.shopKey] = (newBalances[t.shopKey] ?? 0.0) - t.amount;
      }
      _store = store.copyWith(
        walletBalances: newBalances,
        orders: [...result.orders, ...store.orders],
        walletTransactions: [
          ...result.transactions,
          ...store.walletTransactions,
        ],
      );
      _cart.clear();
      _selectedIndex = 1;
      _openedOrdersFromHome = true;
    });
    return result;
  }

  Future<void> _setupPin(String pinHash, {String? hint}) async {
    if (_repository case final WalletPinRepository pins) {
      try {
        await pins.setWalletPin(pinHash, hint: hint);
      } on WalletPinAlreadySetException {
        // The server already holds a PIN for this account (set on another
        // device). Remember that so the next checkout asks for it, and let
        // the cart show the server's message instead of placing the order.
        if (mounted) {
          setState(() => _store = _store?.copyWith(hasPin: true));
        }
        rethrow;
      }
    }
    if (mounted) {
      setState(() {
        _store = _store?.copyWith(hasPin: true);
      });
    }
  }


  Future<WalletTopUpResult> _topUpWallet(double amount, String shopKey) async {
    final result = switch (_repository) {
      BackendCanteenRepository backend => await _payWalletTopUp(
        backend,
        amount,
        shopKey,
      ),
      _ => await _repository.topUpWallet(amount),
    };
    if (!mounted) return result;
    final store = _store!;
    setState(() {
      _store = store.copyWith(
        walletBalances: {...store.walletBalances, shopKey: result.balance},
        walletTransactions: [result.transaction, ...store.walletTransactions],
      );
    });
    return result;
  }

  Future<WalletTopUpResult> _payWalletTopUp(
    BackendCanteenRepository repository,
    double amount,
    String shopKey,
  ) async {
    try {
      final order = await repository.createWalletTopUpOrder(amount, shopKey);
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
      backgroundColor: context.palette.surfaceRaised,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.94,
        child: CanteenCartScreen(
          menu: store.menu,
          cart: _cart,
          walletBalances: store.walletBalances,
          onAdd: _addItem,
          onRemove: _removeItem,
          onPlaceOrder: _placeOrder,
          onRefresh: () => _loadStore(silent: true),
          latestOrderFinder: (orderId) {
            final orders = _store?.orders;
            if (orders == null) return null;
            for (final o in orders) {
              if (o.id == orderId) return o;
            }
            return null;
          },
          hasPin: store.hasPin,
          onSetupPin: (pinHash, {hint}) => _setupPin(pinHash, hint: hint),
        ),
      ),
    );
  }

  Future<void> _openWallet(BuildContext context, [String? shopKey]) async {
    var settings = WalletTopUpSettings.defaults;
    if (_repository is BackendCanteenRepository) {
      try {
        settings = await _repository.getWalletTopUpSettings();
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error.toString())));
        }
        return;
      }
    }
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.palette.surfaceRaised,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.84,
        child: StudentWalletSheet(
          store: _store!,
          onTopUp: (amount) => _topUpWallet(amount, shopKey ?? 'mec-canteen'),
          shopKey: shopKey ?? 'mec-canteen',
          topUpSettings: settings,
          loadTransactionDetail: switch (_repository) {
            final WalletTransactionDetailRepository repository =>
              repository.loadWalletTransaction,
            _ => null,
          },
        ),
      ),
    );
  }

  /// The avatar in the shop screens, when the host has not given it the app's
  /// own profile: the signed-in person from the session, the Work / Shop
  /// choice, and sign-out. There used to be a second "Profile & settings"
  /// page here that dressed every account up as a student.
  Future<void> _openAccount(BuildContext context) {
    final session = widget.session;
    return showShopAccountSheet(
      context,
      name: session.displayName,
      email: session.email,
      idNumber: session.idNumber,
      photoUrl: widget.photoUrl ?? session.photoUrl,
      mode: _canUseWorkMode
          ? (_ownerWorkMode ? CanteenStaffMode.work : CanteenStaffMode.eat)
          : null,
      onModeChanged: _canUseWorkMode ? _updateOwnerMode : null,
      onSignOut: widget.onSignOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = _store;
    if (_error != null) {
      return Center(
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
      );
    }
    if (store == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const SafeArea(child: SkeletonList(rows: 6, rowHeight: 84)),
      );
    }

    if (_isStationeryOperator && _ownerWorkMode) {
      final workStore = _workView(store);
      final stationeryStore = workStore.staffState.mode == CanteenStaffMode.work
          ? workStore
          : workStore.copyWith(
              staffState: CanteenStaffState(
                mode: CanteenStaffMode.work,
                shopOpen: store.staffState.shopOpen,
              ),
            );
      return StationeryOperatorHome(
        store: stationeryStore,
        initialAction: widget.initialAction,
        onExitModule: widget.onExitModule,
        onSignOut: widget.onSignOut,
        onRefresh: () => _loadStore(silent: true),
        onCounterStateChanged: _updateOwnerMode,
        onShopOpenChanged: _updateShopOpen,
        onOrderStatusChanged: _updateOrderStatus,
        onSaveItem: (item, create) => _saveMenuItem(item, create),
        onUploadMedia: (bytes, filename) =>
            _repository.uploadMedia(bytes, filename: filename),
        onScanOrder: (payload) async {
          final order = await _repository.scanOrder(payload);
          await _loadStore(silent: true);
          return order;
        },
        isMainHome: widget.isMainHome,
        onProfileTap: widget.onProfileTap,
        displayName: widget.session.displayName,
        email: widget.session.email,
        photoUrl: widget.photoUrl ?? widget.session.photoUrl,
      );
    }

    if (_isLaundryOperator && _ownerWorkMode) {
      return LaundryOperatorHome(
        store: _workView(store),
        onExitModule: widget.onExitModule,
        onShopMode: () => _updateOwnerMode(CanteenStaffMode.eat),
        onRefresh: () => _loadStore(silent: true),
        onUpdatePrice: _updateLaundryPrice,
        onCreateCharge: _createLaundryCharge,
      );
    }

    final isCaptain = widget.session.isCaptain ||
        (store.canManage && !store.canManageMenu && !widget.session.isCanteenOwner);
    if (isCaptain && _ownerWorkMode) {
      final workStore = _workView(store);
      final captainStore = workStore.staffState.mode == CanteenStaffMode.work
          ? workStore
          : workStore.copyWith(
              staffState: CanteenStaffState(
                mode: CanteenStaffMode.work,
                shopOpen: store.staffState.shopOpen,
              ),
            );
      return CanteenCaptainHome(
        store: captainStore,
        onExitModule: widget.onExitModule,
        onSignOut: widget.onSignOut,
        onRefresh: () => _loadStore(silent: true),
        onModeChanged: _updateOwnerMode,
        onOrderStatusChanged: _updateOrderStatus,
        onScanOrder: (payload) async {
          final order = await _repository.scanOrder(payload);
          await _loadStore(silent: true);
          return order;
        },
        onProfileTap: widget.onProfileTap,
        photoUrl: widget.photoUrl ?? widget.session.photoUrl,
        displayName: widget.session.displayName,
        isMainHome: widget.session.isCaptain,
      );
    }

    if (_hasCounterWork && _canUseWorkMode && _ownerWorkMode) {
      final workStore = _workView(store);
      final ownerStore = workStore.staffState.mode == CanteenStaffMode.work
          ? workStore
          : workStore.copyWith(
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
        isMainHome: widget.isMainHome,
        onProfileTap: widget.onProfileTap ?? () => _openAccount(context),
        photoUrl: widget.photoUrl ?? widget.session.photoUrl,
        displayName: widget.session.displayName,
        email: widget.session.email,
        nav: widget.ownerNav,
        loadShopAnalytics: switch (_repository) {
          final ShopAnalyticsRepository analytics =>
            (shopKey, range) =>
                analytics.loadShopAnalytics(shopKey: shopKey, range: range),
          _ => null,
        },
      );
    }

    void handleOrdersBack() {
      if (_openedOrdersFromHome) {
        setState(() {
          _openedOrdersFromHome = false;
          _selectedIndex = 0;
        });
      } else {
        widget.onExitModule();
      }
    }

    void handlePop() {
      if (_selectedIndex == 1) {
        handleOrdersBack();
      } else if (_selectedIndex == 2) {
        setState(() => _selectedIndex = 0);
      } else {
        widget.onExitModule();
      }
    }

    // Shop mode: every campus store, as a customer.
    final shopStore = _shopView(store);
    final pages = [
      StudentCanteenHome(
        store: shopStore,
        cart: _cart,
        onAdd: _addItem,
        onRemove: _removeItem,
        onOpenCart: () => _openCart(context),
        onOpenWallet: (shopKey) => _openWallet(context, shopKey),
        onOpenProfile: () => _openAccount(context),
        onOpenOrders: () => setState(() {
          _openedOrdersFromHome = true;
          _selectedIndex = 1;
        }),
        onExitModule: widget.onExitModule,
        initialShopKey: widget.initialAction == 'laundry'
            ? 'mec-laundry'
            : null,
        onPayLaundryCharge: _payLaundryCharge,
        onWorkMode: _canUseWorkMode
            ? () => _updateOwnerMode(CanteenStaffMode.work)
            : null,
        onAlertsTap: widget.onAlertsTap,
        onProfileTap: widget.onProfileTap,
        hasAlerts: widget.hasAlerts,
        photoUrl: widget.photoUrl ?? widget.session.photoUrl,
        onScanLaundryQr: () => _scanLaundryQr(context),
        onOpenModule: widget.onOpenModule,
        glance: widget.glance,
        announcements: widget.announcements,
        session: widget.session,
      ),
      CanteenOrdersScreen(
        orders: shopStore.orders,
        onBack: handleOrdersBack,
        onRefresh: () => _loadStore(silent: true),
      ),
      CanteenScannerScreen(
        onScan: (payload) async {
          await _repository.scanOrder(payload);
          await _loadStore(silent: true);
        },
      ),
    ];

    final eatContent = PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) handlePop();
      },
      child: IndexedStack(index: _selectedIndex, children: pages),
    );

    final body = SafeArea(
      bottom: false,
      child: eatContent,
    );

    if (isCaptain || Scaffold.maybeOf(context) == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: body,
      );
    }

    return body;
  }
}
