import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/transaction_result_overlay.dart';
import '../data/canteen_models.dart';

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
    this.topUpSettings = WalletTopUpSettings.defaults,
  });

  final CanteenStore store;
  final Future<WalletTopUpResult> Function(double amount) onTopUp;
  final WalletTopUpSettings topUpSettings;

  @override
  State<StudentWalletSheet> createState() => _StudentWalletSheetState();
}

class _StudentWalletSheetState extends State<StudentWalletSheet> {
  WalletHistory _history = WalletHistory.orders;

  CanteenStore get store => widget.store;
  Future<WalletTopUpResult> Function(double amount) get onTopUp =>
      widget.onTopUp;

  Future<void> _openTopUp(BuildContext context) async {
    final result = await showModalBottomSheet<WalletTopUpResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
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
                  color: AppColors.border,
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
                        'Wallet',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Balance and transactions',
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
                color: const Color(0xFFE7F3EC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBBD9C6)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Personal balance',
                          style: TextStyle(color: AppColors.muted),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          formatCurrency(store.walletBalance),
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 25,
                            fontWeight: FontWeight.w500,
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
              Flexible(child: _OrderHistory(orders: store.orders))
            else
              Flexible(
                child: store.walletTransactions.isEmpty
                    ? const _EmptyHistory(
                        icon: Icons.swap_vert,
                        message: 'No transactions yet.',
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: store.walletTransactions.length,
                        separatorBuilder: (_, _) =>
                            const Divider(height: 1, indent: 56),
                        itemBuilder: (context, index) {
                          final transaction = store.walletTransactions[index];
                          final isCredit =
                              transaction.type == WalletTransactionType.credit;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: isCredit
                                        ? const Color(0xFFE7F3EC)
                                        : const Color(0xFFFDEBE9),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    isCredit
                                        ? Icons.south_west
                                        : Icons.north_east,
                                    color: isCredit
                                        ? AppColors.success
                                        : const Color(0xFFC43B31),
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
                                        '${formatShortDate(transaction.createdAt)} · ${formatTime(transaction.createdAt)}',
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
                                        ? AppColors.success
                                        : const Color(0xFFC43B31),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
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

/// Past orders, newest first.
///
/// Items lead, because "what did I order?" is the question being asked; the
/// order number and status follow in a quieter line.
class _OrderHistory extends StatelessWidget {
  const _OrderHistory({required this.orders});

  final List<CanteenOrder> orders;

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return const _EmptyHistory(
        icon: Icons.receipt_long_outlined,
        message: 'No orders yet.',
      );
    }
    final sorted = [...orders]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return ListView.separated(
      shrinkWrap: true,
      itemCount: sorted.length,
      separatorBuilder: (_, _) => const Divider(height: 1, indent: 56),
      itemBuilder: (context, index) {
        final order = sorted[index];
        final settled = !order.status.isActive;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: settled
                      ? const Color(0xFFF1F2F4)
                      : const Color(0xFFEAF1FE),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  settled ? Icons.check_rounded : Icons.schedule,
                  size: 20,
                  color: settled ? AppColors.muted : const Color(0xFF2563EB),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.lines
                          .map(
                            (line) => line.quantity > 1
                                ? '${line.quantity} x ${line.item.name}'
                                : line.item.name,
                          )
                          .join(', '),
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
                      '#${order.displayId} · ${formatShortDate(order.createdAt)} · ${order.status.label}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                formatCurrency(order.total),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        );
      },
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
          Icon(icon, size: 30, color: AppColors.muted),
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
