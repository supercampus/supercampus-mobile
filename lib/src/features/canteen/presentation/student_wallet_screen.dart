import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/transaction_result_overlay.dart';
import '../data/canteen_models.dart';
import 'canteen_orders_screen.dart';
import 'wallet_transaction_details_screen.dart';

/// Which history the wallet is showing.
enum WalletHistory { orders, transactions }

/// The wallet, and both records of what the money did.
///
/// Orders and transactions answer different questions — "what did I eat?" and
/// "where did my balance go?" — but they are the same trail seen twice, so they
/// live together here rather than being scattered across the app.
class StudentWalletSheet extends StatefulWidget {
  const StudentWalletSheet({
    super.key,
    required this.store,
    required this.onTopUp,
    this.shopKey = 'mec-canteen',
    this.topUpSettings = WalletTopUpSettings.defaults,
    this.loadTransactionDetail,
  });

  final CanteenStore store;
  final String shopKey;
  final Future<WalletTopUpResult> Function(double amount) onTopUp;
  final WalletTopUpSettings topUpSettings;

  /// Fetches a transaction's full server record for its details page. Without
  /// it the page shows what the wallet already holds.
  final WalletTransactionDetailLoader? loadTransactionDetail;

  @override
  State<StudentWalletSheet> createState() => _StudentWalletSheetState();
}

class _StudentWalletSheetState extends State<StudentWalletSheet> {
  WalletHistory _history = WalletHistory.orders;

  CanteenStore get store => widget.store;

  /// Only this shop's wallet: another shop's rows never appear here, and
  /// legacy store keys are mapped onto their shop before comparing.
  List<WalletTransaction> get _transactions =>
      store.walletTransactionsFor(widget.shopKey);

