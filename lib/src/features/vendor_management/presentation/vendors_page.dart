part of 'vendor_management_shell.dart';

/// The tenant's shop register with each shop's live state and staff.
class _VendorsPage extends StatefulWidget {
  const _VendorsPage({
    required this.repository,
    required this.stores,
    required this.canCreate,
    required this.canUpdate,
    required this.onOpenOrders,
    required this.registerAddAction,
  });

  final VendorRepository repository;

  /// Live figures per shop from the dashboard, keyed by nothing: matched on
  /// shop key.
  final List<StoreSales> stores;
  final bool canCreate;
  final bool canUpdate;
  final ValueChanged<String> onOpenOrders;

  /// Hands the shell a callback for its "Add shop" button.
  final ValueChanged<VoidCallback> registerAddAction;

  @override
  State<_VendorsPage> createState() => _VendorsPageState();
}

class _VendorsPageState extends State<_VendorsPage> {
  List<VendorShop>? _shops;
  Object? _error;
  String _query = '';
  String? _category;
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    widget.registerAddAction(_addShop);
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final shops = await widget.repository.listVendors();
      if (mounted) setState(() => _shops = shops);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  StoreSales? _salesFor(VendorShop shop) {
    for (final store in widget.stores) {
      if (store.shopKey == shop.shopKey) return store;
    }
    return null;
  }

  List<String> get _categories {
    final seen = <String, String>{};
    for (final shop in _shops ?? const <VendorShop>[]) {
      final c = shop.category.trim();
      if (c.isNotEmpty) seen.putIfAbsent(c.toLowerCase(), () => _titleCase(c));
    }
    return seen.values.toList()..sort();
  }

