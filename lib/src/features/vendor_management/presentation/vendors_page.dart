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

  /// The sequence being arranged, while the administrator reorders shops.
  List<VendorShop>? _arranging;
  var _savingOrder = false;

  /// Shop order and counter staff, where the repository offers them.
  ShopAdministration? get _administration => switch (widget.repository) {
    final ShopAdministration administration => administration,
    _ => null,
  };

  bool get _canArrange =>
      widget.canUpdate &&
      _administration != null &&
      (_shops?.length ?? 0) > 1;

  void _startArranging() => setState(() => _arranging = [...?_shops]);

  void _moveShop(int from, int to) {
    final list = _arranging;
    if (list == null || from == to) return;
    setState(() {
      final shop = list.removeAt(from);
      list.insert(to, shop);
    });
  }

  Future<void> _saveOrder() async {
    final list = _arranging;
    final administration = _administration;
    if (list == null || administration == null || _savingOrder) return;
    setState(() => _savingOrder = true);
    try {
      final saved = await administration.reorderVendors([
        for (final shop in list) shop.shopKey,
      ]);
      if (!mounted) return;
      setState(() {
        _shops = saved.isEmpty ? list : saved;
        _arranging = null;
      });
      _toast('Shop order saved. Every shop list now follows it.');
    } catch (error) {
      if (mounted) _toast(userFacingError(error), error: true);
    } finally {
      if (mounted) setState(() => _savingOrder = false);
    }
  }

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
      builder: (_) => _ShopFormSheet(
        suggestedCategories: _categories,
        loadStaffCandidates: _staffLoader,
      ),
    );
    if (draft == null || !mounted) return;
    try {
      final created = await widget.repository.createVendor(draft);
      if (!mounted) return;
      // A new shop joins the end of the administrator's sequence.
      setState(() => _shops = [...?_shops, created]);
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
      builder: (_) => _ShopFormSheet(
        shop: shop,
        suggestedCategories: _categories,
        loadStaffCandidates: _staffLoader,
      ),
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

  /// Counter staff are chosen in the shop editor where the viewer may
  /// configure shops and the repository can list candidates.
  Future<List<ShopStaffCandidate>> Function()? get _staffLoader {
    final administration = _administration;
    if (!widget.canUpdate || administration == null) return null;
    return administration.listShopStaffCandidates;
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
    final arranging = _arranging;
    if (arranging != null) {
      return _ArrangeShops(
        shops: arranging,
        saving: _savingOrder,
        onMove: _moveShop,
        onCancel: () => setState(() => _arranging = null),
        onSave: _saveOrder,
      );
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
          Row(
            children: [
              Expanded(
                child: Text(
                  shops.isEmpty
                      ? 'No shops yet'
                      : '${formatCount(shops.length)} shop${shops.length == 1 ? '' : 's'} · $trading open now',
                  style: TextStyle(fontSize: 13, color: p.inkSecondary),
                ),
              ),
              if (_canArrange)
                TextButton.icon(
                  onPressed: _startArranging,
                  icon: const Icon(Icons.swap_vert_rounded, size: 18),
                  label: const Text('Arrange'),
                ),
            ],
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

/// The administrator's shop sequence: drag a shop by its handle, then save.
/// Students' shop tabs, wallets, sales and reports all follow this order.
class _ArrangeShops extends StatelessWidget {
  const _ArrangeShops({
    required this.shops,
    required this.saving,
    required this.onMove,
    required this.onCancel,
    required this.onSave,
  });

  final List<VendorShop> shops;
  final bool saving;
  final void Function(int from, int to) onMove;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              TextButton(
                onPressed: saving ? null : onCancel,
                child: const Text('Cancel'),
              ),
              Expanded(
                child: Text(
                  'Arrange shops',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: p.ink,
                  ),
                ),
              ),
              FilledButton(
                onPressed: saving ? null : onSave,
                child: saving
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text(
            'Drag shops into the order students, wallets, sales and reports should show them.',
            style: TextStyle(fontSize: 13, color: p.inkSecondary),
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            buildDefaultDragHandles: false,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            itemCount: shops.length,
            onReorderItem: onMove,
            itemBuilder: (context, index) {
              final shop = shops[index];
              return Material(
                key: ValueKey('arrange_${shop.id}'),
                color: Colors.transparent,
                child: Column(
                  children: [
                    if (index > 0) Divider(height: 1, color: p.divider),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 24,
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                fontSize: 13,
                                color: p.inkTertiary,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ),
                          _ShopAvatar(shop.category),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  shop.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: p.ink,
                                  ),
                                ),
                                Text(
                                  shop.isActive
                                      ? _titleCase(shop.category)
                                      : '${_titleCase(shop.category)} · Disabled',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: p.inkSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ReorderableDragStartListener(
                            index: index,
                            child: Semantics(
                              label: 'Drag to move ${shop.name}',
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: Icon(
                                  Icons.drag_handle_rounded,
                                  color: p.inkTertiary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Who works one shop's counter, edited inside the shop form. Captains run
/// the order queue; owners also run the menu.
class _ShopStaffEditor extends StatelessWidget {
  const _ShopStaffEditor({
    required this.staff,
    required this.candidates,
    required this.onChanged,
  });

  final List<ShopStaffAssignment> staff;

  /// Null while loading.
  final List<ShopStaffCandidate>? candidates;
  final ValueChanged<List<ShopStaffAssignment>> onChanged;

  String _nameOf(ShopStaffAssignment assignment) {
    for (final candidate in candidates ?? const <ShopStaffCandidate>[]) {
      if (candidate.userId == assignment.userId) return candidate.name;
    }
    return assignment.name ?? 'Staff member';
  }

  Future<void> _add(BuildContext context) async {
    final taken = {for (final s in staff) s.userId};
    final options = [
      for (final c in candidates ?? const <ShopStaffCandidate>[])
        if (!taken.contains(c.userId)) c,
    ];
    final picked = await showModalBottomSheet<ShopStaffCandidate>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _StaffPickerSheet(candidates: options),
    );
    if (picked == null) return;
    onChanged([
      ...staff,
      ShopStaffAssignment(
        userId: picked.userId,
        role: picked.suggestedRole,
        name: picked.name,
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Counter staff',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: p.ink,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Captains run the order queue. Owners also manage the menu. '
          'Staff see orders only for the shops listed here.',
          style: TextStyle(fontSize: 12.5, color: p.inkSecondary),
        ),
        const SizedBox(height: 6),
        if (staff.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No one is assigned to this counter yet.',
              style: TextStyle(fontSize: 13.5, color: p.inkSecondary),
            ),
          ),
        for (final assignment in staff)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _nameOf(assignment),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, color: p.ink),
                  ),
                ),
                _RoleToggle(
                  role: assignment.role,
                  onChanged: (role) => onChanged([
                    for (final s in staff)
                      s.userId == assignment.userId ? s.withRole(role) : s,
                  ]),
                ),
                IconButton(
                  tooltip: 'Remove ${_nameOf(assignment)}',
                  icon: Icon(Icons.remove_circle_outline, color: p.danger),
                  onPressed: () => onChanged([
                    for (final s in staff)
                      if (s.userId != assignment.userId) s,
                  ]),
                ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: candidates == null ? null : () => _add(context),
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
            label: Text(candidates == null ? 'Loading staff…' : 'Add staff'),
          ),
        ),
      ],
    );
  }
}

class _RoleToggle extends StatelessWidget {
  const _RoleToggle({required this.role, required this.onChanged});

  final String role;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<String>(
      showSelectedIcon: false,
      style: const ButtonStyle(visualDensity: VisualDensity.compact),
      segments: const [
        ButtonSegment(value: 'captain', label: Text('Captain')),
        ButtonSegment(value: 'owner', label: Text('Owner')),
      ],
      selected: {role},
      onSelectionChanged: (value) => onChanged(value.first),
    );
  }
}

/// Picks one person for a counter from the accounts whose roles grant shop
/// work.
class _StaffPickerSheet extends StatefulWidget {
  const _StaffPickerSheet({required this.candidates});

  final List<ShopStaffCandidate> candidates;

  @override
  State<_StaffPickerSheet> createState() => _StaffPickerSheetState();
}

class _StaffPickerSheetState extends State<_StaffPickerSheet> {
  var _query = '';

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final q = _query.trim().toLowerCase();
    final visible = [
      for (final c in widget.candidates)
        if (q.isEmpty || '${c.name} ${c.email}'.toLowerCase().contains(q)) c,
    ];
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        10,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SheetHandle(),
          const SizedBox(height: 14),
          Text(
            'Add staff',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
              color: p.ink,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            onChanged: (value) => setState(() => _query = value),
            decoration: const InputDecoration(
              hintText: 'Search by name or email',
              prefixIcon: Icon(Icons.search_rounded),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          if (widget.candidates.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'No one else has a shop captain or owner role. Give someone '
                'that role in Users first.',
                style: TextStyle(fontSize: 13.5, color: p.inkSecondary),
              ),
            )
          else
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final c in visible)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(c.name),
                      subtitle: Text(c.email),
                      trailing: Text(
                        c.suggestedRole == 'owner' ? 'Owner' : 'Captain',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: p.inkSecondary,
                        ),
                      ),
                      onTap: () => Navigator.of(context).pop(c),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Add a shop, or edit one when [shop] is given.
class _ShopFormSheet extends StatefulWidget {
  const _ShopFormSheet({
    required this.suggestedCategories,
    this.shop,
    this.loadStaffCandidates,
  });

  final VendorShop? shop;
  final List<String> suggestedCategories;

  /// Present when the viewer may choose counter staff here.
  final Future<List<ShopStaffCandidate>> Function()? loadStaffCandidates;

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
  late List<ShopStaffAssignment> _staff = [...?widget.shop?.operators];
  var _staffChanged = false;
  List<ShopStaffCandidate>? _candidates;

  bool get _editing => widget.shop != null;

  @override
  void initState() {
    super.initState();
    final load = widget.loadStaffCandidates;
    if (load != null) {
      load().then(
        (value) {
          if (mounted) setState(() => _candidates = value);
        },
        onError: (_) {
          if (mounted) setState(() => _candidates = const []);
        },
      );
    }
  }

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
        // Only a changed list is sent; otherwise the staff stay as they are.
        operators: _staffChanged ? _staff : null,
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
            if (widget.loadStaffCandidates != null) ...[
              const SizedBox(height: 12),
              _ShopStaffEditor(
                staff: _staff,
                candidates: _candidates,
                onChanged: (value) => setState(() {
                  _staff = value;
                  _staffChanged = true;
                }),
              ),
            ],
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