  Future<void> _openOrder(BuildContext context, CanteenOrder order) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => FullScreenOrderQrScreen(
          order: order,
          latestOrderFinder: () {
            for (final candidate in store.orders) {
              if (candidate.id == order.id) return candidate;
            }
            return null;
          },
        ),
      ),
    );
  }

  /// A laundry charge's details are its payment's receipt.
  WalletTransaction? _laundryPayment(LaundryCharge charge) {
    for (final transaction in _transactions) {
      if (transaction.referenceId == charge.id) return transaction;
    }
    return null;
  }

  Future<WalletTopUpResult> Function(double amount) get onTopUp =>
      widget.onTopUp;

  Future<void> _openTransaction(
    BuildContext context,
    WalletTransaction transaction,
  ) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => WalletTransactionDetailsScreen(
          transaction: transaction,
          store: store,
          loadDetail: widget.loadTransactionDetail,
        ),
      ),
    );
  }

  Future<void> _openTopUp(BuildContext context) async {
    final result = await showModalBottomSheet<WalletTopUpResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.palette.surfaceRaised,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      builder: (_) =>
          _TopUpSheet(onTopUp: onTopUp, settings: widget.topUpSettings),
    );
    if (result == null || !context.mounted) return;
    await showTransactionResult(
      context,
      result: TransactionResult.success,
      title: 'Wallet recharged',
      message: 'Your updated balance is ready to use across campus services.',
      amount: formatCurrency(result.transaction.amount),
      reference: 'Transaction ${result.transaction.id}',
    );
    if (!context.mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final shopName = store.walletShopFor(widget.shopKey)?.name.trim();
    final balance = store.walletBalances[widget.shopKey] ?? 0.0;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: context.palette.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shopName == null || shopName.isEmpty
                            ? 'Wallet'
                            : shopName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Wallet balance, orders and transactions',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Close wallet',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(17),
              decoration: BoxDecoration(
                color: context.palette.brandSoft,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: context.palette.brand.withValues(alpha: 0.24),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: context.palette.surface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.account_balance_wallet,
                      color: context.palette.brandInk,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Personal balance',
                          style: TextStyle(color: context.palette.inkSecondary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          formatCurrency(balance),
                          key: const ValueKey('student-wallet-balance'),
                          style: TextStyle(
                            // An accounts deduction can leave the wallet
                            // below zero; say so in red.
                            color: balance < 0
                                ? context.palette.danger
                                : context.palette.brandInk,
                            fontSize: 25,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (balance < 0)
                          Text(
                            'Top up to order again',
                            key: const ValueKey('student-wallet-negative-hint'),
                            style: TextStyle(
                              color: context.palette.danger,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => _openTopUp(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Top up'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SegmentedButton<WalletHistory>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: WalletHistory.orders,
                  icon: Icon(Icons.receipt_long_outlined),
                  label: Text('Orders'),
                ),
                ButtonSegment(
                  value: WalletHistory.transactions,
                  icon: Icon(Icons.swap_vert),
                  label: Text('Transactions'),
                ),
              ],
              selected: {_history},
              onSelectionChanged: (selection) =>
                  setState(() => _history = selection.first),
            ),
            const SizedBox(height: 12),
            if (_history == WalletHistory.orders)
              Flexible(
                child: _OrderHistory(
                  orders: store.walletOrdersFor(widget.shopKey),
                  laundryCharges: store.walletLaundryChargesFor(widget.shopKey),
                  onOpenOrder: (order) => _openOrder(context, order),
                  onOpenLaundryCharge: (charge) {
                    final payment = _laundryPayment(charge);
                    if (payment == null) return null;
                    return () => _openTransaction(context, payment);
                  },
                ),
              )
            else
              Flexible(
                child: _transactions.isEmpty
                    ? const _EmptyHistory(
                        icon: Icons.swap_vert,
                        message: 'No transactions yet.',
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: _transactions.length,
                        separatorBuilder: (_, _) =>
                            const Divider(height: 1, indent: 56),
                        itemBuilder: (context, index) {
                          final transaction = _transactions[index];
                          final isCredit =
                              transaction.type == WalletTransactionType.credit;
                          return Material(
                            type: MaterialType.transparency,
                            child: InkWell(
                              key: ValueKey(
                                'wallet-transaction-${transaction.id}',
                              ),
                              borderRadius: BorderRadius.circular(8),
                              onTap: () =>
                                  _openTransaction(context, transaction),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 42,
                                      height: 42,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: isCredit
                                            ? context.adaptive(
                                                light: const Color(0xFFE7F3EC),
                                                dark: const Color(0x2E2E7D52),
                                              )
                                            : context.adaptive(
                                                light: const Color(0xFFFDEBE9),
                                                dark: const Color(0x2EC43B31),
                                              ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        isCredit
                                            ? Icons.south_west
                                            : Icons.north_east,
                                        color: isCredit
                                            ? context.palette.success
                                            : context.adaptive(
                                                light: const Color(0xFFC43B31),
                                                dark: const Color(0xFFFCA5A5),
                                              ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            transaction.description,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.titleMedium,
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            [
                                              if (transaction.kind ==
                                                  'manual_debit')
                                                'Deducted by Accounts',
                                              '${formatShortDate(transaction.createdAt)} · ${formatTime(transaction.createdAt)}',
                                            ].join(' · '),
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodyMedium,
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      formatCurrency(
                                        transaction.signedAmount,
                                        signed: true,
                                      ),
                                      style: TextStyle(
                                        color: isCredit
                                            ? context.palette.success
                                            : context.adaptive(
                                                light: const Color(0xFFC43B31),
                                                dark: const Color(0xFFFCA5A5),
                                              ),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      size: 20,
                                      color: context.palette.inkTertiary,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Past orders — or, for the laundry, its charges — newest first.
class _OrderHistory extends StatelessWidget {
  const _OrderHistory({
    required this.orders,
    required this.laundryCharges,
    required this.onOpenOrder,
    required this.onOpenLaundryCharge,
  });

  final List<CanteenOrder> orders;

  /// The laundry's orders: the charges this person claimed and paid.
  final List<LaundryCharge> laundryCharges;
  final ValueChanged<CanteenOrder> onOpenOrder;

  /// The tap for a charge, or null when it has no payment to show yet.
  final VoidCallback? Function(LaundryCharge charge) onOpenLaundryCharge;

  @override
  Widget build(BuildContext context) {
    final entries = <({DateTime at, Widget Function(BuildContext) build})>[
      for (final order in orders)
        (at: order.createdAt, build: (context) => _orderRow(context, order)),
      for (final charge in laundryCharges)
        (
          at: charge.paidAt ?? charge.claimedAt ?? charge.createdAt,
          build: (context) => _laundryRow(context, charge),
        ),
    ]..sort((a, b) => b.at.compareTo(a.at));

    if (entries.isEmpty) {
      return const _EmptyHistory(
        icon: Icons.receipt_long_outlined,
        message: 'No orders yet.',
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      itemCount: entries.length,
      separatorBuilder: (_, _) => const Divider(height: 1, indent: 56),
      itemBuilder: (context, index) => entries[index].build(context),
    );
  }

  Widget _orderRow(BuildContext context, CanteenOrder order) {
    final settled = !order.status.isActive;
    return _HistoryRow(
      key: ValueKey('wallet-order-${order.id}'),
      onTap: () => onOpenOrder(order),
      icon: settled ? Icons.check_rounded : Icons.schedule,
      highlighted: !settled,
      title: order.lines
          .map(
            (line) => line.quantity > 1
                ? '${line.quantity} x ${line.item.name}'
                : line.item.name,
          )
          .join(', '),
      subtitle:
          '#${order.displayId} · ${formatShortDate(order.createdAt)} · ${order.status.label}',
      amount: order.total,
    );
  }

  Widget _laundryRow(BuildContext context, LaundryCharge charge) {
    final paid = charge.status == LaundryChargeStatus.paid;
    final status = switch (charge.status) {
      LaundryChargeStatus.paid => 'Paid',
      LaundryChargeStatus.claimed => 'Awaiting payment',
      LaundryChargeStatus.cancelled => 'Cancelled',
      LaundryChargeStatus.pending => 'Pending',
    };
    final quantity =
        '${charge.quantity.toStringAsFixed(charge.unitLabel == 'kg' ? 1 : 0)} ${charge.unitLabel}';
    return _HistoryRow(
      key: ValueKey('wallet-laundry-${charge.id}'),
      onTap: onOpenLaundryCharge(charge),
      icon: charge.serviceType == LaundryServiceType.wash
          ? Icons.local_laundry_service_outlined
          : Icons.iron_outlined,
      highlighted: !paid && charge.status != LaundryChargeStatus.cancelled,
      title: charge.name,
      subtitle:
          '$quantity · ${formatShortDate(charge.paidAt ?? charge.createdAt)} · $status',
      amount: charge.total,
    );
  }
}

/// One line of the wallet's order history: what, when, how much.
///
/// Items lead, because "what did I order?" is the question being asked; the
/// number and status follow in a quieter line.
class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    super.key,
    required this.onTap,
    required this.icon,
    required this.highlighted,
    required this.title,
    required this.subtitle,
    required this.amount,
  });

  final VoidCallback? onTap;
  final IconData icon;
  final bool highlighted;
  final String title;
  final String subtitle;
  final double amount;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: highlighted
                      ? context.adaptive(
                          light: const Color(0xFFEFE8FE),
                          dark: const Color(0x2E7B42F6),
                        )
                      : context.adaptive(
                          light: const Color(0xFFF1F2F4),
                          dark: const Color(0xFF1C1D23),
                        ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: highlighted
                      ? context.palette.info
                      : context.palette.inkSecondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
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
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                formatCurrency(amount),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: context.palette.inkTertiary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 34),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 30, color: context.palette.inkSecondary),
          const SizedBox(height: 10),
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _TopUpSheet extends StatefulWidget {
  const _TopUpSheet({required this.onTopUp, required this.settings});

  final Future<WalletTopUpResult> Function(double amount) onTopUp;
  final WalletTopUpSettings settings;

  @override
  State<_TopUpSheet> createState() => _TopUpSheetState();
}

class _TopUpSheetState extends State<_TopUpSheet> {
  late final TextEditingController _controller;
  late double _amount;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _amount = widget.settings.minimumAmount;
    _controller = TextEditingController(text: _amount.toStringAsFixed(0));
  }

  String _amountLabel(double value) => NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: value == value.roundToDouble() ? 0 : 2,
  ).format(value);

  List<double> get _suggestions {
    final values = <double>{
      widget.settings.minimumAmount,
      for (final value in const [100.0, 200.0, 250.0, 500.0, 1000.0, 2000.0])
        if (value >= widget.settings.minimumAmount &&
            value <= widget.settings.maximumAmount)
          value,
      widget.settings.maximumAmount,
    }.toList()..sort();
    if (values.length <= 4) return values;
    return [
      values.first,
      values[values.length ~/ 3],
      values[(values.length * 2) ~/ 3],
      values.last,
    ];
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_controller.text.trim());
    if (amount == null ||
        amount < widget.settings.minimumAmount ||
        amount > widget.settings.maximumAmount) {
      setState(
        () => _error =
            'Enter an amount between ${_amountLabel(widget.settings.minimumAmount)} and ${_amountLabel(widget.settings.maximumAmount)}.',
      );
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.onTopUp(amount);
      if (mounted) Navigator.of(context).pop(result);
    } catch (error) {
      if (mounted) {
        final message = error.toString().replaceFirst('Exception: ', '');
        await showTransactionResult(
          context,
          result: TransactionResult.failure,
          title: 'Recharge unsuccessful',
          message: message,
          amount: formatCurrency(amount),
        );
        if (mounted) setState(() => _error = message);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          Text('Top up wallet', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _suggestions.map((amount) {
              return ChoiceChip(
                label: Text(formatCurrency(amount)),
                selected: _amount == amount,
                onSelected: (_) => setState(() {
                  _amount = amount;
                  _controller.text = amount.toStringAsFixed(0);
                }),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Amount',
              prefixText: '₹ ',
              errorText: _error,
            ),
            onChanged: (value) =>
                setState(() => _amount = double.tryParse(value) ?? 0),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _loading ? null : _submit,
            child: Text(_loading ? 'Processing...' : 'Continue'),
          ),
        ],
      ),
    );
  }
}
