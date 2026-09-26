import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/utils/image_picker_helper.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/module_navigation_buttons.dart';
import '../../../core/widgets/swipe_action_card.dart';
import '../data/canteen_models.dart';
import 'widgets/canteen_surface.dart';
import 'widgets/menu_item_art.dart';
import 'widgets/order_status_badge.dart';

/// A stationery-only workspace. It deliberately does not reuse the food
/// captain labels or screens: inventory is the primary job at this counter.
class StationeryOperatorHome extends StatefulWidget {
  const StationeryOperatorHome({
    super.key,
    required this.store,
    required this.onExitModule,
    required this.onSignOut,
    required this.onRefresh,
    required this.onCounterStateChanged,
    required this.onOrderStatusChanged,
    required this.onSaveItem,
    required this.onUploadMedia,
    this.onShopOpenChanged,
    this.initialAction,
    this.isMainHome = false,
    this.onProfileTap,
    this.displayName,
    this.email,
    this.photoUrl,
  });

  final CanteenStore store;
  final VoidCallback onExitModule;
  final VoidCallback onSignOut;
  final Future<void> Function() onRefresh;
  final Future<void> Function(CanteenStaffMode mode) onCounterStateChanged;
  final Future<void> Function(bool open)? onShopOpenChanged;
  final Future<void> Function(String orderId, CanteenOrderStatus status)
      onOrderStatusChanged;
  final Future<void> Function(CanteenMenuItem item, bool create) onSaveItem;
  final Future<String> Function(Uint8List bytes, String filename) onUploadMedia;
  final String? initialAction;
  final bool isMainHome;
  final VoidCallback? onProfileTap;
  final String? displayName;
  final String? email;
  final String? photoUrl;

  @override
  State<StationeryOperatorHome> createState() => _StationeryOperatorHomeState();
}

class _StationeryOperatorHomeState extends State<StationeryOperatorHome> {
  var _index = 1;
  var _busy = false;
  var _showHistory = false;
  var _query = '';
  String? _category;

  @override
  void initState() {
    super.initState();
    // Default to Orders (index 1) matching Image 1, unless initialAction explicitly requests inventory
    _index = widget.initialAction == 'inventory' ? 0 : 1;
    if (widget.initialAction == 'order_history') {
      _showHistory = true;
    }
  }

