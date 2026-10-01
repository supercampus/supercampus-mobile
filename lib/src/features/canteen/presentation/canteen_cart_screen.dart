import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/transaction_result_overlay.dart';
import '../data/canteen_models.dart';
import '../data/canteen_repository.dart';
import 'widgets/canteen_surface.dart';
import 'widgets/menu_item_art.dart';
import 'widgets/quantity_control.dart';
import 'order_pickup_sheet.dart';
import 'transaction_pin_sheet.dart';
import '../../../core/utils/user_facing_error.dart';

class CanteenCartScreen extends StatefulWidget {
  const CanteenCartScreen({
    super.key,
    required this.menu,
    required this.cart,
    required this.walletBalances,
    required this.onAdd,
    required this.onRemove,
    required this.onPlaceOrder,
    this.onRefresh,
    this.latestOrderFinder,
    this.hasPin = false,
    this.onSetupPin,
    this.shops = const [],
  });

  final List<CanteenMenuItem> menu;

  /// The campus's shops, to name each shop the cart splits into.
  final List<CanteenShop> shops;
  final Map<String, int> cart;
  final Map<String, double> walletBalances;
  final ValueChanged<CanteenMenuItem> onAdd;
  final ValueChanged<CanteenMenuItem> onRemove;
  /// Called after PIN verification; receives the SHA-256 hash of the entered PIN.
  final Future<OrderPlacementResult> Function(String pinHash) onPlaceOrder;
  final Future<void> Function()? onRefresh;
  final CanteenOrder? Function(String orderId)? latestOrderFinder;
  /// Whether the user already has a PIN set.
  final bool hasPin;
  /// Called when first-time PIN setup completes (receives hash + optional hint).
  final Future<void> Function(String pinHash, {String? hint})? onSetupPin;

  @override
  State<CanteenCartScreen> createState() => _CanteenCartScreenState();
}

class _CanteenCartScreenState extends State<CanteenCartScreen> {
  bool _isSubmitting = false;
  String? _error;

  List<CartLine> get _lines {
    return widget.menu
        .where((item) => (widget.cart[item.id] ?? 0) > 0)
        .map((item) => CartLine(item: item, quantity: widget.cart[item.id]!))
        .toList();
  }

  double get _total => _lines.fold(0, (sum, line) => sum + line.total);

  /// The shop a cart line is bought from. Two canteens are two shops: each
  /// takes its own order, hands over its own QR and debits its own wallet.
  String _shopOf(CartLine line) =>
      resolveShopKey(line.item.effectiveShopKey, widget.shops);

  /// Shops represented in the cart, in menu order — one order and one QR each.
  List<String> get _shops {
    final seen = <String>[];
    for (final line in _lines) {
      final shop = _shopOf(line);
      if (!seen.contains(shop)) seen.add(shop);
    }
    return seen;
  }

  List<CartLine> _linesFor(String shop) =>
      _lines.where((line) => _shopOf(line) == shop).toList(growable: false);

  /// What the student calls [shopKey]: its configured name.
  String _shopName(String shopKey) {
    for (final shop in widget.shops) {
      if (shop.shopKey == shopKey) return shop.name;
    }
    return shopCategoryForStoreKey(shopKey) == 'stationery'
        ? 'Stationery'
        : 'Canteen';
  }

  /// The wallets the cart spends from, in cart order: a counter's canteen
  /// holds its wallet, so Meals and Snacks share one line.
  List<String> get _wallets {
    final seen = <String>[];
    for (final shop in _shops) {
      final wallet = walletKeyOf(shop, widget.shops);
      if (!seen.contains(wallet)) seen.add(wallet);
    }
    return seen;
  }

  /// How each shop's part of the cart will be paid, exactly as checkout
  /// will: a counter's own credit first, then its canteen's.
  ({List<List<WalletDebit>> debits, int? failedAt}) get _plan =>
      planWalletDebits(
        [
          for (final shop in _shops)
            (
              shop: shop,
              total: _linesFor(
                shop,
              ).fold<double>(0, (sum, line) => sum + line.total),
            ),
        ],
        widget.walletBalances,
        widget.shops,
      );

  /// "₹100 Snacks-only + ₹20 canteen credit" for one counter's debits.
  String _paidWith(String shop, List<WalletDebit> debits) {
    if (debits.isEmpty) return 'Nothing to pay';
    return debits
        .map(
          (debit) => debit.bucket == shop
              ? '${formatCurrency(debit.amount)} ${_shopName(shop)}-only credit'
              : '${formatCurrency(debit.amount)} canteen credit',
        )
        .join(' + ');
  }

