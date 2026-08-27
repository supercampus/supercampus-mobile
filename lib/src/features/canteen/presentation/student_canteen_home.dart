import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/module_navigation_buttons.dart';
import '../../../core/widgets/campus_nav_bar.dart';
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
    this.onWorkMode,
  });

  final CanteenStore store;
  final Map<String, int> cart;
  final ValueChanged<CanteenMenuItem> onAdd;
  final ValueChanged<CanteenMenuItem> onRemove;
  final VoidCallback onOpenCart;
  final VoidCallback onOpenWallet;
  final VoidCallback onOpenProfile;
  final VoidCallback onExitModule;
  final VoidCallback? onWorkMode;

  @override
  State<StudentCanteenHome> createState() => _StudentCanteenHomeState();
}

class _StudentCanteenHomeState extends State<StudentCanteenHome> {
  String? _shopKey;
  bool _isSearching = false;
  String _query = '';

  /// Sub-category filter within the open storefront; null means "All".
  String? _subCategory;

  List<CanteenShop> get _shops {
    final active = widget.store.shops.where((shop) => shop.isActive).toList();
    if (active.isNotEmpty) return active;

    final keys = <String>[];
    for (final item in widget.store.menu) {
      if (!keys.contains(item.effectiveShopKey)) {
        keys.add(item.effectiveShopKey);
      }
    }
    return [
      for (final key in keys)
        CanteenShop(
          id: key,
          shopKey: key,
          name: _shopLabel(key),
          category: key == 'stationery' ? 'Stationery' : 'Canteen',
        ),
    ];
  }

  String? get _selectedShopKey {
    final shops = _shops;
    if (shops.isEmpty) return null;
    if (shops.any((shop) => shop.shopKey == _shopKey)) return _shopKey;
    return shops.first.shopKey;
  }

  @override
  void initState() {
    super.initState();
    _shopKey = _shops.isEmpty ? null : _shops.first.shopKey;
  }

  @override
  void didUpdateWidget(covariant StudentCanteenHome oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_shops.isNotEmpty && !_shops.any((shop) => shop.shopKey == _shopKey)) {
      _shopKey = _shops.first.shopKey;
      _subCategory = null;
    }
  }

  /// Categories present in the open storefront, in menu order.
  List<String> get _subCategories {
    final seen = <String>[];
    for (final item in widget.store.menu) {
      if (item.effectiveShopKey == _selectedShopKey &&
          !seen.contains(item.category)) {
        seen.add(item.category);
      }
    }
    return seen;
  }

  List<CanteenMenuItem> get _visibleItems {
    final query = _query.trim().toLowerCase();
    return widget.store.menu.where((item) {
      final matchesStore = item.effectiveShopKey == _selectedShopKey;
      final matchesCategory =
          _subCategory == null || item.category == _subCategory;
      final matchesQuery =
          query.isEmpty ||
          item.name.toLowerCase().contains(query) ||
          item.description.toLowerCase().contains(query);
      return matchesStore && matchesCategory && matchesQuery;
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
                  _StoreSelector(
                    shops: _shops,
                    selected: _selectedShopKey,
                    onSelected: (shopKey) => setState(() {
                      _shopKey = shopKey;
                      _subCategory = null;
                      _query = '';
                    }),
                  ),
                  // Food storefronts are a single flat list; only a shop with
                  // several aisles needs a second row of filters.
                  if (_subCategories.length > 1) ...[
                    const SizedBox(height: 12),
                    _SubCategoryFilter(
                      categories: _subCategories,
                      selected: _subCategory,
                      onSelected: (category) =>
                          setState(() => _subCategory = category),
                    ),
                  ],
                  const SizedBox(height: 18),
                  const _OpenStatusBand(),
                  const SizedBox(height: 22),
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
                  // The nav bar floats over the module content, so a bar
                  // pinned to the bottom lands behind it and its raised
                  // centre button swallows the tap. Clear it the same way
                  // the module dashboard does.
                  bottom:
                      CampusNavBar.heightFor(context) +
                      MediaQuery.paddingOf(context).bottom +
                      20,
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
        ModuleBackButton(onPressed: widget.onExitModule),
        const SizedBox(width: 10),
        // The balance is a glance, not a destination, so the pill hugs its
        // number instead of stretching across the bar. Tapping it opens the
        // wallet, where the histories live.
        InkWell(
          customBorder: const StadiumBorder(),
          onTap: widget.onOpenWallet,
          child: Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: const ShapeDecoration(
              color: Color(0xFFEAF1FE),
              shape: StadiumBorder(),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 17,
                  color: Color(0xFF2563EB),
                ),
                const SizedBox(width: 7),
                Text(
                  formatCurrency(widget.store.walletBalance),
                  style: const TextStyle(
                    color: Color(0xFF2563EB),
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ),
          ),
        ),
        const Spacer(),
        const SizedBox(width: 6),
        if (widget.onWorkMode != null)
          IconButton(
            tooltip: 'Switch to owner workspace',
            onPressed: widget.onWorkMode,
            icon: const Icon(Icons.storefront_outlined),
          ),
        IconButton(
          tooltip: _isSearching ? 'Close search' : 'Search menu',
          onPressed: () => setState(() {
            _isSearching = !_isSearching;
            if (!_isSearching) _query = '';
          }),
          icon: Icon(_isSearching ? Icons.close : Icons.search),
        ),
        ModuleHomeButton(onPressed: widget.onExitModule),
      ],
    );
  }
}