  String get _userInitials {
    final name = (widget.displayName ?? widget.store.user.name).trim();
    final parts = name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'ST';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  List<CanteenMenuItem> get _stationeryItems {
    final assigned = widget.store.assignedShopKeys.toSet();
    final items = widget.store.menu
        .where((item) {
          final belongsToStationery =
              item.store == MenuStore.stationery ||
              item.effectiveShopKey == 'stationery' ||
              assigned.contains(item.effectiveShopKey);
          if (!belongsToStationery) return false;
          if (_category != null && item.category != _category) return false;
          final query = _query.trim().toLowerCase();
          return query.isEmpty ||
              item.name.toLowerCase().contains(query) ||
              item.category.toLowerCase().contains(query);
        })
        .toList(growable: false);
    items.sort((a, b) {
      final category = a.category.compareTo(b.category);
      return category == 0 ? a.name.compareTo(b.name) : category;
    });
    return items;
  }

  List<String> get _categories {
    final categories =
        widget.store.menu
            .where(
              (item) =>
                  item.store == MenuStore.stationery ||
                  item.effectiveShopKey == 'stationery',
            )
            .map((item) => item.category)
            .where((category) => category.trim().isNotEmpty)
            .toSet()
            .toList(growable: false)
          ..sort();
    return categories;
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.store.orders
        .where((order) => order.status.isActive)
        .toList(growable: false);
    final history =
        widget.store.orders
            .where((order) => !order.status.isActive)
            .toList(growable: false)
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final shopOpen = widget.store.staffState.shopOpen ?? true;
    final counterOpen = widget.store.staffState.mode == CanteenStaffMode.work;

    return Scaffold(
      appBar: AppBar(
        leading: widget.isMainHome
            ? null
            : ModuleBackButton(onPressed: widget.onExitModule),
        automaticallyImplyLeading: !widget.isMainHome,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Stationery shop'),
            Text(
              shopOpen ? 'Shop open · Counter active' : 'Shop closed · Ordering paused',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: shopOpen ? const Color(0xFF087A53) : const Color(0xFFB42318),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            key: const ValueKey('stationery-top-profile-btn'),
            tooltip: 'Settings & Profile',
            onPressed: () => _openSettings(context),
            icon: CircleAvatar(
              radius: 17,
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              backgroundImage: (widget.photoUrl != null && widget.photoUrl!.isNotEmpty)
                  ? NetworkImage(widget.photoUrl!)
                  : null,
              child: (widget.photoUrl == null || widget.photoUrl!.isEmpty)
                  ? Text(
                      _userInitials,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: _index == 0
          ? FloatingActionButton.extended(
              key: const ValueKey('stationery-add-item-fab'),
              onPressed: _addNewItem,
              icon: const Icon(Icons.add),
              label: const Text('Add item'),
            )
          : null,
      body: Column(
        children: [
          if (_busy) const LinearProgressIndicator(minHeight: 2),
          _StationerySectionSwitcher(
            selectedIndex: _index,
            onSelected: (value) => setState(() => _index = value),
          ),
          Expanded(
            child: IndexedStack(
              index: _index,
              children: [
                _InventoryPage(
                  items: _stationeryItems,
                  totalItems: widget.store.menu
                      .where(
                        (item) =>
                            item.store == MenuStore.stationery ||
                            item.effectiveShopKey == 'stationery',
                      )
                      .length,
                  categories: _categories,
                  selectedCategory: _category,
                  query: _query,
                  onQueryChanged: (value) => setState(() => _query = value),
                  onCategoryChanged: (value) =>
                      setState(() => _category = value),
                  onRefresh: () => _run(widget.onRefresh),
                  onAdd: _addNewItem,
                  onEdit: _editItem,
                ),
                _OrdersPage(
                  orders: _showHistory ? history : active,
                  showHistory: _showHistory,
                  counterOpen: counterOpen,
                  busy: _busy,
                  onShowHistoryChanged: (value) =>
                      setState(() => _showHistory = value),
                  onRefresh: () => _run(widget.onRefresh),
                  onStatus: (id, status) =>
                      _run(() => widget.onOrderStatusChanged(id, status)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addNewItem() async {
    final newItem = await showModalBottomSheet<CanteenMenuItem>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (_) => _StationeryItemEditor(
        item: null,
        onUploadMedia: widget.onUploadMedia,
        existingCategories: _categories,
      ),
    );
    if (newItem == null || !mounted) return;
    await _run(() => widget.onSaveItem(newItem, true));
  }

  Future<void> _editItem(CanteenMenuItem item) async {
    final edited = await showModalBottomSheet<CanteenMenuItem>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (_) => _StationeryItemEditor(
        item: item,
        onUploadMedia: widget.onUploadMedia,
        existingCategories: _categories,
      ),
    );
    if (edited == null || !mounted) return;
    await _run(() => widget.onSaveItem(edited, false));
  }

  void _openSettings(BuildContext context) {
    final theme = Theme.of(context);
    final userInitials = _userInitials;
    final userName = widget.displayName ?? widget.store.user.name;
    final userEmail = widget.email ?? widget.store.user.email;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final shopOpen = widget.store.staffState.shopOpen ?? true;
            final mode = widget.store.staffState.mode;

            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.muted.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    // Operator Profile Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF1D4ED8).withValues(alpha: 0.25),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: Colors.white.withValues(alpha: 0.2),
                            foregroundColor: Colors.white,
                            backgroundImage: (widget.photoUrl != null &&
                                    widget.photoUrl!.isNotEmpty)
                                ? NetworkImage(widget.photoUrl!)
                                : null,
                            child: (widget.photoUrl == null ||
                                    widget.photoUrl!.isEmpty)
                                ? Text(
                                    userInitials,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  userName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  userEmail,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'Stationery Shop Operator',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Shop Open / Closed Setting
                    CanteenSurface(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: shopOpen
                                      ? const Color(0xFF087A53).withValues(alpha: 0.12)
                                      : const Color(0xFFB42318).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  shopOpen
                                      ? Icons.storefront_outlined
                                      : Icons.store_mall_directory_outlined,
                                  color: shopOpen
                                      ? const Color(0xFF087A53)
                                      : const Color(0xFFB42318),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Shop Status',
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      shopOpen
                                          ? 'Shop is OPEN · Accepting orders'
                                          : 'Shop is CLOSED · Ordering paused',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: shopOpen
                                            ? const Color(0xFF087A53)
                                            : const Color(0xFFB42318),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch.adaptive(
                                value: shopOpen,
                                onChanged: _busy
                                    ? null
                                    : (value) async {
                                        setSheetState(() {});
                                        await _run(() async {
                                          if (widget.onShopOpenChanged != null) {
                                            await widget.onShopOpenChanged!(value);
                                          }
                                        });
                                        if (context.mounted) {
                                          setSheetState(() {});
                                        }
                                      },
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            shopOpen
                                ? 'Students can view items and place stationery orders.'
                                : 'Incoming orders are paused. Students will see the shop as closed.',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Eat Mode / Work Mode Setting
                    CanteenSurface(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  mode == CanteenStaffMode.work
                                      ? Icons.work_outline_rounded
                                      : Icons.restaurant_outlined,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Workspace Mode',
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      mode == CanteenStaffMode.work
                                          ? 'Work mode active'
                                          : 'Eat mode active',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SegmentedButton<CanteenStaffMode>(
                            showSelectedIcon: true,
                            segments: const [
                              ButtonSegment(
                                value: CanteenStaffMode.work,
                                icon: Icon(Icons.work_outline_rounded),
                                label: Text('Work mode'),
                              ),
                              ButtonSegment(
                                value: CanteenStaffMode.eat,
                                icon: Icon(Icons.restaurant_outlined),
                                label: Text('Eat mode'),
                              ),
                            ],
                            selected: {mode},
                            onSelectionChanged: _busy
                                ? null
                                : (selection) async {
                                    final newMode = selection.first;
                                    Navigator.of(sheetContext).pop();
                                    await _run(() => widget.onCounterStateChanged(newMode));
                                  },
                          ),
                          const SizedBox(height: 8),
                          Text(
                            mode == CanteenStaffMode.work
                                ? 'Work mode lets you manage stationery inventory and incoming orders.'
                                : 'Eat mode switches to customer view to browse campus items and order food or supplies.',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Full Settings Link (if onProfileTap is provided)
                    if (widget.onProfileTap != null) ...[
                      ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: AppColors.border),
                        ),
                        leading: const Icon(Icons.settings_outlined, color: AppColors.primary),
                        title: const Text('All App Settings', style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: const Text('Account, theme, notifications, and security'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          widget.onProfileTap!();
                        },
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Sign Out button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFB42318),
                          side: const BorderSide(color: Color(0xFFFECDCA)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                          widget.onSignOut();
                        },
                        icon: const Icon(Icons.logout_rounded),
                        label: const Text('Sign out'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _StationerySectionSwitcher extends StatelessWidget {
  const _StationerySectionSwitcher({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).scaffoldBackgroundColor,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<int>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(
              value: 0,
              icon: Icon(Icons.inventory_2_outlined),
              label: Text('Inventory'),
            ),
            ButtonSegment(
              value: 1,
              icon: Icon(Icons.receipt_long_outlined),
              label: Text('Orders'),
            ),
          ],
          selected: {selectedIndex},
          onSelectionChanged: (selection) => onSelected(selection.first),
        ),
      ),
    ),
  );
}

class _InventoryPage extends StatelessWidget {
  const _InventoryPage({
    required this.items,
    required this.totalItems,
    required this.categories,
    required this.selectedCategory,
    required this.query,
    required this.onQueryChanged,
    required this.onCategoryChanged,
    required this.onRefresh,
    required this.onAdd,
    required this.onEdit,
  });

  final List<CanteenMenuItem> items;
  final int totalItems;
  final List<String> categories;
  final String? selectedCategory;
  final String query;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String?> onCategoryChanged;
  final Future<void> Function() onRefresh;
  final VoidCallback onAdd;
  final ValueChanged<CanteenMenuItem> onEdit;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Stationery inventory',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$totalItems items · ${categories.length} categories',
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                key: const ValueKey('stationery-header-add-btn'),
                onPressed: onAdd,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add item'),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE7F7EF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'LIVE CATALOG',
                  style: TextStyle(
                    color: Color(0xFF087A53),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            onChanged: onQueryChanged,
            decoration: InputDecoration(
              hintText: 'Search notebooks, pens, files…',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: () => onQueryChanged(''),
                      icon: const Icon(Icons.close),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: selectedCategory == null,
                  onSelected: (_) => onCategoryChanged(null),
                ),
                for (final category in categories) ...[
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(category),
                    selected: selectedCategory == category,
                    onSelected: (_) => onCategoryChanged(category),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (items.isEmpty)
            CanteenSurface(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  children: [
                    const Icon(
                      Icons.inventory_2_outlined,
                      size: 38,
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: 10),
                    const Text('No stationery items match this filter.'),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      key: const ValueKey('stationery-empty-add-btn'),
                      onPressed: onAdd,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add new item'),
                    ),
                  ],
                ),
              ),
            )
          else
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Semantics(
                  button: true,
                  label: 'Edit ${item.name}',
                  child: InkWell(
                    key: ValueKey('stationery-item-${item.id}'),
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => onEdit(item),
                    child: CanteenSurface(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          MenuItemArt(item: item, size: 58),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  item.category,
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
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                formatCurrency(item.price),
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                item.isAvailable ? 'Available' : 'Unavailable',
                                style: TextStyle(
                                  color: item.isAvailable
                                      ? const Color(0xFF087A53)
                                      : const Color(0xFFB42318),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 6),
                          IconButton(
                            tooltip: 'Edit ${item.name}',
                            onPressed: () => onEdit(item),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _StationeryItemEditor extends StatefulWidget {
  const _StationeryItemEditor({
    this.item,
    required this.onUploadMedia,
    this.existingCategories = const [],
  });

  final CanteenMenuItem? item;
  final Future<String> Function(Uint8List bytes, String filename) onUploadMedia;
  final List<String> existingCategories;

  @override
  State<_StationeryItemEditor> createState() => _StationeryItemEditorState();
}

class _StationeryItemEditorState extends State<_StationeryItemEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _category;
  late final TextEditingController _description;
  late final TextEditingController _actualPrice;
  late final TextEditingController _sellingPrice;
  late bool _available;
  String? _imageUrl;
  Uint8List? _imageBytes;
  var _uploading = false;

  late final List<String> _suggestedCategories;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _name = TextEditingController(text: item?.name ?? '');
    _category = TextEditingController(
      text: item?.category ??
          (widget.existingCategories.isNotEmpty
              ? widget.existingCategories.first
              : 'Notebooks'),
    );
    _description = TextEditingController(text: item?.description ?? '');
    _actualPrice = TextEditingController(
      text: item != null ? item.effectiveActualPrice.toStringAsFixed(2) : '',
    );
    _sellingPrice = TextEditingController(
      text: item != null ? item.price.toStringAsFixed(2) : '',
    );
    _available = item?.isAvailable ?? true;
    _imageUrl = item?.imageUrl;

    final baseSuggestions = [
      'Notebooks',
      'Pens & Writing',
      'Files & Folders',
      'Drawing & Geometry',
      'Exam Supplies',
      'General Stationery',
    ];
    final combined = {...widget.existingCategories, ...baseSuggestions}.toList();
    combined.sort();
    _suggestedCategories = combined;
  }

  @override
  void dispose() {
    _name.dispose();
    _category.dispose();
    _description.dispose();
    _actualPrice.dispose();
    _sellingPrice.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final isNew = widget.item == null;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.9,
        minChildSize: 0.65,
        maxChildSize: 0.96,
        builder: (context, controller) => Form(
          key: _formKey,
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.muted.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                isNew ? 'Add stationery item' : 'Edit inventory item',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                isNew
                    ? 'Publish a new stationery item to the student catalog.'
                    : 'Changes update the live student catalogue.',
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 18),
              _imageEditor(),
              const SizedBox(height: 18),
              TextFormField(
                key: const ValueKey('stationery-edit-name'),
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Item name',
                  hintText: 'e.g. Classmate 200-page Notebook',
                ),
                validator: _required,
              ),
              if (isNew) ...[
                const SizedBox(height: 14),
                const Text(
                  'Category',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final cat in _suggestedCategories) ...[
                        ChoiceChip(
                          label: Text(cat),
                          selected: _category.text.trim().toLowerCase() ==
                              cat.toLowerCase(),
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _category.text = cat);
                            }
                          },
                        ),
                        const SizedBox(width: 6),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  key: const ValueKey('stationery-edit-category'),
                  controller: _category,
                  decoration: const InputDecoration(
                    labelText: 'Category name',
                    hintText: 'e.g. Notebooks, Pens & Writing...',
                    prefixIcon: Icon(Icons.category_outlined, size: 20),
                  ),
                  validator: _required,
                ),
              ],
              const SizedBox(height: 14),
              TextFormField(
                key: const ValueKey('stationery-edit-description'),
                controller: _description,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Item description (optional)',
                  hintText: 'Size, brand, or details students should know',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      key: const ValueKey('stationery-edit-actual-price'),
                      controller: _actualPrice,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Actual price',
                        hintText: 'Cost / procurement price',
                        prefixText: '₹ ',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      key: const ValueKey('stationery-edit-selling-price'),
                      controller: _sellingPrice,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Selling price',
                        prefixText: '₹ ',
                      ),
                      validator: _priceValidator,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SwitchListTile.adaptive(
                key: const ValueKey('stationery-edit-available'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Available for purchase'),
                subtitle: Text(
                  _available
                      ? 'Visible and orderable in the student portal'
                      : 'Shown as unavailable in the student portal',
                ),
                value: _available,
                onChanged: (value) => setState(() => _available = value),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _uploading
                          ? null
                          : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      key: const ValueKey('stationery-edit-save'),
                      onPressed: _uploading ? null : _save,
                      icon: Icon(isNew ? Icons.add_shopping_cart : Icons.save_outlined),
                      label: Text(isNew ? 'Add to inventory' : 'Save changes'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _imageEditor() => Row(
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 92,
          height: 92,
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: _imageBytes != null
              ? Image.memory(_imageBytes!, fit: BoxFit.contain)
              : _imageUrl != null && _imageUrl!.isNotEmpty
              ? Image.network(
                  _imageUrl!,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => _imagePlaceholder(),
                )
              : _imagePlaceholder(),
        ),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: OutlinedButton.icon(
          key: const ValueKey('stationery-edit-image'),
          onPressed: _uploading ? null : _pickAndUploadImage,
          icon: _uploading
              ? const SizedBox.square(
                  dimension: 17,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add_photo_alternate_outlined),
          label: Text(_imageUrl == null ? 'Add item image' : 'Replace image'),
        ),
      ),
    ],
  );

  Widget _imagePlaceholder() => const ColoredBox(
    color: Color(0xFFE5ECFA),
    child: Icon(Icons.inventory_2_outlined, color: AppColors.primary, size: 34),
  );

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'This field is required' : null;

  String? _priceValidator(String? value) {
    final amount = double.tryParse(value?.trim() ?? '');
    return amount == null || amount < 0 ? 'Enter a valid price' : null;
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final cat = _category.text.trim();
    final costPrice = double.tryParse(_actualPrice.text.trim());
    final sellPrice = double.parse(_sellingPrice.text.trim());

    if (widget.item == null) {
      final newItem = CanteenMenuItem(
        id: 'stat_${DateTime.now().millisecondsSinceEpoch}',
        name: _name.text.trim(),
        description: _description.text.trim(),
        category: cat.isEmpty ? 'General Stationery' : cat,
        price: sellPrice,
        actualPrice: costPrice ?? sellPrice,
        cost: costPrice ?? sellPrice,
        isVegetarian: true,
        store: MenuStore.stationery,
        shopKey: 'stationery',
        isAvailable: _available,
        imageUrl: _imageUrl,
      );
      Navigator.pop(context, newItem);
    } else {
      Navigator.pop(
        context,
        widget.item!.copyWith(
          name: _name.text.trim(),
          description: _description.text.trim(),
          category: cat.isEmpty ? widget.item!.category : cat,
          actualPrice: costPrice ?? widget.item!.effectiveActualPrice,
          cost: costPrice ?? widget.item!.cost,
          price: sellPrice,
          isAvailable: _available,
          imageUrl: _imageUrl,
        ),
      );
    }
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final picked = await pickImageFile();
      if (picked == null || picked.bytes.isEmpty || !mounted) return;

      if (picked.bytes.length > 10 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Images must not exceed 10 MB.')),
          );
        }
        return;
      }

      setState(() {
        _uploading = true;
        _imageBytes = picked.bytes;
      });
      final url = await widget.onUploadMedia(picked.bytes, picked.name);
      if (mounted) setState(() => _imageUrl = url);
    } catch (error) {
      if (mounted) {
        setState(() => _imageBytes = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }
}

class _OrdersPage extends StatelessWidget {
  const _OrdersPage({
    required this.orders,
    required this.showHistory,
    required this.counterOpen,
    required this.busy,
    required this.onShowHistoryChanged,
    required this.onRefresh,
    required this.onStatus,
  });

  final List<CanteenOrder> orders;
  final bool showHistory;
  final bool counterOpen;
  final bool busy;
  final ValueChanged<bool> onShowHistoryChanged;
  final Future<void> Function() onRefresh;
  final void Function(String id, CanteenOrderStatus status) onStatus;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
        children: [
          Text(
            'Stationery orders',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          const Text(
            'Pack and hand over orders from this shop only',
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 14),
          SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: false,
                icon: Icon(Icons.pending_actions_outlined),
                label: Text('Live'),
              ),
              ButtonSegment(
                value: true,
                icon: Icon(Icons.history),
                label: Text('History'),
              ),
            ],
            selected: {showHistory},
            onSelectionChanged: (value) => onShowHistoryChanged(value.first),
          ),
          const SizedBox(height: 16),
          if (!showHistory && !counterOpen)
            const _CounterPausedNotice()
          else if (orders.isEmpty)
            CanteenSurface(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  children: [
                    const Icon(
                      Icons.receipt_long_outlined,
                      size: 38,
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      showHistory
                          ? 'No settled stationery orders yet.'
                          : 'No active stationery orders.',
                    ),
                  ],
                ),
              ),
            )
          else
            for (final order in orders)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: showHistory
                    ? _HistoryOrderCard(order: order)
                    : _LiveOrderCard(
                        key: ValueKey('${order.id}_${order.status.name}'),
                        order: order,
                        enabled: !busy,
                        onStatus: onStatus,
                      ),
              ),
        ],
      ),
    );
  }
}

class _LiveOrderCard extends StatelessWidget {
  const _LiveOrderCard({
    super.key,
    required this.order,
    required this.enabled,
    required this.onStatus,
  });

  final CanteenOrder order;
  final bool enabled;
  final void Function(String id, CanteenOrderStatus status) onStatus;

  (CanteenOrderStatus, String, IconData)? get _next {
    final next = order.nextServiceStep ??
        (order.status.isActive ? CanteenOrderStatus.completed : null);
    if (next == null) return null;
    return switch (next) {
      CanteenOrderStatus.preparing => (
        next,
        'Start packing',
        Icons.inventory_outlined,
      ),
      CanteenOrderStatus.ready => (
        next,
        'Ready for pickup',
        Icons.shopping_bag_outlined,
      ),
      CanteenOrderStatus.completed => (
        next,
        'Handed over',
        Icons.check_circle_outline,
      ),
      _ => (
        CanteenOrderStatus.completed,
        'Handed over',
        Icons.check_circle_outline,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final next = _next;
    final nextStatus = next?.$1;
    final nextGradient = nextStatus != null
        ? OrderStatusGradients.forStatus(nextStatus)
        : null;
    final nextForeground = nextStatus != null
        ? (nextStatus == CanteenOrderStatus.preparing
            ? const Color(0xFF78350F)
            : Colors.white)
        : Colors.white;

    final firstItem = order.lines.firstOrNull?.item;

    return SwipeActionCard(
      enabled: enabled,
      dismissOnCommit: next?.$1 == CanteenOrderStatus.completed,
      forward: next == null
          ? null
          : SwipeAction(
              label: next.$2,
              icon: next.$3,
              color: nextGradient?.colors.first ?? AppColors.primary,
              gradient: nextGradient,
              foreground: nextForeground,
              onCommit: () => onStatus(order.id, next.$1),
            ),
      backward: order.status.canReject
          ? SwipeAction(
              label: 'Reject',
              icon: Icons.close,
              color: const Color(0xFFEF4444),
              gradient: OrderStatusGradients.rejected,
              foreground: Colors.white,
              onCommit: () => onStatus(order.id, CanteenOrderStatus.rejected),
            )
          : null,
      child: CanteenSurface(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            ClipOval(
              child: SizedBox(
                width: 48,
                height: 48,
                child: firstItem != null
                    ? MenuItemArt(item: firstItem, size: 48)
                    : Container(
                        color: const Color(0xFFF1F5F9),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.storefront_outlined,
                          size: 24,
                          color: AppColors.primary,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    order.customerName ?? 'Campus user',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text.rich(
                    TextSpan(
                      children: [
                        for (int i = 0; i < order.lines.length; i++) ...[
                          if (i > 0)
                            const TextSpan(
                              text: ', ',
                              style: TextStyle(color: Color(0xFF64748B)),
                            ),
                          TextSpan(
                            text: '${order.lines[i].quantity}× ',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          TextSpan(
                            text: order.lines[i].item.name,
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            OrderNumberStatusBadge(order: order),
          ],
        ),
      ),
    );
  }
}

class _HistoryOrderCard extends StatelessWidget {
  const _HistoryOrderCard({required this.order});
  final CanteenOrder order;

  @override
  Widget build(BuildContext context) => CanteenSurface(
    padding: const EdgeInsets.all(13),
    child: Row(
      children: [
        Icon(
          order.status == CanteenOrderStatus.completed
              ? Icons.check_circle_outline
              : Icons.cancel_outlined,
          color: order.status == CanteenOrderStatus.completed
              ? const Color(0xFF087A53)
              : const Color(0xFFB42318),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                order.customerName ?? 'Campus user',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                '#${order.displayId} · ${order.status.label} · ${formatShortDate(order.createdAt)}',
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
        Text(
          formatCurrency(order.total),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

class _CounterPausedNotice extends StatelessWidget {
  const _CounterPausedNotice();

  @override
  Widget build(BuildContext context) => const CanteenSurface(
    child: Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(Icons.pause_circle_outline, size: 38, color: AppColors.primary),
          SizedBox(height: 10),
          Text(
            'The stationery counter is paused',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 5),
          Text(
            'Open it from Settings at the top right to process incoming orders.',
            style: TextStyle(color: AppColors.muted),
          ),
        ],
      ),
    ),
  );
}

