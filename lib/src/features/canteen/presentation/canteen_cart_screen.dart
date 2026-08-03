import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../data/canteen_models.dart';
import 'widgets/canteen_surface.dart';
import 'widgets/menu_item_art.dart';
import 'widgets/quantity_control.dart';
import 'order_pickup_sheet.dart';
import 'transaction_pin_sheet.dart';

class CanteenCartScreen extends StatefulWidget {
  const CanteenCartScreen({
    super.key,
    required this.menu,
    required this.cart,
    required this.walletBalance,
    required this.onAdd,
    required this.onRemove,
    required this.onPlaceOrder,
  });

  final List<CanteenMenuItem> menu;
  final Map<String, int> cart;
  final double walletBalance;
  final ValueChanged<CanteenMenuItem> onAdd;
  final ValueChanged<CanteenMenuItem> onRemove;
  final Future<OrderPlacementResult> Function(FulfilmentMode mode) onPlaceOrder;

  @override
  State<CanteenCartScreen> createState() => _CanteenCartScreenState();
}

class _CanteenCartScreenState extends State<CanteenCartScreen> {
  FulfilmentMode _mode = FulfilmentMode.dineIn;
  bool _isSubmitting = false;
  String? _error;

  List<CartLine> get _lines {
    return widget.menu
        .where((item) => (widget.cart[item.id] ?? 0) > 0)
        .map((item) => CartLine(item: item, quantity: widget.cart[item.id]!))
        .toList();
  }

  double get _total => _lines.fold(0, (sum, line) => sum + line.total);

  Future<void> _placeOrder() async {
    final approved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      builder: (_) => TransactionPinSheet(
        amount: _total,
        summary:
            '${_lines.length} canteen item${_lines.length == 1 ? '' : 's'}',
      ),
    );
    if (approved != true || !mounted) return;

    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      final result = await widget.onPlaceOrder(_mode);
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: AppColors.ink,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
        ),
        builder: (_) => OrderPickupSheet(order: result.order),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error is Exception
              ? error.toString().replaceFirst('Exception: ', '')
              : 'Order could not be placed. Try again.';
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
                      const SizedBox(height: 12),
                      CanteenSurface(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            for (
                              var index = 0;
                              index < _lines.length;
                              index++
                            ) ...[
                              _CartLineRow(
                                line: _lines[index],
                                onAdd: () {
                                  widget.onAdd(_lines[index].item);
                                  setState(() {});
                                },
                                onRemove: () {
                                  widget.onRemove(_lines[index].item);
                                  setState(() {});
                                },
                              ),
                              if (index != _lines.length - 1)
                                const Divider(height: 1, indent: 74),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        'How will you eat?',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<FulfilmentMode>(
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment(
                              value: FulfilmentMode.dineIn,
                              icon: Icon(Icons.table_restaurant_outlined),
                              label: Text('Dine in'),
                            ),
                            ButtonSegment(
                              value: FulfilmentMode.pickup,
                              icon: Icon(Icons.shopping_bag_outlined),
                              label: Text('Pickup'),
                            ),
                          ],
                          selected: {_mode},
                          onSelectionChanged: (selection) {
                            setState(() => _mode = selection.first);
                          },
                        ),
                      ),
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
                      Row(
                        children: [
                          const Icon(
                            Icons.account_balance_wallet_outlined,
                            size: 19,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Wallet balance ${formatCurrency(widget.walletBalance)}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
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
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
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
        Text(value, style: style?.copyWith(fontWeight: FontWeight.w800)),
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
            const Icon(
              Icons.shopping_bag_outlined,
              size: 52,
              color: AppColors.muted,
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