/// The three storefronts, as pills across the top of the menu.
class _StoreSelector extends StatelessWidget {
  const _StoreSelector({
    required this.shops,
    required this.selected,
    required this.onSelected,
  });

  final List<CanteenShop> shops;
  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    if (shops.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: shops.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final shop = shops[index];
          final isSelected = shop.shopKey == selected;
          final category = shop.category.toLowerCase();
          final icon = category.contains('station')
              ? Icons.storefront_outlined
              : Icons.restaurant;
          return Material(
            color: isSelected ? AppColors.primary : Colors.white,
            shape: StadiumBorder(
              side: BorderSide(
                color: isSelected ? AppColors.primary : AppColors.border,
              ),
            ),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: () => onSelected(shop.shopKey),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 18,
                      color: isSelected ? Colors.white : AppColors.muted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      shop.name,
                      style: TextStyle(
                        color: isSelected ? Colors.white : AppColors.muted,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

String _shopLabel(String value) {
  final words = value.replaceAll(RegExp(r'[-_]'), ' ').trim().split(' ');
  return words
      .where((word) => word.isNotEmpty)
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}

/// Aisle filters inside a storefront that has more than one, scrolled
/// horizontally because the labels are owner-written and can be long.
class _SubCategoryFilter extends StatelessWidget {
  const _SubCategoryFilter({
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  final List<String> categories;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = index == 0 ? null : categories[index - 1];
          final isSelected = category == selected;
          return Material(
            color: isSelected ? AppColors.primary : Colors.white,
            shape: StadiumBorder(
              side: BorderSide(
                color: isSelected ? AppColors.primary : AppColors.border,
              ),
            ),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: () => onSelected(category),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  child: Text(
                    category ?? 'All',
                    style: TextStyle(
                      color: isSelected ? Colors.white : AppColors.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
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
                  'Shops are open',
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

/// A menu row: thumbnail, name, price, and a single tap to add.
///
/// The design keeps the row deliberately quiet — no description, no metadata —
/// so a long menu stays scannable. Everything else about the item lives in the
/// cart and the order.
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
    final unavailable = !item.isAvailable;
    return Opacity(
      opacity: unavailable ? 0.5 : 1,
      child: CanteenSurface(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            MenuItemArt(item: item),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          item.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (item.isInstant) ...[
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.bolt,
                          size: 19,
                          color: Color(0xFFF97316),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    formatCurrency(item.price),
                    style: const TextStyle(
                      color: Color(0xFF2563EB),
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (unavailable)
              const Text('Sold out', style: TextStyle(color: AppColors.muted))
            else if (quantity == 0)
              _AddButton(onTap: onAdd)
            else
              QuantityControl(
                quantity: quantity,
                compact: true,
                onAdd: onAdd,
                onRemove: onRemove,
              ),
          ],
        ),
      ),
    );
  }
}

/// The round blue affordance that puts a first unit in the cart.
class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Add item',
      child: Material(
        color: const Color(0xFF2563EB),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: const SizedBox(
            width: 46,
            height: 46,
            child: Icon(Icons.add, color: Colors.white, size: 24),
          ),
        ),
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
