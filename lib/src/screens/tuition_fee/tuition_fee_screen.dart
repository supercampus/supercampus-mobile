import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/transaction_result_overlay.dart';
import '../../core/widgets/module_navigation_buttons.dart';
import '../../features/authentication/data/auth_repository.dart';
import 'razorpay_checkout.dart';
import 'fee_receipt_exporter.dart';
import 'tuition_fee_repository.dart';

class TuitionFeeScreen extends StatefulWidget {
  const TuitionFeeScreen({
    required this.session,
    required this.repository,
    required this.onExitModule,
    this.canManageFees = false,
    super.key,
  });

  final UserSession session;
  final TuitionFeeRepository repository;
  final VoidCallback onExitModule;
  final bool canManageFees;

  @override
  State<TuitionFeeScreen> createState() => _TuitionFeeScreenState();
}

class _TuitionFeeScreenState extends State<TuitionFeeScreen> {
  late Future<List<StudentFeeRecord>> _future;
  late Future<AdminFeeData> _adminFuture;

  @override
  void initState() {
    super.initState();
    if (widget.canManageFees) {
      _future = Future.value(const []);
      _adminFuture = widget.repository.loadAdmin();
    } else {
      _future = widget.repository.load();
      _adminFuture = Future.value(
        const AdminFeeData(records: [], students: []),
      );
    }
  }

  void _reload() => setState(() {
    if (widget.canManageFees) {
      _adminFuture = widget.repository.loadAdmin();
    } else {
      _future = widget.repository.load();
    }
  });

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
    body: widget.canManageFees
        ? FutureBuilder<AdminFeeData>(
            future: _adminFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const _FeeLoading();
              }
              if (snapshot.hasError) {
                return _FeeError(
                  message: snapshot.error is TuitionFeeException
                      ? (snapshot.error! as TuitionFeeException).message
                      : 'Fee management could not be loaded.',
                  onRetry: _reload,
                );
              }
              return _AdminFeeWorkspace(
                data:
                    snapshot.data ??
                    const AdminFeeData(records: [], students: []),
                repository: widget.repository,
                onChanged: _reload,
              );
            },
          )
        : FutureBuilder<List<StudentFeeRecord>>(
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
                repository: widget.repository,
                onPaymentVerified: _reload,
              );
            },
          ),
  );
}

class _AdminFeeWorkspace extends StatefulWidget {
  const _AdminFeeWorkspace({
    required this.data,
    required this.repository,
    required this.onChanged,
  });

  final AdminFeeData data;
  final TuitionFeeRepository repository;
  final VoidCallback onChanged;

  @override
  State<_AdminFeeWorkspace> createState() => _AdminFeeWorkspaceState();
}

class _AdminFeeWorkspaceState extends State<_AdminFeeWorkspace> {
  var _saving = false;