  Widget _walletSummary(BuildContext context) {
    final plan = _plan;
    final textStyle = Theme.of(context).textTheme.bodyMedium;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final wallet in _wallets) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 19,
                  color: context.palette.brandInk,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_shopName(wallet)} wallet: ${formatCurrency(walletBreakdownOf(wallet, widget.walletBalances, widget.shops).total)}',
                    style: textStyle,
                  ),
                ),
              ],
            ),
          ),
          // Counters say which credit pays for them, since credit can be
          // limited to one counter.
          for (var index = 0; index < _shops.length; index++)
            if (_shops[index] != wallet &&
                walletKeyOf(_shops[index], widget.shops) == wallet)
              Padding(
                key: ValueKey('cart-wallet-split-${_shops[index]}'),
                padding: const EdgeInsets.only(left: 27, bottom: 4),
                child: Text(
                  index < plan.debits.length
                      ? '${_shopName(_shops[index])} · ${_paidWith(_shops[index], plan.debits[index])}'
                      : index == plan.failedAt
                      ? '${_shopName(_shops[index])} · not enough credit here'
                      : _shopName(_shops[index]),
                  style: textStyle?.copyWith(
                    color: index == plan.failedAt
                        ? context.palette.danger
                        : context.palette.inkSecondary,
                  ),
                ),
              ),
        ],
      ],
    );
  }

  Future<void> _placeOrder() async {
    // The parent clears the cart as soon as the order succeeds. Preserve the
    // amount the student approved so the result screen never recomputes an
    // already-cleared cart as zero.
    final transactionTotal = _total;

    String? pinHash;

    if (!widget.hasPin) {
      // First-time setup: ask the user to create a PIN.
      final setup = await showSetupPinSheet(context);
      if (setup == null || !mounted) return;
      // Persist the new PIN via parent callback.
      if (widget.onSetupPin != null) {
        try {
          await widget.onSetupPin!(setup.pinHash, hint: setup.hint);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  e is CanteenException
                      ? e.message
                      : 'Your PIN could not be saved. Try again.',
                ),
              ),
            );
          }
          return;
        }
      }
      pinHash = setup.pinHash;
    } else {
      // Existing PIN: verify before placing order.
      final result = await showVerifyPinSheet(
        context,
        amount: transactionTotal,
        summary: '${_lines.length} item${_lines.length == 1 ? '' : 's'}',
      );
      if (result == null || !mounted) return;
      pinHash = result;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      final result = await widget.onPlaceOrder(pinHash);
      if (!mounted) return;
      await showTransactionResult(
        context,
        result: TransactionResult.success,
        title: 'Order placed',
        message: 'Your payment is complete and the counter has your order.',
        amount: formatCurrency(transactionTotal),
        reference: result.orders
            .map((order) => 'Order #${order.orderNumber}')
            .join(' · '),
      );
      // A cart spanning two shops (two canteens, say) is two orders, each
      // collected at its own counter with its own QR: show every one.
      for (final order in result.orders) {
        if (!mounted) return;
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          backgroundColor: Colors.transparent,
          builder: (_) => OrderPickupSheet(
            order: order,
            onRefresh: widget.onRefresh,
            latestOrderFinder: () => widget.latestOrderFinder?.call(order.id),
          ),
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        final message = error is Exception
            ? userFacingError(error)
            : 'Order could not be placed. Try again.';
        await showTransactionResult(
          context,
          result: TransactionResult.failure,
          title: 'Payment unsuccessful',
          message: message,
          amount: formatCurrency(transactionTotal),
        );
        if (!mounted) return;
        setState(() {
          _error = message;
        });
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: const Text('Your cart'),
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: _lines.isEmpty
                ? _EmptyCart(onBack: () => Navigator.of(context).pop())
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 130),
                    children: [
                      Text(
                        'Order items',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (_shops.length > 1) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Each shop hands over its own order, so you will get '
                          '${_shops.length} separate QR codes.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                      const SizedBox(height: 12),
                      // Grouped by shop, because that is how the order will be
                      // split and collected.
                      for (final shop in _shops) ...[
                        if (_shops.length > 1)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8, top: 4),
                            child: Text(
                              _shopName(shop),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.1,
                              ),
                            ),
                          ),
                        CanteenSurface(
                          padding: EdgeInsets.zero,
                          child: Column(
                            children: [
                              for (
                                var index = 0;
                                index < _linesFor(shop).length;
                                index++
                              ) ...[
                                _CartLineRow(
                                  line: _linesFor(shop)[index],
                                  onAdd: () {
                                    widget.onAdd(_linesFor(shop)[index].item);
                                    setState(() {});
                                  },
                                  onRemove: () {
                                    widget.onRemove(
                                      _linesFor(shop)[index].item,
                                    );
                                    setState(() {});
                                  },
                                ),
                                if (index != _linesFor(shop).length - 1)
                                  const Divider(height: 1, indent: 74),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      const SizedBox(height: 22),
                      CanteenSurface(
                        child: Column(
                          children: [
                            _SummaryRow(
                              label: 'Item total',
                              value: formatCurrency(_total),
                            ),
                            const SizedBox(height: 10),
                            const _SummaryRow(
                              label: 'Service fee',
                              value: '₹0',
                            ),
                            const Divider(height: 24),
                            _SummaryRow(
                              label: 'Total',
                              value: formatCurrency(_total),
                              emphasized: true,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _walletSummary(context),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ),
      ),
      bottomNavigationBar: _lines.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
                child: FilledButton.icon(
                  onPressed: _isSubmitting ? null : _placeOrder,
                  icon: _isSubmitting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.lock_outline),
                  label: Text(
                    _isSubmitting
                        ? 'Placing order...'
                        : 'Pay ${formatCurrency(_total)} from wallet',
                  ),
                ),
              ),
            ),
    );
  }
}

class _CartLineRow extends StatelessWidget {
  const _CartLineRow({
    required this.line,
    required this.onAdd,
    required this.onRemove,
  });

  final CartLine line;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(13),
      child: Row(
        children: [
          MenuItemArt(item: line.item, size: 52),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.item.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  formatCurrency(line.item.price),
                  style: TextStyle(
                    color: context.palette.brandInk,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          QuantityControl(
            quantity: line.quantity,
            compact: true,
            onAdd: onAdd,
            onRemove: onRemove,
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final style = emphasized
        ? Theme.of(context).textTheme.titleMedium
        : Theme.of(context).textTheme.bodyLarge;
    return Row(
      children: [
        Expanded(child: Text(label, style: style)),
        Text(value, style: style?.copyWith(fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.shopping_bag_outlined,
              size: 52,
              color: context.palette.inkSecondary,
            ),
            const SizedBox(height: 15),
            Text(
              'Your cart is empty',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 18),
            FilledButton(onPressed: onBack, child: const Text('Browse menu')),
          ],
        ),
      ),
    );
  }
}
