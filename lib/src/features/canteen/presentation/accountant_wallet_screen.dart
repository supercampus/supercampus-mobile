import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/skeleton_loading.dart';
import '../data/accountant_wallet_repository.dart';

class AccountantWalletScreen extends StatefulWidget {
  const AccountantWalletScreen({
    super.key,
    required this.repository,
    required this.accountantName,
    required this.onSignOut,
  });

  final AccountantWalletRepository repository;
  final String accountantName;
  final VoidCallback onSignOut;

  @override
  State<AccountantWalletScreen> createState() => _AccountantWalletScreenState();
}

class _AccountantWalletScreenState extends State<AccountantWalletScreen> {
  final _search = TextEditingController();
  List<StudentWalletAccount>? _wallets;
  List<AccountantWalletTransaction>? _transactions;
  String? _error;
  Timer? _debounce;
  bool _showActivity = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final results = await Future.wait([
        widget.repository.listWallets(search: _search.text),
        widget.repository.listTransactions(),
      ]);
      if (mounted) {
        setState(() {
          _wallets = results[0] as List<StudentWalletAccount>;
          _transactions = results[1] as List<AccountantWalletTransaction>;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  void _searchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _load);
  }

  Future<void> _openCredit(StudentWalletAccount wallet) async {
    final result = await showModalBottomSheet<_CreditRequest>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _CreditWalletSheet(wallet: wallet),
    );
    if (result == null || !mounted) return;
    try {
      await widget.repository.creditWallet(
        userId: wallet.userId,
        amount: result.amount,
        reference: result.reference,
      );
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${result.amount.toStringAsFixed(0)} credits added to ${wallet.studentName}',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallets = _wallets;
    final total =
        wallets?.fold<double>(0, (sum, item) => sum + item.balance) ?? 0;
    final today = DateTime.now();
    final creditedToday =
        (_transactions ?? const <AccountantWalletTransaction>[])
            .where(
              (item) =>
                  item.isCredit &&
                  item.createdAt.toLocal().year == today.year &&
                  item.createdAt.toLocal().month == today.month &&
                  item.createdAt.toLocal().day == today.day,
            )
            .fold<double>(0, (sum, item) => sum + item.amount);
    return Scaffold(
      backgroundColor: const Color(0xFFF6F4FF),
      appBar: AppBar(
        title: const Text('Accounts'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: widget.onSignOut,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 36),
          children: [
            Text(
              'Hello, ${widget.accountantName}',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text('Student wallet credits and transaction records.'),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppColors.violetGradient,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.account_balance_wallet_rounded,
                        color: Colors.white,
                      ),
                      SizedBox(width: 9),
                      Text(
                        'Wallet overview',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _SummaryValue(
                          label: 'Wallet float',
                          value: total.toStringAsFixed(0),
                        ),
                      ),
                      Expanded(
                        child: _SummaryValue(
                          label: 'Credited today',
                          value: creditedToday.toStringAsFixed(0),
                        ),
                      ),
                      Expanded(
                        child: _SummaryValue(
                          label: 'Students',
                          value: '${wallets?.length ?? 0}',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  icon: Icon(Icons.people_rounded),
                  label: Text('Student wallets'),
                ),
                ButtonSegment(
                  value: true,
                  icon: Icon(Icons.receipt_long_rounded),
                  label: Text('Activity'),
                ),
              ],
              selected: {_showActivity},
              onSelectionChanged: (value) =>
                  setState(() => _showActivity = value.first),
            ),
            const SizedBox(height: 18),
            if (!_showActivity) ...[
              TextField(
                controller: _search,
                onChanged: _searchChanged,
                decoration: InputDecoration(
                  hintText: 'Search name, roll number or department',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 18),
            ],
            if (_error != null)
              _ErrorCard(message: _error!, onRetry: _load)
            else if (wallets == null || _transactions == null)
              const SizedBox(
                height: 552,
                child: SkeletonList(rows: 6, rowHeight: 82),
              )
            else if (_showActivity && _transactions!.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 56),
                child: Center(child: Text('No wallet activity yet.')),
              )
            else if (_showActivity)
              ..._transactions!.map(
                (transaction) => _TransactionCard(transaction: transaction),
              )
            else if (wallets.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 56),
                child: Center(child: Text('No student wallets found.')),
              )
            else
              ...wallets.map(
                (wallet) => _WalletCard(
                  wallet: wallet,
                  onCredit: () => _openCredit(wallet),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        value,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 23,
          fontWeight: FontWeight.w800,
        ),
      ),
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
    ],
  );
}

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({required this.transaction});
  final AccountantWalletTransaction transaction;

