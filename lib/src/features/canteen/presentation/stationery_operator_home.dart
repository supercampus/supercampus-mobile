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
    this.initialAction,
  });

  final CanteenStore store;
  final VoidCallback onExitModule;
  final VoidCallback onSignOut;
  final Future<void> Function() onRefresh;
  final Future<void> Function(CanteenStaffMode mode) onCounterStateChanged;
  final Future<void> Function(String orderId, CanteenOrderStatus status)
  onOrderStatusChanged;
  final Future<void> Function(CanteenMenuItem item) onSaveItem;
  final Future<String> Function(Uint8List bytes, String filename) onUploadMedia;
  final String? initialAction;

  @override
  State<StationeryOperatorHome> createState() => _StationeryOperatorHomeState();
}

class _StationeryOperatorHomeState extends State<StationeryOperatorHome> {
  var _index = 0;
  var _busy = false;
  var _showHistory = false;
  var _query = '';
  String? _category;

  @override
  void initState() {
    super.initState();
    if (const {'orders', 'order_history'}.contains(widget.initialAction)) {
      _index = 1;
      _showHistory = widget.initialAction == 'order_history';
    }
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
    final counterOpen = widget.store.staffState.mode == CanteenStaffMode.work;

    return Scaffold(
      appBar: AppBar(
        leading: ModuleBackButton(onPressed: widget.onExitModule),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Stationery shop'),
            Text(
              counterOpen ? 'Counter open' : 'Counter paused',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
            ),
          ],
        ),
      ),
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
                _StationeryProfile(
                  store: widget.store,
                  busy: _busy,
                  onCounterStateChanged: (mode) =>
                      _run(() => widget.onCounterStateChanged(mode)),
                  onSignOut: widget.onSignOut,
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
      ),
    );
    if (edited == null || !mounted) return;
    await _run(() => widget.onSaveItem(edited));
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
            ButtonSegment(
              value: 2,
              icon: Icon(Icons.person_outline),
              label: Text('Profile'),
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
            const CanteenSurface(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 38,
                      color: AppColors.primary,
                    ),
                    SizedBox(height: 10),
                    Text('No stationery items match this filter.'),
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
    required this.item,
    required this.onUploadMedia,
  });

  final CanteenMenuItem item;
  final Future<String> Function(Uint8List bytes, String filename) onUploadMedia;

  @override
  State<_StationeryItemEditor> createState() => _StationeryItemEditorState();
}