  void _toast(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? context.palette.danger : null,
      ),
    );
  }

  Future<void> _addShop() async {
    final draft = await showModalBottomSheet<VendorShopDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ShopFormSheet(suggestedCategories: _categories),
    );
    if (draft == null || !mounted) return;
    try {
      final created = await widget.repository.createVendor(draft);
      if (!mounted) return;
      setState(() => _shops = [created, ...?_shops]);
      _toast('${created.name} added.');
    } catch (error) {
      if (mounted) _toast(userFacingError(error), error: true);
    }
  }

  Future<void> _editShop(VendorShop shop) async {
    final draft = await showModalBottomSheet<VendorShopDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) =>
          _ShopFormSheet(shop: shop, suggestedCategories: _categories),
    );
    if (draft == null || !mounted) return;
    try {
      final updated = await widget.repository.updateVendor(shop.id, draft);
      if (!mounted) return;
      _replace(shop.id, updated.copyWith(isOpen: shop.isOpen));
      _toast('${updated.name} saved.');
    } catch (error) {
      if (mounted) _toast(userFacingError(error), error: true);
    }
  }

  Future<void> _setActive(VendorShop shop, bool active) async {
    if (_busy.contains(shop.id)) return;
    setState(() => _busy.add(shop.id));
    try {
      await widget.repository.toggleVendorStatus(shop, active);
      if (!mounted) return;
      _replace(shop.id, shop.copyWith(isActive: active));
      _toast(active ? '${shop.name} enabled.' : '${shop.name} disabled.');
    } catch (error) {
      if (mounted) _toast(userFacingError(error), error: true);
    } finally {
      if (mounted) setState(() => _busy.remove(shop.id));
    }
  }

  void _replace(String id, VendorShop shop) => setState(() {
    _shops = [
      for (final s in _shops ?? const <VendorShop>[]) s.id == id ? shop : s,
    ];
  });

  void _showShop(VendorShop shop) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheet) => _ShopDetailSheet(
        shop: shop,
        sales: _salesFor(shop),
        canUpdate: widget.canUpdate,
        onEdit: () {
          Navigator.pop(sheet);
          _editShop(shop);
        },
        onToggle: () {
          Navigator.pop(sheet);
          _setActive(shop, !shop.isActive);
        },
        onOrders: () {
          Navigator.pop(sheet);
          widget.onOpenOrders(shop.shopKey);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final shops = _shops;
    final error = _error;
    if (shops == null) {
      if (error != null) {
        return _loadFailure(
          error,
          _load,
          "You don't have access to the shop register.",
        );
      }
      return const Center(child: CircularProgressIndicator());
    }
    final query = _query.trim().toLowerCase();
    final visible = shops.where((shop) {
      if (_category != null &&
          shop.category.trim().toLowerCase() != _category!.toLowerCase()) {
        return false;
      }
      return query.isEmpty ||
          '${shop.name} ${shop.category} ${shop.description} ${shop.shopKey}'
              .toLowerCase()
              .contains(query);
    }).toList();
    final trading = shops.where((s) => s.isActive && s.isOpen).length;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(
            shops.isEmpty
                ? 'No shops yet'
                : '${formatCount(shops.length)} shop${shops.length == 1 ? '' : 's'} · $trading open now',
            style: TextStyle(fontSize: 13, color: p.inkSecondary),
          ),
          const SizedBox(height: 10),
          if (shops.length > 4) ...[
            TextField(
              onChanged: (value) => setState(() => _query = value),
              decoration: const InputDecoration(
                hintText: 'Search shops',
                prefixIcon: Icon(Icons.search_rounded),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (_categories.length > 1) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('All'),
                    selected: _category == null,
                    onSelected: (_) => setState(() => _category = null),
                  ),
                  for (final category in _categories) ...[
                    const SizedBox(width: 6),
                    ChoiceChip(
                      label: Text(category),
                      selected:
                          _category?.toLowerCase() == category.toLowerCase(),
                      onSelected: (on) =>
                          setState(() => _category = on ? category : null),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (shops.isEmpty)
            _MessageState(
              icon: Icons.storefront_outlined,
              title: 'No shops yet',
              message: widget.canCreate
                  ? 'Add the canteen, stationery store or laundry to start taking orders.'
                  : 'Your administrator has not set up any campus shops.',
            )
          else if (visible.isEmpty)
            const _MessageState(
              icon: Icons.search_off_rounded,
              title: 'No matches',
              message: 'No shop matches this search.',
            )
          else
            _SectionCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Column(
                children: [
                  for (var i = 0; i < visible.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: p.divider),
                    _ShopRow(
                      shop: visible[i],
                      sales: _salesFor(visible[i]),
                      busy: _busy.contains(visible[i].id),
                      onTap: () => _showShop(visible[i]),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

String _titleCase(String raw) => raw
    .split(RegExp(r'[\s_-]+'))
    .where((w) => w.isNotEmpty)
    .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
    .join(' ');

String _staffLine(List<ShopOperator> operators) {
  if (operators.isEmpty) return 'No staff assigned';
  final owners = operators.where((o) => o.isOwner).map((o) => o.name).toList();
  final captains = operators.length - owners.length;
  final parts = [
    if (owners.isNotEmpty) owners.join(', '),
    if (captains > 0) '$captains captain${captains == 1 ? '' : 's'}',
  ];
  return parts.join(' · ');
}

class _ShopRow extends StatelessWidget {
  const _ShopRow({
    required this.shop,
    required this.sales,
    required this.busy,
    required this.onTap,
  });

  final VendorShop shop;
  final StoreSales? sales;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final sales = this.sales;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            _ShopAvatar(shop.category),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          shop.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: p.ink,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _tradingPill(
                        context,
                        active: shop.isActive,
                        open: shop.isOpen,
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${_titleCase(shop.category)} · ${_staffLine(sales?.operators ?? const [])}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, color: p.inkSecondary),
                  ),
                  if (sales != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Today: ${formatCount(sales.ordersToday)} order${sales.ordersToday == 1 ? '' : 's'} · '
                      '${formatRupees(sales.revenueToday)}'
                      '${sales.activeNow > 0 ? ' · ${sales.activeNow} in queue' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, color: p.inkTertiary),
                    ),
                  ],
                ],
              ),
            ),
            if (busy)
              const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(Icons.chevron_right_rounded, color: p.inkTertiary),
          ],
        ),
      ),
    );
  }
}

class _ShopDetailSheet extends StatelessWidget {
  const _ShopDetailSheet({
    required this.shop,
    required this.sales,
    required this.canUpdate,
    required this.onEdit,
    required this.onToggle,
    required this.onOrders,
  });

