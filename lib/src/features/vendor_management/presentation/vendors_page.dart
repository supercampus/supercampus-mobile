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

  /// Moving a canteen's own items into its categories, where offered.
  CategoryMenuAdministration? get _menuAdministration =>
      switch (widget.repository) {
        final CategoryMenuAdministration administration => administration,
        _ => null,
      };

  bool _isSplit(VendorShop shop) =>
      isSplitIntoCategories(shop, _shops ?? const <VendorShop>[]);

  bool get _canArrange =>
      widget.canUpdate && _administration != null && (_shops?.length ?? 0) > 1;

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

  /// The canteen [shop] is a counter of, when it is one and is listed.
  VendorShop? _parentOf(VendorShop shop) {
    if (!shop.isCounter) return null;
    for (final candidate in _shops ?? const <VendorShop>[]) {
      if (candidate.shopKey == shop.parentShopKey) return candidate;
    }
    return null;
  }

  /// [canteen]'s categories, in the administrator's order.
  List<VendorShop> _countersOf(VendorShop canteen) => [
    for (final shop in _shops ?? const <VendorShop>[])
      if (shop.parentShopKey == canteen.shopKey) shop,
  ];

  /// Adds a category (Bites, Mess …) under [canteen]: a shop of its own for
  /// staff, menu and orders that students find in the canteen. The first
  /// category retires the canteen's own staff; the server says who.
  Future<void> _addCounter(VendorShop canteen) async {
    final draft = await showModalBottomSheet<VendorShopDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ShopFormSheet(
        parent: canteen,
        suggestedCategories: _categories,
        loadStaffCandidates: _staffLoader,
        nextPosition: _countersOf(canteen).length + 1,
      ),
    );
    if (draft == null || !mounted) return;
    try {
      final created = await widget.repository.createVendor(draft);
      if (!mounted) return;
      setState(() => _shops = [...?_shops, created]);
      final removed = created.parentStaffRemoved.length;
      _toast(
        removed == 0
            ? '${created.name} added to ${canteen.name}.'
            : '${created.name} added to ${canteen.name}. '
                  '$removed staff no longer work ${canteen.name} itself — '
                  'assign them to its categories.',
      );
      // The canteen's staff and flags changed on the server.
      _load();
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
        parent: _parentOf(shop),
        suggestedCategories: _categories,
        loadStaffCandidates: _staffLoader,
        splitIntoCategories: _isSplit(shop),
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

  /// Opens the tool that moves [canteen]'s own items into its categories,
  /// then refreshes the register's "not in a category" count.
  Future<void> _moveItems(VendorShop canteen) async {
    final administration = _menuAdministration;
    if (administration == null) return;
    final moved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => MoveItemsToCategoriesSheet(
        canteen: canteen,
        categories: [
          for (final category in _countersOf(canteen))
            if (category.isActive) category,
        ],
        administration: administration,
      ),
    );
    // A drag-to-dismiss returns null even after a move, so refresh anyway.
    if (mounted && moved != false) await _load();
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
        canCreate: widget.canCreate,
        parent: _parentOf(shop),
        counters: _countersOf(shop),
        splitIntoCategories: _isSplit(shop),
        salesFor: _salesFor,
        onAddCounter: () {
          Navigator.pop(sheet);
          _addCounter(shop);
        },
        onMoveItems:
            widget.canUpdate && _menuAdministration != null && _isSplit(shop)
            ? () {
                Navigator.pop(sheet);
                _moveItems(shop);
              }
            : null,
        onOpenCounter: (counter) {
          Navigator.pop(sheet);
          _showShop(counter);
        },
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
    // Counters sit right under their canteen.
    final visible = nestCounters(shops).where((shop) {
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
                      parent: _parentOf(visible[i]),
                      categoryCount: _isSplit(visible[i])
                          ? _countersOf(
                              visible[i],
                            ).where((c) => c.isActive).length
                          : null,
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
    this.parent,
    this.categoryCount,
  });

  final VendorShop shop;

  /// The canteen this row is a category of; the row is then indented under it.
  final VendorShop? parent;

  /// How many categories [shop] is split into; null when it is not split.
  /// A split canteen has no staff of its own to list.
  final int? categoryCount;
  final StoreSales? sales;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final sales = this.sales;
    final parent = this.parent;
    return InkWell(
      key: ValueKey('vendor-shop-${shop.shopKey}'),
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.only(
          top: 12,
          bottom: 12,
          left: parent == null ? 0 : 28,
        ),
        child: Row(
          children: [
            _ShopAvatar(shop.category, size: parent == null ? 40 : 32),
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
                    '${parent == null ? _titleCase(shop.category) : 'Category of ${parent.name}'} · '
                    '${categoryCount != null ? '$categoryCount categor${categoryCount == 1 ? 'y' : 'ies'}' : _staffLine(sales?.operators ?? const [])}',
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
    this.canCreate = false,
    this.parent,
    this.counters = const [],
    this.salesFor,
    this.onAddCounter,
    this.onOpenCounter,
    this.splitIntoCategories = false,
    this.onMoveItems,
  });

  final VendorShop shop;
  final StoreSales? sales;
  final bool canUpdate;
  final bool canCreate;

  /// The canteen [shop] is a category of, when it is one.
  final VendorShop? parent;

  /// [shop]'s categories, when it is a canteen that has them.
  final List<VendorShop> counters;
  final StoreSales? Function(VendorShop shop)? salesFor;
  final VoidCallback? onAddCounter;
  final ValueChanged<VendorShop>? onOpenCounter;

  /// [shop] is a canteen with active categories: owners and captains belong
  /// to the categories, never to the canteen itself.
  final bool splitIntoCategories;

  /// Opens the tool that moves the canteen's own items into its categories.
  final VoidCallback? onMoveItems;

  /// A canteen can be split into categories; a category cannot.
  bool get _takesCounters =>
      !shop.isCounter &&
      shop.isActive &&
      shop.category.trim().toLowerCase() == 'canteen';
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
          if (splitIntoCategories && shop.uncategorizedItemCount > 0) ...[
            const SizedBox(height: 16),
            Container(
              key: const ValueKey('uncategorized-items-banner'),
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
              decoration: BoxDecoration(
                color: p.warningSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 20, color: p.warning),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${shop.uncategorizedItemCount} '
                      '${shop.uncategorizedItemCount == 1 ? "item isn't" : "items aren't"} '
                      'in a category yet. Students can’t order '
                      '${shop.uncategorizedItemCount == 1 ? 'it' : 'them'} until moved.',
                      style: TextStyle(fontSize: 13, color: p.ink),
                    ),
                  ),
                ],
              ),
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
          if (splitIntoCategories)
            Padding(
              key: const ValueKey('staff-per-category'),
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                'Staff are assigned per category. ${shop.name} has no '
                'owner or captain of its own.',
                style: TextStyle(fontSize: 13.5, color: p.inkSecondary),
              ),
            )
          else if (operators.isEmpty)
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
          if (_takesCounters && (counters.isNotEmpty || canCreate)) ...[
            const SizedBox(height: 12),
            Text(
              'Categories',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: p.ink,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Each category has its own owner, captains, menu and order '
              'queue. Students see them inside ${shop.name} as All and each '
              'category, and its wallet pays in every category.',
              style: TextStyle(fontSize: 12.5, color: p.inkSecondary),
            ),
            for (final counter in counters)
              InkWell(
                key: ValueKey('counter-row-${counter.shopKey}'),
                onTap: onOpenCounter == null
                    ? null
                    : () => onOpenCounter!(counter),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              counter.name,
                              style: TextStyle(fontSize: 14, color: p.ink),
                            ),
                            Text(
                              _staffLine(
                                salesFor?.call(counter)?.operators ?? const [],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: p.inkSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _tradingPill(
                        context,
                        active: counter.isActive,
                        open: counter.isOpen,
                      ),
                      Icon(Icons.chevron_right_rounded, color: p.inkTertiary),
                    ],
                  ),
                ),
              ),
            if (canCreate && onAddCounter != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const ValueKey('add-counter'),
                  onPressed: onAddCounter,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add category'),
                ),
              ),
            if (onMoveItems != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const ValueKey('move-items'),
                  onPressed: onMoveItems,
                  icon: const Icon(Icons.drive_file_move_outline, size: 18),
                  label: const Text('Move items to categories'),
                ),
              ),
          ],
          const SizedBox(height: 8),
          if (parent != null) _DetailRow('Category of', parent!.name),
          _DetailRow('Shop key', shop.shopKey),
          _DetailRow('Wallet QR', shop.qrPayments ? 'Accepted' : 'Off'),
          if (shop.mealCompliance)
            const _DetailRow('Meal plan', 'Counts toward hostel meals'),
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
                        style: TextStyle(fontSize: 12.5, color: p.inkSecondary),
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
    this.parent,
    this.nextPosition,
    this.splitIntoCategories = false,
  });

  final VendorShop? shop;

  /// The canteen the shop is (or becomes) a category of. A category takes
  /// its canteen's shop type, so the form asks for a position instead.
  final VendorShop? parent;

  /// Where a new category goes among its canteen's categories.
  final int? nextPosition;

  /// The shop is a canteen with categories: it takes no staff of its own.
  final bool splitIntoCategories;
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
    text:
        widget.shop?.category ??
        (widget.suggestedCategories.isNotEmpty
            ? widget.suggestedCategories.first
            : 'Canteen'),
  );
  late final _description = TextEditingController(
    text: widget.shop?.description,
  );
  late final _position = TextEditingController(
    text: widget.parent == null
        ? ''
        : '${widget.shop == null ? (widget.nextPosition ?? 1) : (widget.shop!.sortOrder ?? '')}',
  );
  late bool _qrPayments = widget.shop?.qrPayments ?? true;
  late bool _isActive = widget.shop?.isActive ?? true;
  bool _autoKey = true;
  String? _problem;
  late List<ShopStaffAssignment> _staff = [...?widget.shop?.operators];
  var _staffChanged = false;
  List<ShopStaffCandidate>? _candidates;

  bool get _editing => widget.shop != null;

  bool get _counter => widget.parent != null;

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
    _position.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    final key = _key.text.trim().toLowerCase();
    if (name.isEmpty) {
      setState(
        () => _problem = _counter
            ? 'Enter a category name.'
            : 'Enter a shop name.',
      );
      return;
    }
    final position = _position.text.trim();
    if (_counter && position.isNotEmpty && int.tryParse(position) == null) {
      setState(() => _problem = 'The position is a whole number, like 1 or 2.');
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
        category: _counter
            ? widget.parent!.category
            : _category.text.trim().isEmpty
            ? 'General'
            : _category.text.trim(),
        description: _description.text.trim(),
        isActive: _isActive,
        qrPayments: _qrPayments,
        mealCompliance: widget.shop?.mealCompliance ?? false,
        // Only a changed list is sent; otherwise the staff stay as they are.
        operators: _staffChanged && !widget.splitIntoCategories ? _staff : null,
        // A new category names its canteen; an edit leaves it where it is.
        parentShopKey: _counter && !_editing ? widget.parent!.shopKey : null,
        sortOrder: _counter && position.isNotEmpty
            ? int.tryParse(position)
            : null,
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
              _editing
                  ? 'Edit ${widget.shop!.name}'
                  : _counter
                  ? 'Add category to ${widget.parent!.name}'
                  : 'Add shop',
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
                final slug = value
                    .trim()
                    .toLowerCase()
                    .replaceAll(RegExp(r'[^a-z0-9_-]+'), '-')
                    .replaceAll(RegExp(r'^-+|-+$'), '');
                // A category's key starts with its canteen's, so it reads as
                // part of it in QR codes and reports. Only a-z, 0-9 and -
                // survive, so "Let's eat!" keys as let-s-eat.
                _key.text = _counter && slug.isNotEmpty
                    ? '${widget.parent!.shopKey}-$slug'
                    : slug;
              },
              decoration: InputDecoration(
                labelText: _counter ? 'Category name' : 'Shop name',
                hintText: _counter ? 'Bites, Mess, Snacks …' : null,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _key,
              enabled: !_editing,
              onChanged: (_) => _autoKey = false,
              decoration: const InputDecoration(
                labelText: 'Shop key',
                helperText:
                    'Used in QR codes and reports. Cannot change later.',
              ),
            ),
            if (_counter) ...[
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('counter-position'),
                controller: _position,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Position in ${widget.parent!.name} (optional)',
                  helperText: 'Students see categories in this order.',
                ),
              ),
            ],
            if (!_counter) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _category,
                decoration: const InputDecoration(labelText: 'Category'),
              ),
            ],
            if (!_counter && widget.suggestedCategories.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final category in widget.suggestedCategories)
                    ActionChip(
                      label: Text(category),
                      onPressed: () =>
                          setState(() => _category.text = category),
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
            if (widget.splitIntoCategories) ...[
              const SizedBox(height: 12),
              Text(
                'Staff are assigned per category',
                key: const ValueKey('form-staff-per-category'),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: p.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${widget.shop?.name ?? 'This canteen'} has no owner or '
                'captain of its own. Open a category to choose its staff.',
                style: TextStyle(fontSize: 12.5, color: p.inkSecondary),
              ),
            ] else if (widget.loadStaffCandidates != null) ...[
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
              key: const ValueKey('shop-form-submit'),
              onPressed: _submit,
              child: Text(
                _editing
                    ? 'Save changes'
                    : _counter
                    ? 'Add category'
                    : 'Add shop',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Moves the items a canteen still holds itself into its categories. Once a
/// canteen is split into categories its own items have no staff to make them,
/// so students cannot order them until they are moved.
///
/// Pick items (or all of them), pick the category, move. The sheet stays open
/// with whatever is left, and resolves to true when anything moved.
class MoveItemsToCategoriesSheet extends StatefulWidget {
  const MoveItemsToCategoriesSheet({
    super.key,
    required this.canteen,
    required this.categories,
    required this.administration,
  });

  final VendorShop canteen;

  /// The canteen's active categories, in the administrator's order.
  final List<VendorShop> categories;
  final CategoryMenuAdministration administration;

  @override
  State<MoveItemsToCategoriesSheet> createState() =>
      _MoveItemsToCategoriesSheetState();
}

class _MoveItemsToCategoriesSheetState
    extends State<MoveItemsToCategoriesSheet> {
  List<ShopMenuItemSummary>? _items;
  final Set<String> _selected = {};
  late String? _target = widget.categories.isEmpty
      ? null
      : widget.categories.first.shopKey;
  String? _error;
  String? _notice;
  var _moving = false;
  var _movedAny = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final items = await widget.administration.listShopItems(
        widget.canteen.shopKey,
      );
      if (!mounted) return;
      setState(() {
        _items = items;
        _selected.retainAll({for (final item in items) item.id});
      });
    } catch (error) {
      if (mounted) setState(() => _error = userFacingError(error));
    }
  }

  String _categoryName(String key) {
    for (final category in widget.categories) {
      if (category.shopKey == key) return category.name;
    }
    return key;
  }

  Future<void> _move() async {
    final target = _target;
    if (target == null || _selected.isEmpty || _moving) return;
    final count = _selected.length;
    setState(() {
      _moving = true;
      _error = null;
      _notice = null;
    });
    try {
      await widget.administration.moveItemsToCategory(
        parentShopKey: widget.canteen.shopKey,
        itemIds: _selected.toList(),
        targetShopKey: target,
      );
      if (!mounted) return;
      _movedAny = true;
      _selected.clear();
      _notice =
          'Moved $count item${count == 1 ? '' : 's'} to ${_categoryName(target)}.';
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = userFacingError(error));
    } finally {
      if (mounted) setState(() => _moving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final items = _items;
    final allSelected =
        items != null &&
        items.isNotEmpty &&
        items.every((item) => _selected.contains(item.id));
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SheetHandle(),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Move items to categories',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                    color: p.ink,
                  ),
                ),
              ),
              TextButton(
                key: const ValueKey('move-items-done'),
                onPressed: _moving
                    ? null
                    : () => Navigator.of(context).pop(_movedAny),
                child: const Text('Done'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'These items are still on ${widget.canteen.name} itself. Students '
            'can’t order them until they’re in a category.',
            style: TextStyle(fontSize: 13.5, color: p.inkSecondary),
          ),
          const SizedBox(height: 14),
          Text(
            'Move to',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: p.inkSecondary,
            ),
          ),
          const SizedBox(height: 8),
          if (widget.categories.isEmpty)
            Text(
              'Add a category to ${widget.canteen.name} first.',
              style: TextStyle(fontSize: 13.5, color: p.inkSecondary),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final category in widget.categories)
                  ChoiceChip(
                    key: ValueKey('move-target-${category.shopKey}'),
                    label: Text(category.name),
                    selected: _target == category.shopKey,
                    onSelected: _moving
                        ? null
                        : (_) => setState(() => _target = category.shopKey),
                  ),
              ],
            ),
          const SizedBox(height: 12),
          if (_notice != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _notice!,
                key: const ValueKey('move-items-notice'),
                style: TextStyle(fontSize: 13, color: p.success),
              ),
            ),
          if (items == null && _error == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (items != null && items.isEmpty)
            Padding(
              key: const ValueKey('move-items-empty'),
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Every item is in a category.',
                style: TextStyle(fontSize: 14, color: p.inkSecondary),
              ),
            )
          else if (items != null) ...[
            CheckboxListTile.adaptive(
              key: const ValueKey('move-items-select-all'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: allSelected,
              onChanged: _moving
                  ? null
                  : (on) => setState(() {
                      if (on ?? false) {
                        _selected.addAll(items.map((item) => item.id));
                      } else {
                        _selected.clear();
                      }
                    }),
              title: Text(
                'All ${items.length} item${items.length == 1 ? '' : 's'}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: p.ink,
                ),
              ),
            ),
            Divider(height: 1, color: p.divider),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final item in items)
                    CheckboxListTile.adaptive(
                      key: ValueKey('move-item-${item.id}'),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: _selected.contains(item.id),
                      onChanged: _moving
                          ? null
                          : (on) => setState(() {
                              if (on ?? false) {
                                _selected.add(item.id);
                              } else {
                                _selected.remove(item.id);
                              }
                            }),
                      title: Text(
                        item.name,
                        style: TextStyle(fontSize: 14.5, color: p.ink),
                      ),
                      subtitle: Text(
                        [
                          if (item.category.trim().isNotEmpty) item.category,
                          formatRupees(item.price),
                          if (!item.isAvailable) 'Hidden',
                        ].join(' · '),
                        style: TextStyle(fontSize: 12.5, color: p.inkSecondary),
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: p.danger, fontSize: 13)),
          ],
          const SizedBox(height: 14),
          FilledButton(
            key: const ValueKey('move-items-submit'),
            onPressed: _moving || _selected.isEmpty || _target == null
                ? null
                : _move,
            child: _moving
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    _selected.isEmpty || _target == null
                        ? 'Choose items to move'
                        : 'Move ${_selected.length} '
                              'item${_selected.length == 1 ? '' : 's'} to '
                              '${_categoryName(_target!)}',
                  ),
          ),
        ],
      ),
    );
  }
}
