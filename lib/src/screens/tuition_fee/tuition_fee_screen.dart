import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/module_navigation_buttons.dart';
import '../../features/authentication/data/auth_repository.dart';
import 'tuition_fee_repository.dart';

class TuitionFeeScreen extends StatefulWidget {
  const TuitionFeeScreen({
    required this.session,
    required this.repository,
    required this.onExitModule,
    super.key,
  });

  final UserSession session;
  final TuitionFeeRepository repository;
  final VoidCallback onExitModule;

  @override
  State<TuitionFeeScreen> createState() => _TuitionFeeScreenState();
}

class _TuitionFeeScreenState extends State<TuitionFeeScreen> {
  late Future<List<StudentFeeRecord>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.load();
  }

  void _reload() => setState(() => _future = widget.repository.load());

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Tuition Fee'),
      leading: ModuleBackButton(onPressed: widget.onExitModule),
      actions: [
        IconButton(onPressed: _reload, icon: const Icon(Icons.refresh_rounded)),
        ModuleHomeButton(onPressed: widget.onExitModule),
      ],
    ),
    body: FutureBuilder<List<StudentFeeRecord>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _FeeLoading();
        }
        if (snapshot.hasError) {
          return _FeeError(
            message: snapshot.error is TuitionFeeException
                ? (snapshot.error! as TuitionFeeException).message
                : 'Your fee account could not be loaded.',
            onRetry: _reload,
          );
        }
        return _FeeAccount(
          session: widget.session,
          records: snapshot.data ?? const [],
        );
      },
    ),
  );
}

class _FeeAccount extends StatelessWidget {
  const _FeeAccount({required this.session, required this.records});
  final UserSession session;
  final List<StudentFeeRecord> records;

  @override
  Widget build(BuildContext context) {
    final account = records
        .where((row) => row.type == 'student_fee_accounts')
        .firstOrNull;
    final assignments = records
        .where((row) => row.type == 'fee_assignment')
        .toList();
    final payments = records.where((row) => row.type == 'payments').toList()
      ..sort(
        (a, b) => _text(
          b.data['paymentDate'],
        ).compareTo(_text(a.data['paymentDate'])),
      );
    final fines = records
        .where((row) => row.type == 'fines_penalties')
        .toList();
    final assigned = account == null
        ? assignments.fold<double>(
            0,
            (sum, row) => sum + _number(row.data['amountPerStudent']),
          )
        : _number(account.data['totalAssigned']);
    final paid = account == null
        ? payments
              .where(
                (row) => !{
                  'failed',
                  'reversed',
                  'void',
                }.contains(_text(row.data['status']).toLowerCase()),
              )
              .fold<double>(0, (sum, row) => sum + _number(row.data['amount']))
        : _number(account.data['paid']);
    final waiver = _number(account?.data['discountWaiver']);
    final fine = account == null
        ? fines.fold<double>(
            0,
            (sum, row) =>
                sum +
                _number(row.data['amount']) -
                _number(row.data['waivedAmount']),
          )
        : _number(account.data['fine']);
    final outstanding = account == null
        ? (assigned + fine - waiver - paid).clamp(0, double.infinity).toDouble()
        : _number(account.data['outstanding']);

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
      children: [
        Text(
          'Student fee account',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.brandLavender,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          session.displayName,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        Text(
          session.idNumber ?? session.email,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: AppColors.violetGradient,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.account_balance_wallet_outlined,
                color: Colors.white,
              ),
              const SizedBox(height: 18),
              const Text(
                'Outstanding',
                style: TextStyle(color: Colors.white70),
              ),
              Text(
                _money(outstanding),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 31,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(child: _metric('Assigned', assigned)),
                  Expanded(child: _metric('Paid', paid)),
                  Expanded(child: _metric('Waiver', waiver)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        _sectionTitle('Assigned fees'),
        if (assignments.isEmpty)
          _emptyCard('No fee has been assigned yet.')
        else
          ...assignments.map(
            (row) => _recordCard(
              title: _text(
                row.data['feeStructure'],
                fallback: 'Fee assignment',
              ),
              subtitle:
                  '${_text(row.data['academicContext'])} · ${_text(row.data['status'])}',
              amount: _number(row.data['amountPerStudent']),
            ),
          ),
        if (fine > 0)
          _recordCard(
            title: 'Fines & penalties',
            subtitle: '${fines.length} active item(s)',
            amount: fine,
            danger: true,
          ),
        const SizedBox(height: 20),
        _sectionTitle('Payment history & receipts'),
        if (payments.isEmpty)
          _emptyCard('No payments recorded yet.')
        else
          ...payments.map(
            (row) => _recordCard(
              title: _text(row.data['paymentReference'], fallback: 'Payment'),
              subtitle:
                  '${_text(row.data['paymentDate'])} · ${_text(row.data['method'])} · ${_text(row.data['status'])}',
              amount: _number(row.data['amount']),
            ),
          ),
      ],
    );
  }

  Widget _metric(String label, double value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      Text(
        _money(value),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
  Widget _sectionTitle(String value) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Text(
      value,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
    ),
  );
  Widget _emptyCard(String value) => Card(
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: Center(
        child: Text(value, style: const TextStyle(color: AppColors.muted)),
      ),
    ),
  );
  Widget _recordCard({
    required String title,
    required String subtitle,
    required double amount,
    bool danger = false,
  }) => Card(
    child: ListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Text(
        _money(amount),
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: danger ? Colors.red : AppColors.brandBlue,
        ),
      ),
    ),
  );
}

class _FeeLoading extends StatelessWidget {
  const _FeeLoading();
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(18),
    children: [
      for (final height in [190.0, 78.0, 78.0, 110.0])
        Container(
          height: height,
          margin: const EdgeInsets.only(bottom: 13),
          decoration: BoxDecoration(
            color: AppColors.moduleSoft,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
    ],
  );
}

class _FeeError extends StatelessWidget {
  const _FeeError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 38),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    ),
  );
}

String _money(double value) => '₹${value.toStringAsFixed(0)}';
double _number(Object? value) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
String _text(Object? value, {String fallback = '—'}) {
  final result = value?.toString().trim() ?? '';
  return result.isEmpty ? fallback : result;
}