class _StationeryItemEditorState extends State<_StationeryItemEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _actualPrice;
  late final TextEditingController _sellingPrice;
  late bool _available;
  String? _imageUrl;
  Uint8List? _imageBytes;
  var _uploading = false;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _name = TextEditingController(text: item.name);
    _description = TextEditingController(text: item.description);
    _actualPrice = TextEditingController(
      text: item.effectiveActualPrice.toStringAsFixed(2),
    );
    _sellingPrice = TextEditingController(text: item.price.toStringAsFixed(2));
    _available = item.isAvailable;
    _imageUrl = item.imageUrl;
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _actualPrice.dispose();
    _sellingPrice.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
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
                'Edit inventory item',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              const Text(
                'Changes update the live student catalogue.',
                style: TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 18),
              _imageEditor(),
              const SizedBox(height: 18),
              TextFormField(
                key: const ValueKey('stationery-edit-name'),
                controller: _name,
                decoration: const InputDecoration(labelText: 'Item name'),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey('stationery-edit-description'),
                controller: _description,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Item description',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
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
                        prefixText: '₹ ',
                      ),
                      validator: _priceValidator,
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
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Save changes'),
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
    Navigator.pop(
      context,
      widget.item.copyWith(
        name: _name.text.trim(),
        description: _description.text.trim(),
        actualPrice: double.parse(_actualPrice.text.trim()),
        price: double.parse(_sellingPrice.text.trim()),
        isAvailable: _available,
        imageUrl: _imageUrl,
      ),
    );
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
    required this.order,
    required this.enabled,
    required this.onStatus,
  });

  final CanteenOrder order;
  final bool enabled;
  final void Function(String id, CanteenOrderStatus status) onStatus;

  (CanteenOrderStatus, String, IconData)? get _next {
    final next = order.status.nextServiceStep;
    return switch (next) {
      CanteenOrderStatus.preparing => (
        next!,
        'Start packing',
        Icons.inventory_outlined,
      ),
      CanteenOrderStatus.ready => (
        next!,
        'Ready for pickup',
        Icons.shopping_bag_outlined,
      ),
      CanteenOrderStatus.completed => (
        next!,
        'Handed over',
        Icons.check_circle_outline,
      ),
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final next = _next;
    return SwipeActionCard(
      enabled: enabled,
      forward: next == null
          ? null
          : SwipeAction(
              label: next.$2,
              icon: next.$3,
              color: AppColors.primary,
              onCommit: () => onStatus(order.id, next.$1),
            ),
      backward: order.status.canReject
          ? SwipeAction(
              label: 'Reject',
              icon: Icons.close,
              color: const Color(0xFFB42318),
              onCommit: () => onStatus(order.id, CanteenOrderStatus.rejected),
            )
          : null,
      child: CanteenSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primary.withValues(alpha: .1),
                  foregroundColor: AppColors.primary,
                  child: Text(_initials(order.customerName)),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.customerName ?? 'Campus user',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '#${order.displayId}',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  order.status.label,
                  style: const TextStyle(color: AppColors.primary),
                ),
              ],
            ),
            const Divider(height: 24),
            for (final line in order.lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Text(
                      '${line.quantity}×',
                      style: const TextStyle(color: AppColors.primary),
                    ),
                    const SizedBox(width: 7),
                    Expanded(child: Text(line.item.name)),
                    Text(formatCurrency(line.total)),
                  ],
                ),
              ),
            const SizedBox(height: 5),
            Row(
              children: [
                const Icon(
                  Icons.swipe_outlined,
                  size: 17,
                  color: AppColors.muted,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    next == null ? 'Order settled' : 'Swipe right: ${next.$2}',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ),
                Text(
                  formatCurrency(order.total),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
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

class _StationeryProfile extends StatelessWidget {
  const _StationeryProfile({
    required this.store,
    required this.busy,
    required this.onCounterStateChanged,
    required this.onSignOut,
  });

  final CanteenStore store;
  final bool busy;
  final ValueChanged<CanteenStaffMode> onCounterStateChanged;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final mode = store.staffState.mode;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
      children: [
        Text(
          'Stationery profile',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4200FF), Color(0xFF9600FF)],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 31,
                backgroundColor: Colors.white.withValues(alpha: .18),
                foregroundColor: Colors.white,
                child: Text(
                  store.user.initials,
                  style: const TextStyle(fontSize: 22),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      store.user.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      store.user.email,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'MEC Stationery · Shop operator',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        CanteenSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Counter status',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 5),
              const Text(
                'Open accepts and processes stationery orders. Paused temporarily stops the counter queue.',
                style: TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 14),
              SegmentedButton<CanteenStaffMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: CanteenStaffMode.work,
                    icon: Icon(Icons.storefront_outlined),
                    label: Text('Open'),
                  ),
                  ButtonSegment(
                    value: CanteenStaffMode.eat,
                    icon: Icon(Icons.pause_circle_outline),
                    label: Text('Paused'),
                  ),
                ],
                selected: {mode},
                onSelectionChanged: busy
                    ? null
                    : (selection) => onCounterStateChanged(selection.first),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: onSignOut,
          icon: const Icon(Icons.logout),
          label: const Text('Sign out'),
        ),
      ],
    );
  }
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
            'Open it from Profile to process incoming orders.',
            style: TextStyle(color: AppColors.muted),
          ),
        ],
      ),
    ),
  );
}

String _initials(String? name) {
  final parts = (name ?? '')
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .take(2);
  final value = parts.map((part) => part[0].toUpperCase()).join();
  return value.isEmpty ? 'SC' : value;
}
