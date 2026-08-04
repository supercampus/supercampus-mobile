import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../data/canteen_models.dart';

class StudentWalletSheet extends StatelessWidget {
  const StudentWalletSheet({
    super.key,
    required this.store,
    required this.onTopUp,
  });

  final CanteenStore store;
  final Future<WalletTopUpResult> Function(double amount) onTopUp;

  Future<void> _openTopUp(BuildContext context) async {
    final result = await showModalBottomSheet<WalletTopUpResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      builder: (_) => _TopUpSheet(onTopUp: onTopUp),
    );
    if (result == null || !context.mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${formatCurrency(result.transaction.amount)} added.'),
      ),
    );
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
            Text(
              'Transaction history',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            Flexible(
              child: ListView.separated(
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
                            isCredit ? Icons.south_west : Icons.north_east,
                            color: isCredit
                                ? AppColors.success
                                : const Color(0xFFC43B31),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                transaction.description,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${formatShortDate(transaction.createdAt)} · ${formatTime(transaction.createdAt)}',
                                style: Theme.of(context).textTheme.bodyMedium,
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

class _TopUpSheet extends StatefulWidget {
  const _TopUpSheet({required this.onTopUp});

  final Future<WalletTopUpResult> Function(double amount) onTopUp;

  @override
  State<_TopUpSheet> createState() => _TopUpSheetState();
}

class _TopUpSheetState extends State<_TopUpSheet> {
  final _controller = TextEditingController(text: '500');
  double _amount = 500;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_controller.text.trim());
    if (amount == null || amount < 50 || amount > 5000) {
      setState(() => _error = 'Enter an amount between ₹50 and ₹5,000.');
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
      if (mounted) setState(() => _error = error.toString());
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
            children: [100.0, 200.0, 500.0, 1000.0].map((amount) {
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