  @override
  Widget build(BuildContext context) {
    final assignments =
        widget.data.records
            .where((row) => row.type == 'fee_assignment')
            .toList()
          ..sort(
            (a, b) => _text(
              b.data['assignedAt'],
            ).compareTo(_text(a.data['assignedAt'])),
          );
    final payments = widget.data.records
        .where((row) => row.type == 'payments')
        .toList();
    final assignedTotal = assignments.fold<double>(
      0,
      (sum, row) => sum + _number(row.data['amountPerStudent']),
    );
    final collectedTotal = payments
        .where(
          (row) => !{
            'failed',
            'reversed',
            'void',
          }.contains(_text(row.data['status']).toLowerCase()),
        )
        .fold<double>(0, (sum, row) => sum + _number(row.data['amount']));

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: AppColors.violetGradient,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.account_balance_outlined, color: Colors.white),
              const SizedBox(height: 14),
              const Text(
                'Fee administration',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Text(
                'Assign student fees and monitor verified payments.',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _adminMetric(
                      'Students',
                      '${widget.data.students.length}',
                    ),
                  ),
                  Expanded(
                    child: _adminMetric('Assigned', _money(assignedTotal)),
                  ),
                  Expanded(
                    child: _adminMetric('Collected', _money(collectedTotal)),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const ValueKey('assign-student-fee'),
                  onPressed: _saving || widget.data.students.isEmpty
                      ? null
                      : _openAssignment,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.brandBlue,
                  ),
                  icon: const Icon(Icons.add_card_rounded),
                  label: const Text('Assign fee to student'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  key: const ValueKey('mark-hostel-fee-paid'),
                  onPressed: _saving || widget.data.students.isEmpty
                      ? null
                      : _openHostelAccess,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white70),
                  ),
                  icon: const Icon(Icons.hotel_rounded),
                  label: const Text('Mark hostel fee paid'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _saving ? null : _openDiningSettings,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white70),
                  ),
                  icon: const Icon(Icons.tune_rounded),
                  label: const Text('Hostel dining options'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        _adminSectionTitle('Recent fee assignments', assignments.length),
        if (assignments.isEmpty)
          _adminEmpty('No student fees have been assigned yet.')
        else
          ...assignments
              .take(50)
              .map(
                (row) => Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.person_outline_rounded),
                    ),
                    title: Text(
                      _text(row.data['studentName'], fallback: 'Student'),
                    ),
                    subtitle: Text(
                      '${_text(row.data['studentNumber'])} · ${_text(row.data['feeStructure'], fallback: 'Fee assignment')}',
                    ),
                    trailing: Text(
                      _money(_number(row.data['amountPerStudent'])),
                      style: const TextStyle(
                        color: AppColors.brandBlue,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
        const SizedBox(height: 16),
        _adminSectionTitle('Verified payment history', payments.length),
        if (payments.isEmpty)
          _adminEmpty('No payments have been recorded yet.')
        else
          ...payments
              .take(50)
              .map(
                (row) => Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.verified_outlined),
                    ),
                    title: Text(
                      _text(
                        row.data['studentName'],
                        fallback: 'Student payment',
                      ),
                    ),
                    subtitle: Text(
                      '${_text(row.data['studentNumber'])} · ${_text(row.data['status'])}',
                    ),
                    trailing: Text(
                      _money(_number(row.data['amount'])),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
      ],
    );
  }

  Widget _adminMetric(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      const SizedBox(height: 2),
      Text(
        value,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );

  Widget _adminSectionTitle(String title, int count) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ),
        Text('$count', style: const TextStyle(color: AppColors.muted)),
      ],
    ),
  );

  Widget _adminEmpty(String message) => Card(
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: Center(
        child: Text(message, style: const TextStyle(color: AppColors.muted)),
      ),
    ),
  );

  Future<void> _openAssignment() async {
    final titleController = TextEditingController(text: 'Tuition fee');
    final contextController = TextEditingController(
      text: 'Academic year 2026–27',
    );
    final amountController = TextEditingController();
    FeeStudent? selectedStudent;
    final submit = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            MediaQuery.viewInsetsOf(context).bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.muted.withValues(alpha: .5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Assign student fee',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 18),
                DropdownButtonFormField<FeeStudent>(
                  key: const ValueKey('fee-student-selector'),
                  initialValue: selectedStudent,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Student',
                    prefixIcon: Icon(Icons.person_search_outlined),
                  ),
                  items: widget.data.students
                      .map(
                        (student) => DropdownMenuItem(
                          value: student,
                          child: Text(
                            '${student.name} · ${student.rollNumber}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) =>
                      setSheetState(() => selectedStudent = value),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Fee title'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contextController,
                  decoration: const InputDecoration(
                    labelText: 'Academic context',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey('fee-amount-field'),
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    prefixText: '₹ ',
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(sheetContext, true),
                    child: const Text('Assign fee'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (submit != true) return;
    final amount = double.tryParse(amountController.text.trim());
    if (selectedStudent == null ||
        titleController.text.trim().isEmpty ||
        amount == null ||
        amount < 1) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Select a student and enter a valid fee title and amount.',
          ),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.repository.createFeeAssignment(
        student: selectedStudent!,
        title: titleController.text,
        academicContext: contextController.text,
        amount: amount,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fee assigned to ${selectedStudent!.name}.')),
      );
      widget.onChanged();
    } on TuitionFeeException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      titleController.dispose();
      contextController.dispose();
      amountController.dispose();
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openHostelAccess() async {
    FeeStudent? selectedStudent;
    var validFrom = DateTime.now();
    var validUntil = DateTime(DateTime.now().year + 1, 5, 31);
    final referenceController = TextEditingController();
    final submit = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            14,
            20,
            MediaQuery.viewInsetsOf(context).bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Activate hostel meal access',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 6),
                const Text(
                  'Creates three one-use meal QRs per day only inside this paid coverage period.',
                  style: TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 18),
                DropdownButtonFormField<FeeStudent>(
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Hosteller',
                    prefixIcon: Icon(Icons.person_search_rounded),
                  ),
                  items: widget.data.students
                      .map(
                        (student) => DropdownMenuItem(
                          value: student,
                          child: Text(
                            '${student.name} · ${student.rollNumber}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) =>
                      setSheetState(() => selectedStudent = value),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: referenceController,
                  decoration: const InputDecoration(
                    labelText: 'Payment reference (optional)',
                    prefixIcon: Icon(Icons.receipt_long_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _DateChoice(
                        label: 'Access starts',
                        value: validFrom,
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2035),
                            initialDate: validFrom,
                          );
                          if (picked != null) {
                            setSheetState(() => validFrom = picked);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _DateChoice(
                        label: 'Access ends',
                        value: validUntil,
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            firstDate: validFrom,
                            lastDate: DateTime(2035),
                            initialDate: validUntil.isBefore(validFrom)
                                ? validFrom
                                : validUntil,
                          );
                          if (picked != null) {
                            setSheetState(() => validUntil = picked);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(sheetContext, true),
                    icon: const Icon(Icons.verified_user_outlined),
                    label: const Text('Confirm fee paid & activate'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (submit != true) {
      referenceController.dispose();
      return;
    }
    if (selectedStudent == null || validUntil.isBefore(validFrom)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select a student and valid dates.')),
        );
      }
      referenceController.dispose();
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.repository.markHostelFeePaid(
        student: selectedStudent!,
        validFrom: validFrom,
        validUntil: validUntil,
        paymentReference: referenceController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Hostel meal access activated for ${selectedStudent!.name}.',
          ),
        ),
      );
      widget.onChanged();
    } on TuitionFeeException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      referenceController.dispose();
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openDiningSettings() async {
    var menuEnabled = true;
    var messEnabled = true;
    final submit = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hostel dining options',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              const Text(
                'Choose which food experiences hostellers can access.',
                style: TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 14),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: menuEnabled,
                onChanged: (value) => setSheetState(() => menuEnabled = value),
                title: const Text('Menu-based ordering'),
                subtitle: const Text('Browse and order from the campus menu'),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: messEnabled,
                onChanged: (value) => setSheetState(() => messEnabled = value),
                title: const Text('Mess meal passes'),
                subtitle: const Text(
                  'Three fee-linked meal QRs per covered day',
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(sheetContext, true),
                  child: const Text('Save dining options'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (submit != true) return;
    setState(() => _saving = true);
    try {
      await widget.repository.updateHostelDiningSettings(
        menuEnabled: menuEnabled,
        messEnabled: messEnabled,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hostel dining options updated.')),
        );
      }
    } on TuitionFeeException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _DateChoice extends StatelessWidget {
  const _DateChoice({
    required this.label,
    required this.value,
    required this.onTap,
  });
  final String label;
  final DateTime value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: InputDecorator(
      decoration: InputDecoration(labelText: label),
      child: Text(
        '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}',
      ),
    ),
  );
}

class _FeeAccount extends StatefulWidget {
  const _FeeAccount({
    required this.session,
    required this.records,
    required this.repository,
    required this.onPaymentVerified,
  });

  final UserSession session;
  final List<StudentFeeRecord> records;
  final TuitionFeeRepository repository;
  final VoidCallback onPaymentVerified;

  @override
  State<_FeeAccount> createState() => _FeeAccountState();
}

class _FeeAccountState extends State<_FeeAccount> {
  var _paying = false;

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final records = widget.records;
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
    final recordedPayments = payments
        .where(
          (row) => !{
            'failed',
            'reversed',
            'void',
          }.contains(_text(row.data['status']).toLowerCase()),
        )
        .fold<double>(0, (sum, row) => sum + _number(row.data['amount']));
    final paid =
        (account == null
                ? recordedPayments
                : _number(
                    account.data['paid'],
                  ).clamp(recordedPayments, double.infinity))
            .toDouble();
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
    final outstanding = (assigned + fine - waiver - paid)
        .clamp(0, double.infinity)
        .toDouble();

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
              if (outstanding >= 1) ...[
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const ValueKey('pay-tuition-fee'),
                    onPressed: _paying
                        ? null
                        : () => _payOutstanding(outstanding),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.brandBlue,
                    ),
                    icon: _paying
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.lock_outline_rounded),
                    label: Text(
                      _paying ? 'Opening secure checkout…' : 'Pay now',
                    ),
                  ),
                ),
              ],
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
          ...payments.map((row) => _paymentCard(row)),
      ],
    );
  }

  Future<void> _payOutstanding(double outstanding) async {
    if (_paying) return;
    setState(() => _paying = true);
    try {
      final amount = (outstanding * 100).round();
      final identity = (widget.session.idNumber ?? 'student').replaceAll(
        RegExp('[^A-Za-z0-9]'),
        '',
      );
      final suffix = identity.length <= 8
          ? identity
          : identity.substring(identity.length - 8);
      final receipt = 'sc_${DateTime.now().millisecondsSinceEpoch}_$suffix';
      final order = await widget.repository.createOrder(
        amount: amount,
        receipt: receipt.length <= 40 ? receipt : receipt.substring(0, 40),
      );
      final checkout = await const RazorpayCheckoutClient().open(
        keyId: order.keyId,
        orderId: order.id,
        amount: order.amount,
        currency: order.currency,
        name: 'SuperCampus',
        description: 'Tuition fee payment',
        customerName: widget.session.displayName,
        customerEmail: widget.session.email,
      );
      await widget.repository.verifyPayment(
        paymentId: checkout.paymentId,
        orderId: checkout.orderId,
        signature: checkout.signature,
      );
      if (!mounted) return;
      await showTransactionResult(
        context,
        result: TransactionResult.success,
        title: 'Fee payment successful',
        message: 'Your payment was verified and your receipt is now available.',
        amount: _money(outstanding),
        reference: 'Payment ${checkout.paymentId}',
      );
      if (!mounted) return;
      widget.onPaymentVerified();
    } on RazorpayCheckoutException catch (error) {
      if (!mounted) return;
      if (error.cancelled) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Payment cancelled.')));
      } else {
        await showTransactionResult(
          context,
          result: TransactionResult.failure,
          title: 'Payment unsuccessful',
          message: error.message,
          amount: _money(outstanding),
        );
      }
    } on TuitionFeeException catch (error) {
      if (!mounted) return;
      await showTransactionResult(
        context,
        result: TransactionResult.failure,
        title: 'Payment unsuccessful',
        message: error.message,
        amount: _money(outstanding),
      );
    } catch (_) {
      if (!mounted) return;
      await showTransactionResult(
        context,
        result: TransactionResult.failure,
        title: 'Payment unsuccessful',
        message: 'Payment could not be completed. Please try again.',
        amount: _money(outstanding),
      );
    } finally {
      if (mounted) setState(() => _paying = false);
    }
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

  Widget _paymentCard(StudentFeeRecord row) {
    final verified = {
      'verified',
      'success',
      'paid',
    }.contains(_text(row.data['status']).toLowerCase());
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: verified
                      ? Colors.green.withValues(alpha: .12)
                      : AppColors.moduleSoft,
                  child: Icon(
                    verified ? Icons.verified_rounded : Icons.receipt_long,
                    color: verified ? Colors.green.shade700 : AppColors.muted,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _money(_number(row.data['amount'])),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        _text(
                          row.data['paymentReference'],
                          fallback: 'Payment',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (verified)
                  IconButton.filledTonal(
                    tooltip: 'Download receipt',
                    onPressed: () => _downloadReceipt(row),
                    icon: const Icon(Icons.download_rounded),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${_text(row.data['method'])} · ${_friendlyDate(row.data['paymentDate'])}',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ),
                Text(
                  verified ? 'Verified' : _text(row.data['status']),
                  style: TextStyle(
                    color: verified ? Colors.green.shade700 : AppColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadReceipt(StudentFeeRecord row) async {
    try {
      await const FeeReceiptExporter().save(widget.session, row);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Fee receipt downloaded.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Receipt could not be saved. Try again.')),
      );
    }
  }
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

String _friendlyDate(Object? value) {
  final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
  if (date == null) return _text(value);
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}