  String _time(DateTime value) {
    final local = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} · '
        '${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    elevation: 0,
    color: Colors.white,
    child: ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.brandLavender,
        foregroundColor: AppColors.primary,
        child: Icon(
          transaction.isCredit
              ? Icons.south_west_rounded
              : Icons.north_east_rounded,
        ),
      ),
      title: Text(
        transaction.studentName,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        [
          transaction.studentNumber,
          _time(transaction.createdAt),
          if (transaction.referenceId?.isNotEmpty == true)
            'Ref: ${transaction.referenceId}',
        ].where((item) => item.isNotEmpty).join('\n'),
      ),
      trailing: Text(
        '${transaction.isCredit ? '+' : ''}${transaction.amount.toStringAsFixed(0)}',
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
  );
}

class _WalletCard extends StatelessWidget {
  const _WalletCard({required this.wallet, required this.onCredit});

  final StudentWalletAccount wallet;
  final VoidCallback onCredit;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.brandLavender,
              foregroundColor: AppColors.primary,
              child: Text(
                wallet.studentName.isEmpty
                    ? 'S'
                    : wallet.studentName[0].toUpperCase(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    wallet.studentName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    [
                      wallet.studentNumber,
                      wallet.department,
                    ].where((value) => value.isNotEmpty).join(' · '),
                    style: const TextStyle(color: Color(0xFF747080)),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  wallet.balance.toStringAsFixed(0),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Text('credits', style: TextStyle(fontSize: 11)),
              ],
            ),
            const SizedBox(width: 10),
            IconButton.filled(
              key: ValueKey('credit-${wallet.userId}'),
              tooltip: 'Add credits',
              onPressed: onCredit,
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreditRequest {
  const _CreditRequest(this.amount, this.reference);
  final double amount;
  final String reference;
}

class _CreditWalletSheet extends StatefulWidget {
  const _CreditWalletSheet({required this.wallet});
  final StudentWalletAccount wallet;

  @override
  State<_CreditWalletSheet> createState() => _CreditWalletSheetState();
}

class _CreditWalletSheetState extends State<_CreditWalletSheet> {
  final _amount = TextEditingController();
  final _reference = TextEditingController();

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        22,
        18,
        22,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Add wallet credits',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text('${widget.wallet.studentName} · ${widget.wallet.studentNumber}'),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            children: [
              for (final value in const [100, 250, 500, 1000])
                ActionChip(
                  label: Text('$value'),
                  onPressed: () => _amount.text = '$value',
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Credits to add',
              prefixIcon: Icon(Icons.add_card_rounded),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _reference,
            decoration: const InputDecoration(
              labelText: 'Receipt or payment reference (optional)',
              prefixIcon: Icon(Icons.receipt_long_rounded),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            key: const ValueKey('confirm-wallet-credit'),
            onPressed: () {
              final amount = double.tryParse(_amount.text.trim());
              if (amount == null || amount <= 0 || amount > 100000) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enter a valid credit amount.')),
                );
                return;
              }
              Navigator.pop(
                context,
                _CreditRequest(amount, _reference.text.trim()),
              );
            },
            icon: const Icon(Icons.verified_rounded),
            label: const Text('Confirm credit'),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.errorContainer,
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Text(message, textAlign: TextAlign.center),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    ),
  );
}
