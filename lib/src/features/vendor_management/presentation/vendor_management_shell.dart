import 'package:flutter/material.dart';

import '../../../core/widgets/module_navigation_buttons.dart';

import '../../../core/theme/app_theme.dart';
import '../../authentication/data/auth_repository.dart';
import '../data/mock_vendor_repository.dart';
import '../data/vendor_models.dart';

class VendorManagementShell extends StatefulWidget {
  const VendorManagementShell({
    super.key,
    required this.session,
    required this.onExitModule,
  });
  final UserSession session;
  final VoidCallback onExitModule;
  @override
  State<VendorManagementShell> createState() => _VendorManagementShellState();
}

class _VendorManagementShellState extends State<VendorManagementShell> {
  final _repo = MockVendorRepository();
  var _tab = 0;

  Future<void> _addVendor() async {
    final vendor = await showModalBottomSheet<Vendor>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _AddVendorSheet(),
    );
    if (vendor != null && mounted) {
      setState(() => _repo.vendors.insert(0, vendor));
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _vendorList(),
      _orderList(),
      _paymentList(),
      _workOrderList(),
    ];
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: const Color(0xFF8A4B20),
        foregroundColor: Colors.white,
        leading: ModuleBackButton(
          onPressed: widget.onExitModule,
          color: Colors.white,
        ),
        title: const Text('Vendor Management'),
        actions: [
          IconButton(
            onPressed: _tab == 0 ? _addVendor : null,
            icon: const Icon(Icons.add_business_outlined),
          ),
          ModuleHomeButton(onPressed: widget.onExitModule, color: Colors.white),
        ],
      ),
      body: IndexedStack(index: _tab, children: pages),
    );
  }

  Widget _vendorList() => ListView(
    padding: const EdgeInsets.all(18),
    children: [
      _Summary(
        count: _repo.vendors
            .where((v) => v.status == VendorStatus.active)
            .length,
      ),
      const SizedBox(height: 16),
      for (final vendor in _repo.vendors) ...[
        _VendorTile(vendor: vendor),
        const SizedBox(height: 10),
      ],
    ],
  );

  Widget _orderList() => _records('Purchase orders', [
    for (final item in _repo.purchaseOrders)
      _RecordTile(
        title: item.id,
        subtitle: item.vendor,
        amount: item.amount,
        status: item.status,
      ),
  ]);
  Widget _paymentList() => _records('Payments and history', [
    for (final item in _repo.payments)
      _RecordTile(
        title: item.id,
        subtitle: '${item.vendor} · ${item.date}',
        amount: item.amount,
        status: item.status,
      ),
  ]);
  Widget _workOrderList() => _records('Work orders', const [
    _WorkTile(
      title: 'WO-2026-018',
      subtitle: 'GreenScape Works · East lawn maintenance',
      status: 'In progress',
    ),
    _WorkTile(
      title: 'WO-2026-017',
      subtitle: 'Campus Tech Systems · Network cabinet repair',
      status: 'Completed',
    ),
  ]);
  Widget _records(String title, List<Widget> items) => ListView(
    padding: const EdgeInsets.all(18),
    children: [
      Text(title, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 14),
      for (final item in items) ...[item, const SizedBox(height: 10)],
    ],
  );
}

class _Summary extends StatelessWidget {
  const _Summary({required this.count});
  final int count;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF8A4B20).withValues(alpha: .1),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        const Icon(Icons.verified_outlined, color: Color(0xFF8A4B20)),
        const SizedBox(width: 10),
        const Text('Active vendors'),
        const Spacer(),
        Text(
          '$count',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}

class _VendorTile extends StatelessWidget {
  const _VendorTile({required this.vendor});
  final Vendor vendor;
  @override
  Widget build(BuildContext context) {
    final color = vendor.status == VendorStatus.active
        ? AppColors.success
        : const Color(0xFFB77500);
    return Card(
      elevation: 0,
      child: ListTile(
        leading: const Icon(
          Icons.storefront_outlined,
          color: Color(0xFF8A4B20),
        ),
        title: Text(vendor.name),
        subtitle: Text('${vendor.category}\n${vendor.contact}'),
        isThreeLine: true,
        trailing: Chip(
          label: Text(vendor.status.name),
          labelStyle: TextStyle(color: color, fontSize: 11),
          backgroundColor: color.withValues(alpha: .1),
          side: BorderSide.none,
        ),
      ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.status,
  });
  final String title;
  final String subtitle;
  final double amount;
  final String status;
  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    child: ListTile(
      leading: const Icon(
        Icons.receipt_long_outlined,
        color: Color(0xFF8A4B20),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '₹${amount.toStringAsFixed(0)}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Text(
            status,
            style: const TextStyle(color: AppColors.muted, fontSize: 11),
          ),
        ],
      ),
    ),
  );
}

class _WorkTile extends StatelessWidget {
  const _WorkTile({
    required this.title,
    required this.subtitle,
    required this.status,
  });
  final String title;
  final String subtitle;
  final String status;
  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    child: ListTile(
      leading: const Icon(Icons.build_outlined, color: Color(0xFF8A4B20)),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Text(
        status,
        style: const TextStyle(fontSize: 11, color: AppColors.muted),
      ),
    ),
  );
}

class _AddVendorSheet extends StatefulWidget {
  const _AddVendorSheet();
  @override
  State<_AddVendorSheet> createState() => _AddVendorSheetState();
}

class _AddVendorSheetState extends State<_AddVendorSheet> {
  final _name = TextEditingController();
  final _contact = TextEditingController();
  var _category = 'General supplies';
  @override
  void dispose() {
    _name.dispose();
    _contact.dispose();
    super.dispose();
  }

  void _submit() {
    if (_name.text.trim().isEmpty) return;
    Navigator.of(context).pop(
      Vendor(
        id: 'VEN-${DateTime.now().millisecondsSinceEpoch % 1000}',
        name: _name.text.trim(),
        category: _category,
        contact: _contact.text.trim().isEmpty
            ? 'Contact pending'
            : _contact.text.trim(),
        status: VendorStatus.pending,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Add vendor', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Vendor name'),
            ),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: const [
                DropdownMenuItem(
                  value: 'General supplies',
                  child: Text('General supplies'),
                ),
                DropdownMenuItem(
                  value: 'Canteen & Mess',
                  child: Text('Canteen & Mess'),
                ),
                DropdownMenuItem(
                  value: 'IT Services',
                  child: Text('IT Services'),
                ),
                DropdownMenuItem(
                  value: 'Facilities',
                  child: Text('Facilities'),
                ),
              ],
              onChanged: (value) =>
                  setState(() => _category = value ?? _category),
            ),
            TextField(
              controller: _contact,
              decoration: const InputDecoration(
                labelText: 'Contact email or phone',
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _submit,
              child: const Text('Submit vendor for review'),
            ),
          ],
        ),
      ),
    ),
  );
}
