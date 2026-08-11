import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../data/canteen_models.dart';
import 'widgets/canteen_surface.dart';
import 'widgets/menu_item_art.dart';
import 'widgets/quantity_control.dart';

class StudentCanteenHome extends StatefulWidget {
  const StudentCanteenHome({
    super.key,
    required this.store,
    required this.cart,
    required this.onAdd,
    required this.onRemove,
    required this.onOpenCart,
    required this.onOpenWallet,
    required this.onOpenProfile,
    required this.onExitModule,
  });

  final CanteenStore store;
  final Map<String, int> cart;
  final ValueChanged<CanteenMenuItem> onAdd;
  final ValueChanged<CanteenMenuItem> onRemove;
  final VoidCallback onOpenCart;
  final VoidCallback onOpenWallet;
  final VoidCallback onOpenProfile;
  final VoidCallback onExitModule;

  @override
  State<StudentCanteenHome> createState() => _StudentCanteenHomeState();
}

class _StudentCanteenHomeState extends State<StudentCanteenHome> {
  MenuCategory _category = MenuCategory.meals;
  bool _isSearching = false;
  String _query = '';

  List<CanteenMenuItem> get _visibleItems {
    final query = _query.trim().toLowerCase();
    return widget.store.menu.where((item) {
      final matchesCategory = item.category == _category;
      final matchesQuery =
          query.isEmpty ||
          item.name.toLowerCase().contains(query) ||
          item.description.toLowerCase().contains(query);
      return matchesCategory && matchesQuery;
    }).toList();
  }

  int get _cartCount =>
      widget.cart.values.fold(0, (total, quantity) => total + quantity);

  double get _cartTotal {
    return widget.store.menu.fold(0, (total, item) {
      return total + item.price * (widget.cart[item.id] ?? 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Stack(
            children: [
              ListView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  16,
                  20,
                  _cartCount > 0 ? 112 : 28,
                ),
                children: [
                  _buildHeader(context),
                  if (_isSearching) ...[
                    const SizedBox(height: 14),
                    TextField(
                      autofocus: true,
                      onChanged: (value) => setState(() => _query = value),
                      decoration: InputDecoration(
                        hintText: 'Search today’s menu',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear search',
                                onPressed: () => setState(() => _query = ''),
                                icon: const Icon(Icons.close),
                              ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  _CategorySelector(
                    selected: _category,
                    onSelected: (category) => setState(() {
                      _category = category;
                      _query = '';
                    }),
                  ),
                  const SizedBox(height: 18),
                  const _OpenStatusBand(),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Text(
                        _category.label,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Spacer(),
                      Text(
                        '${_visibleItems.length} available',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_visibleItems.isEmpty)
                    const CanteenSurface(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 28),
                        child: Center(
                          child: Text('No matching items available.'),
                        ),
                      ),
                    )
                  else
                    for (final item in _visibleItems)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _MenuItemRow(
                          item: item,
                          quantity: widget.cart[item.id] ?? 0,
                          onAdd: () => widget.onAdd(item),
                          onRemove: () => widget.onRemove(item),
                        ),
                      ),
                ],
              ),
              if (_cartCount > 0)
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 14,
                  child: _CartBar(
                    itemCount: _cartCount,
                    total: _cartTotal,
                    onTap: widget.onOpenCart,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        IconButton.filled(
          tooltip: 'Modules Home',
          onPressed: widget.onExitModule,
          style: IconButton.styleFrom(backgroundColor: AppColors.primary),
          icon: const Icon(Icons.home),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: widget.onOpenWallet,
            child: Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFE7F3EC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBBD9C6)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      formatCurrency(widget.store.walletBalance),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        IconButton(
          tooltip: _isSearching ? 'Close search' : 'Search menu',
          onPressed: () => setState(() {
            _isSearching = !_isSearching;
            if (!_isSearching) _query = '';
          }),
          icon: Icon(_isSearching ? Icons.close : Icons.search),
        ),
      ],
    );
  }
}

class _CategorySelector extends StatelessWidget {
  const _CategorySelector({required this.selected, required this.onSelected});

  final MenuCategory selected;
  final ValueChanged<MenuCategory> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: MenuCategory.values.map((category) {
        final isSelected = category == selected;
        final icon = switch (category) {
          MenuCategory.meals => Icons.restaurant_outlined,
          MenuCategory.snacks => Icons.bakery_dining_outlined,
          MenuCategory.drinks => Icons.local_cafe_outlined,
        };
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: category == MenuCategory.drinks ? 0 : 8,
            ),
            child: Material(
              color: isSelected ? AppColors.primary : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: isSelected ? AppColors.primary : AppColors.border,
                ),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => onSelected(category),
                child: SizedBox(
                  height: 44,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        icon,
                        size: 18,
                        color: isSelected ? Colors.white : AppColors.muted,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          category.label,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isSelected ? Colors.white : AppColors.muted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _OpenStatusBand extends StatelessWidget {
  const _OpenStatusBand();

  @override
  Widget build(BuildContext context) {
    return CanteenSurface(
      color: AppColors.ink,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.amber,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.bolt, color: AppColors.ink),
          ),
          const SizedBox(width: 13),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Canteen is open',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Order now · Counter closes at 8:30 PM',
                  style: TextStyle(color: Color(0xFFCBD2CE), fontSize: 12),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: Colors.white.withValues(alpha: 0.7)),
        ],
      ),
    );
  }
}

class _MenuItemRow extends StatelessWidget {
  const _MenuItemRow({
    required this.item,
    required this.quantity,
    required this.onAdd,
    required this.onRemove,
  });

  final CanteenMenuItem item;
  final int quantity;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return CanteenSurface(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          MenuItemArt(item: item),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 11,
                      height: 11,
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: item.isVegetarian
                              ? AppColors.success
                              : const Color(0xFFB42318),
                        ),
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: item.isVegetarian
                              ? AppColors.success
                              : const Color(0xFFB42318),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        item.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    if (item.isPopular)
                      const Icon(Icons.bolt, color: AppColors.amber, size: 19),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  item.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 9),
                Row(
                  children: [
                    Text(
                      formatCurrency(item.price),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    QuantityControl(
                      quantity: quantity,
                      compact: true,
                      onAdd: onAdd,
                      onRemove: onRemove,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CartBar extends StatelessWidget {
  const _CartBar({
    required this.itemCount,
    required this.total,
    required this.onTap,
  });

  final int itemCount;
  final double total;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(8),
      elevation: 4,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$itemCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Text(
                  'View cart',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                formatCurrency(total),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 5),
              const Icon(Icons.arrow_forward, color: Colors.white, size: 19),
            ],
          ),
        ),
      ),
    );
  }
}
