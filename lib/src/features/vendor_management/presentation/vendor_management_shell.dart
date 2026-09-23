import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/module_navigation_buttons.dart';
import '../../authentication/data/auth_repository.dart';
import '../data/mock_vendor_repository.dart';
import '../data/vendor_models.dart';
import '../data/vendor_repository.dart';

class VendorManagementShell extends StatefulWidget {
  const VendorManagementShell({
    super.key,
    required this.session,
    required this.onExitModule,
    this.repository,
  });

  final UserSession session;
  final VoidCallback onExitModule;
  final VendorRepository? repository;

  @override
  State<VendorManagementShell> createState() => _VendorManagementShellState();
}

class _VendorManagementShellState extends State<VendorManagementShell> {
  final _mockRepo = MockVendorRepository();
  List<VendorShop>? _shops;
  String? _error;
  bool _loading = true;
  String _query = '';
  String _selectedCategory = 'all';
  final Set<String> _togglingIds = {};

  var _tab = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = widget.repository;
    if (repo == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final shops = await repo.listVendors();
      if (!mounted) return;
      setState(() {
        _shops = shops;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _addVendor() async {
    final existingCategories = _categories;
    final draft = await showModalBottomSheet<VendorShopDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AddVendorShopSheet(
        suggestedCategories: existingCategories,
      ),
    );
    if (draft == null || !mounted) return;

    final repo = widget.repository;
    if (repo != null) {
      try {
        final created = await repo.createVendor(draft);
        if (!mounted) return;
        setState(() {
          _shops = [created, ...?_shops];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${created.name} added to Campus Commerce.'),
            backgroundColor: const Color(0xFF167447),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } else {
      // Fallback to mock
      final vendor = Vendor(
        id: 'VEN-${DateTime.now().millisecondsSinceEpoch % 1000}',
        name: draft.name,
        category: draft.category,
        contact: draft.description.isNotEmpty ? draft.description : 'Pending contact',
        status: VendorStatus.active,
      );
      setState(() => _mockRepo.vendors.insert(0, vendor));
    }
  }

  Future<void> _editVendor(VendorShop shop) async {
    final draft = await showModalBottomSheet<VendorShopDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _EditVendorShopSheet(
        shop: shop,
        suggestedCategories: _categories,
      ),
    );
    if (draft == null || !mounted) return;

    final repo = widget.repository;
    if (repo != null) {
      try {
        final updated = await repo.updateVendor(shop.id, draft);
        if (!mounted) return;
        setState(() {
          _shops = [
            for (final s in _shops ?? const <VendorShop>[])
              if (s.id == shop.id) updated else s,
          ];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${updated.name} updated successfully.'),
            backgroundColor: const Color(0xFF167447),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _toggleStatus(VendorShop shop, bool newStatus) async {
    if (_togglingIds.contains(shop.id)) return;
    setState(() => _togglingIds.add(shop.id));

    final repo = widget.repository;
    if (repo != null) {
      try {
        await repo.toggleVendorStatus(shop, newStatus);
        if (!mounted) return;
        setState(() {
          _shops = [
            for (final s in _shops ?? const <VendorShop>[])
              if (s.id == shop.id) s.copyWith(isActive: newStatus) else s,
          ];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${shop.name} is now ${newStatus ? 'Active' : 'Disabled'}.',
            ),
            backgroundColor: newStatus ? const Color(0xFF167447) : Colors.grey[800],
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      } finally {
        if (mounted) setState(() => _togglingIds.remove(shop.id));
      }
    } else {
      setState(() => _togglingIds.remove(shop.id));
    }
  }

  void _showShopDetails(VendorShop shop) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: const Color(0xFF8A4B20).withValues(alpha: 0.15),
                  child: Icon(
                    _categoryIcon(shop.category),
                    color: const Color(0xFF8A4B20),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shop.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        shop.category,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(shop.isActive ? 'Active' : 'Disabled'),
                  labelStyle: TextStyle(
                    color: shop.isActive ? AppColors.success : Colors.grey,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  backgroundColor: (shop.isActive ? AppColors.success : Colors.grey)
                      .withValues(alpha: 0.12),
                  side: BorderSide.none,
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            _detailRow(Icons.key_outlined, 'Shop Key', shop.shopKey),
            _detailRow(
              Icons.description_outlined,
              'Description',
              shop.description.isNotEmpty ? shop.description : 'No description provided',
            ),
            _detailRow(
              Icons.qr_code_2_outlined,
              'QR Payments',
              shop.qrPayments ? 'Enabled' : 'Disabled',
            ),
            _detailRow(
              Icons.restaurant_outlined,
              'Meal Compliance',
              shop.mealCompliance ? 'Enabled' : 'Not required',
            ),
            if (shop.createdAt != null)
              _detailRow(
                Icons.calendar_today_outlined,
                'Created',
                '${shop.createdAt!.day}/${shop.createdAt!.month}/${shop.createdAt!.year}',
              ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _toggleStatus(shop, !shop.isActive);
                    },
                    icon: Icon(
                      shop.isActive ? Icons.block_outlined : Icons.check_circle_outline,
                    ),
                    label: Text(shop.isActive ? 'Disable shop' : 'Enable shop'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF8A4B20),
                    ),
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _editVendor(shop);
                    },
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit details'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<String> get _categories {
    final set = <String>{};
    for (final s in _shops ?? const <VendorShop>[]) {
      if (s.category.trim().isNotEmpty) set.add(s.category.trim());
    }
    if (set.isEmpty) {
      return ['Canteen', 'Stationery', 'Laundry', 'Services'];
    }
    return set.toList();
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
        title: const Text('Campus Commerce'),
        actions: [
          IconButton(
            tooltip: 'Refresh vendors',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Add vendor',
            onPressed: _addVendor,
            icon: const Icon(Icons.add_business_outlined),
          ),
          ModuleHomeButton(onPressed: widget.onExitModule, color: Colors.white),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (v) => setState(() => _tab = v),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront_rounded),
            label: 'Vendors',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_bag_outlined),
            selectedIcon: Icon(Icons.shopping_bag_rounded),
            label: 'Orders',
          ),
          NavigationDestination(
            icon: Icon(Icons.payments_outlined),
            selectedIcon: Icon(Icons.payments_rounded),
            label: 'Payments',
          ),
          NavigationDestination(
            icon: Icon(Icons.construction_outlined),
            selectedIcon: Icon(Icons.construction_rounded),
            label: 'Work Orders',
          ),
        ],
      ),
      body: IndexedStack(index: _tab, children: pages),
    );
  }

  Widget _vendorList() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 40),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(_error!, textAlign: TextAlign.center),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final shops = _shops;
    if (shops != null) {
      final query = _query.trim().toLowerCase();
      final filteredShops = shops.where((shop) {
        if (_selectedCategory != 'all' &&
            shop.category.toLowerCase() != _selectedCategory.toLowerCase()) {
          return false;
        }
        return query.isEmpty ||
            '${shop.name} ${shop.category} ${shop.description} ${shop.shopKey}'
                .toLowerCase()
                .contains(query);
      }).toList();

      final activeCount = shops.where((s) => s.isActive).length;
      final categories = _categories;

      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Summary(count: activeCount, total: shops.length),
          const SizedBox(height: 14),
          TextField(
            onChanged: (value) => setState(() => _query = value),
            decoration: const InputDecoration(
              hintText: 'Search vendors, shops, or categories',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: Text('All (${shops.length})'),
                  selected: _selectedCategory == 'all',
                  onSelected: (_) => setState(() => _selectedCategory = 'all'),
                ),
                for (final cat in categories) ...[
                  const SizedBox(width: 8),
                  FilterChip(
                    label: Text(
                      '$cat (${shops.where((s) => s.category.toLowerCase() == cat.toLowerCase()).length})',
                    ),
                    selected: _selectedCategory.toLowerCase() == cat.toLowerCase(),
                    onSelected: (selected) => setState(
                      () => _selectedCategory = selected ? cat : 'all',
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (filteredShops.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: Text('No vendors match your search / filter.')),
            )
          else
            for (final shop in filteredShops) ...[
              _VendorShopCard(
                shop: shop,
                isToggling: _togglingIds.contains(shop.id),
                onTap: () => _showShopDetails(shop),
                onEdit: () => _editVendor(shop),
                onToggleActive: (val) => _toggleStatus(shop, val),
              ),
              const SizedBox(height: 10),
            ],
        ],
      );
    }

    // Fallback if no backend repository passed
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        _Summary(
          count: _mockRepo.vendors
              .where((v) => v.status == VendorStatus.active)
              .length,
          total: _mockRepo.vendors.length,
        ),
        const SizedBox(height: 16),
        for (final vendor in _mockRepo.vendors) ...[
          _VendorTile(vendor: vendor),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _orderList() => _records('Purchase orders', [
        for (final item in _mockRepo.purchaseOrders)
          _RecordTile(
            title: item.id,
            subtitle: item.vendor,
            amount: item.amount,
            status: item.status,
          ),
      ]);

  Widget _paymentList() => _records('Payments and history', [
        for (final item in _mockRepo.payments)
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

  Widget _detailRow(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: AppColors.muted),
            const SizedBox(width: 8),
            Text('$label: ', style: const TextStyle(fontSize: 13, color: AppColors.muted)),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );

  static IconData _categoryIcon(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('canteen') || lower.contains('food') || lower.contains('mess') || lower.contains('dining')) {
      return Icons.restaurant_outlined;
    }
    if (lower.contains('stationery') || lower.contains('book')) {
      return Icons.menu_book_outlined;
    }
    if (lower.contains('laundry')) {
      return Icons.local_laundry_service_outlined;
    }
    if (lower.contains('tech') || lower.contains('it')) {
      return Icons.computer_outlined;
    }
    return Icons.storefront_outlined;
  }
}

class _VendorShopCard extends StatelessWidget {
  const _VendorShopCard({
    required this.shop,
    required this.isToggling,
    required this.onTap,
    required this.onEdit,
    required this.onToggleActive,
  });

  final VendorShop shop;
  final bool isToggling;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final ValueChanged<bool> onToggleActive;

  @override
  Widget build(BuildContext context) {
    final color = shop.isActive ? AppColors.success : Colors.grey;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: const Color(0xFF8A4B20).withValues(alpha: 0.1),
                    child: Icon(
                      _VendorManagementShellState._categoryIcon(shop.category),
                      color: const Color(0xFF8A4B20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          shop.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${shop.category} • ${shop.shopKey}',
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Vendor actions',
                    onSelected: (val) {
                      if (val == 'details') onTap();
                      if (val == 'edit') onEdit();
                      if (val == 'toggle') onToggleActive(!shop.isActive);
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'details',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.info_outline),
                          title: Text('View details'),
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.edit_outlined),
                          title: Text('Edit vendor'),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'toggle',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            shop.isActive ? Icons.block_outlined : Icons.check_circle_outline,
                          ),
                          title: Text(shop.isActive ? 'Disable vendor' : 'Enable vendor'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (shop.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  shop.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      shop.isActive ? 'Active' : 'Disabled',
                      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const Spacer(),
                  const Text('Active status: ', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                  if (isToggling)
                    const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Switch(
                      value: shop.isActive,
                      activeThumbColor: const Color(0xFF8A4B20),
                      onChanged: onToggleActive,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddVendorShopSheet extends StatefulWidget {
  const _AddVendorShopSheet({required this.suggestedCategories});
  final List<String> suggestedCategories;

  @override
  State<_AddVendorShopSheet> createState() => _AddVendorShopSheetState();
}

class _AddVendorShopSheetState extends State<_AddVendorShopSheet> {
  final _name = TextEditingController();
  final _shopKey = TextEditingController();
  final _category = TextEditingController();
  final _description = TextEditingController();
  bool _qrPayments = true;
  final bool _mealCompliance = false;
  bool _autoKey = true;

  @override
  void initState() {
    super.initState();
    _category.text = widget.suggestedCategories.isNotEmpty
        ? widget.suggestedCategories.first
        : 'Canteen';
  }

  @override
  void dispose() {
    _name.dispose();
    _shopKey.dispose();
    _category.dispose();
    _description.dispose();
    super.dispose();
  }

  void _onNameChanged(String val) {
    if (_autoKey) {
      final key = val.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9_-]'), '-');
      _shopKey.text = key;
    }
  }

  void _submit() {
    if (_name.text.trim().isEmpty || _shopKey.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter vendor name and unique shop key.')),
      );
      return;
    }
    Navigator.of(context).pop(
      VendorShopDraft(
        name: _name.text.trim(),
        shopKey: _shopKey.text.trim().toLowerCase(),
        category: _category.text.trim().isNotEmpty ? _category.text.trim() : 'General',
        description: _description.text.trim(),
        qrPayments: _qrPayments,
        mealCompliance: _mealCompliance,
        isActive: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            MediaQuery.viewInsetsOf(context).bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Add Campus Vendor / Shop',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _name,
                  onChanged: _onNameChanged,
                  decoration: const InputDecoration(
                    labelText: 'Vendor / Shop Name',
                    hintText: 'e.g. FastTrack Laundry Services',
                    prefixIcon: Icon(Icons.storefront_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _shopKey,
                  onChanged: (_) => _autoKey = false,
                  decoration: const InputDecoration(
                    labelText: 'Shop Key (Unique Identifier)',
                    hintText: 'e.g. fasttrack-laundry',
                    prefixIcon: Icon(Icons.vpn_key_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _category,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    hintText: 'e.g. Canteen, Stationery, Laundry',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                ),
                if (widget.suggestedCategories.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final cat in widget.suggestedCategories)
                        ActionChip(
                          label: Text(cat),
                          onPressed: () => setState(() => _category.text = cat),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: _description,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Description / Location / Notes',
                    hintText: 'Near East Gate, operating 9 AM to 8 PM',
                    prefixIcon: Icon(Icons.description_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Enable QR Code Payments'),
                  subtitle: const Text('Allows students and staff to pay via campus wallet QR'),
                  value: _qrPayments,
                  onChanged: (v) => setState(() => _qrPayments = v),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF8A4B20),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _submit,
                  child: const Text('Create Vendor Shop'),
                ),
              ],
            ),
          ),
        ),
      );
}

class _EditVendorShopSheet extends StatefulWidget {
  const _EditVendorShopSheet({
    required this.shop,
    required this.suggestedCategories,
  });

  final VendorShop shop;
  final List<String> suggestedCategories;

  @override
  State<_EditVendorShopSheet> createState() => _EditVendorShopSheetState();
}

class _EditVendorShopSheetState extends State<_EditVendorShopSheet> {
  late final TextEditingController _name;
  late final TextEditingController _category;
  late final TextEditingController _description;
  late bool _isActive;
  late bool _qrPayments;
  late bool _mealCompliance;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.shop.name);
    _category = TextEditingController(text: widget.shop.category);
    _description = TextEditingController(text: widget.shop.description);
    _isActive = widget.shop.isActive;
    _qrPayments = widget.shop.qrPayments;
    _mealCompliance = widget.shop.mealCompliance;
  }

  @override
  void dispose() {
    _name.dispose();
    _category.dispose();
    _description.dispose();
    super.dispose();
  }

  void _submit() {
    if (_name.text.trim().isEmpty) return;
    Navigator.of(context).pop(
      VendorShopDraft(
        name: _name.text.trim(),
        shopKey: widget.shop.shopKey,
        category: _category.text.trim().isNotEmpty ? _category.text.trim() : widget.shop.category,
        description: _description.text.trim(),
        isActive: _isActive,
        qrPayments: _qrPayments,
        mealCompliance: _mealCompliance,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            MediaQuery.viewInsetsOf(context).bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Edit ${widget.shop.name}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: 'Vendor Name',
                    prefixIcon: Icon(Icons.storefront_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _category,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _description,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    prefixIcon: Icon(Icons.description_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active status'),
                  subtitle: Text(_isActive ? 'Vendor is visible and taking requests' : 'Vendor is disabled'),
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF8A4B20),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _submit,
                  child: const Text('Save Changes'),
                ),
              ],
            ),
          ),
        ),
      );
}

class _Summary extends StatelessWidget {
  const _Summary({required this.count, required this.total});
  final int count;
  final int total;

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
            Text(
              'Active vendors: $count of $total',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            Text(
              '$count',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
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