  final VendorShop shop;
  final StoreSales? sales;
  final bool canUpdate;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onOrders;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final sales = this.sales;
    final operators = sales?.operators ?? const <ShopOperator>[];
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SheetHandle(),
          const SizedBox(height: 16),
          Row(
            children: [
              _ShopAvatar(shop.category, size: 48),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shop.name,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                        color: p.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _titleCase(shop.category),
                      style: TextStyle(fontSize: 13.5, color: p.inkSecondary),
                    ),
                  ],
                ),
              ),
              _tradingPill(context, active: shop.isActive, open: shop.isOpen),
            ],
          ),
          if (shop.description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              shop.description,
              style: TextStyle(fontSize: 14, color: p.inkSecondary),
            ),
          ],
          if (sales != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _MiniStat(
                    label: 'Orders today',
                    value: formatCount(sales.ordersToday),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MiniStat(
                    label: 'Revenue today',
                    value: formatRupees(sales.revenueToday),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MiniStat(
                    label: 'In queue',
                    value: formatCount(sales.activeNow),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Text(
            'Staff',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: p.ink,
            ),
          ),
          const SizedBox(height: 4),
          if (operators.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                'No owner or captains assigned.',
                style: TextStyle(fontSize: 13.5, color: p.inkSecondary),
              ),
            )
          else
            for (final operator in operators)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(
                      operator.isOwner
                          ? Icons.person_rounded
                          : Icons.person_outline_rounded,
                      size: 18,
                      color: p.inkSecondary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        operator.name,
                        style: TextStyle(fontSize: 14, color: p.ink),
                      ),
                    ),
                    Text(
                      operator.isOwner ? 'Owner' : 'Captain',
                      style: TextStyle(fontSize: 12.5, color: p.inkSecondary),
                    ),
                  ],
                ),
              ),
          const SizedBox(height: 8),
          _DetailRow('Shop key', shop.shopKey),
          _DetailRow('Wallet QR', shop.qrPayments ? 'Accepted' : 'Off'),
          if (shop.mealCompliance) const _DetailRow('Meal plan', 'Counts toward hostel meals'),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onOrders,
            icon: const Icon(Icons.receipt_long_rounded),
            label: const Text('View orders'),
          ),
          if (canUpdate) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onToggle,
                    child: Text(shop.isActive ? 'Disable shop' : 'Enable shop'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: onEdit,
                    child: const Text('Edit details'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: p.surfaceSunken,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: p.ink,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11.5, color: p.inkSecondary),
          ),
        ],
      ),
    );
  }
}

/// Add a shop, or edit one when [shop] is given.
class _ShopFormSheet extends StatefulWidget {
  const _ShopFormSheet({required this.suggestedCategories, this.shop});

  final VendorShop? shop;
  final List<String> suggestedCategories;

  @override
  State<_ShopFormSheet> createState() => _ShopFormSheetState();
}

class _ShopFormSheetState extends State<_ShopFormSheet> {
  late final _name = TextEditingController(text: widget.shop?.name);
  late final _key = TextEditingController(text: widget.shop?.shopKey);
  late final _category = TextEditingController(
    text: widget.shop?.category ??
        (widget.suggestedCategories.isNotEmpty
            ? widget.suggestedCategories.first
            : 'Canteen'),
  );
  late final _description = TextEditingController(
    text: widget.shop?.description,
  );
  late bool _qrPayments = widget.shop?.qrPayments ?? true;
  late bool _isActive = widget.shop?.isActive ?? true;
  bool _autoKey = true;
  String? _problem;

  bool get _editing => widget.shop != null;

  @override
  void dispose() {
    _name.dispose();
    _key.dispose();
    _category.dispose();
    _description.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    final key = _key.text.trim().toLowerCase();
    if (name.isEmpty) {
      setState(() => _problem = 'Enter a shop name.');
      return;
    }
    if (!RegExp(r'^[a-z0-9][a-z0-9_-]{1,63}$').hasMatch(key)) {
      setState(
        () => _problem =
            'The shop key needs 2–64 lowercase letters, digits, - or _.',
      );
      return;
    }
    Navigator.of(context).pop(
      VendorShopDraft(
        name: name,
        shopKey: key,
        category: _category.text.trim().isEmpty
            ? 'General'
            : _category.text.trim(),
        description: _description.text.trim(),
        isActive: _isActive,
        qrPayments: _qrPayments,
        mealCompliance: widget.shop?.mealCompliance ?? false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        10,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SheetHandle(),
            const SizedBox(height: 14),
            Text(
              _editing ? 'Edit ${widget.shop!.name}' : 'Add shop',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
                color: p.ink,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              onChanged: (value) {
                if (_editing || !_autoKey) return;
                _key.text = value
                    .trim()
                    .toLowerCase()
                    .replaceAll(RegExp(r'[^a-z0-9_-]+'), '-')
                    .replaceAll(RegExp(r'^-+|-+$'), '');
              },
              decoration: const InputDecoration(labelText: 'Shop name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _key,
              enabled: !_editing,
              onChanged: (_) => _autoKey = false,
              decoration: const InputDecoration(
                labelText: 'Shop key',
                helperText: 'Used in QR codes and reports. Cannot change later.',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _category,
              decoration: const InputDecoration(labelText: 'Category'),
            ),
            if (widget.suggestedCategories.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final category in widget.suggestedCategories)
                    ActionChip(
                      label: Text(category),
                      onPressed: () => setState(() => _category.text = category),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _description,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'Location, hours or notes',
              ),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Accept wallet QR payments'),
              value: _qrPayments,
              onChanged: (v) => setState(() => _qrPayments = v),
            ),
            if (_editing)
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Shop enabled'),
                subtitle: const Text('Disabled shops are hidden from students'),
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
              ),
            if (_problem != null) ...[
              const SizedBox(height: 4),
              Text(_problem!, style: TextStyle(color: p.danger, fontSize: 13)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submit,
              child: Text(_editing ? 'Save changes' : 'Add shop'),
            ),
          ],
        ),
      ),
    );
  }
}
