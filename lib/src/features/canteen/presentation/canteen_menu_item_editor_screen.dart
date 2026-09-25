import 'dart:typed_data';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/image_picker_helper.dart';
import '../../../core/widgets/module_navigation_buttons.dart';
import '../data/canteen_models.dart';
import 'widgets/canteen_surface.dart';

/// Full-page editor screen to add or update a canteen menu item.
///
/// Divides price into distinct "Cost" and "Selling Price" inputs,
/// displaying live estimated profit and margin for the owner.
class CanteenMenuItemEditorScreen extends StatefulWidget {
  const CanteenMenuItemEditorScreen({
    super.key,
    this.item,
    required this.shops,
    required this.selectedShopKey,
    required this.onUploadMedia,
  });

  final CanteenMenuItem? item;
  final List<CanteenShop> shops;
  final String selectedShopKey;
  final Future<String> Function(Uint8List bytes, String filename) onUploadMedia;

  @override
  State<CanteenMenuItemEditorScreen> createState() =>
      _CanteenMenuItemEditorScreenState();
}

class _CanteenMenuItemEditorScreenState
    extends State<CanteenMenuItemEditorScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _cost;
  late final TextEditingController _sellingPrice;
  late final TextEditingController _category;

  late String _shopKey;
  String? _imageUrl;
  Uint8List? _imageBytes;
  bool _uploading = false;
  late bool _available;
  late bool _vegetarian;
  late bool _instant;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _name = TextEditingController(text: item?.name ?? '');
    _description = TextEditingController(text: item?.description ?? '');
    _cost = TextEditingController(
      text: item?.cost != null ? item!.cost!.toStringAsFixed(0) : '',
    );
    _sellingPrice = TextEditingController(
      text: item?.price != null ? item!.price.toStringAsFixed(0) : '',
    );
    _category = TextEditingController(text: item?.category ?? 'meals');

    final itemShopKey = item?.effectiveShopKey;
    _shopKey = widget.shops.any((shop) => shop.shopKey == itemShopKey)
        ? itemShopKey!
        : widget.selectedShopKey;

    _imageUrl = item?.imageUrl;
    _available = item?.isAvailable ?? true;
    _vegetarian = item?.isVegetarian ?? true;
    _instant = item?.isInstant ?? false;

    _cost.addListener(_onPriceChanged);
    _sellingPrice.addListener(_onPriceChanged);
  }

  void _onPriceChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _cost.removeListener(_onPriceChanged);
    _sellingPrice.removeListener(_onPriceChanged);
    _name.dispose();
    _description.dispose();
    _cost.dispose();
    _sellingPrice.dispose();
    _category.dispose();
    super.dispose();
  }

  double? get _costValue => double.tryParse(_cost.text.trim());
  double? get _sellingPriceValue => double.tryParse(_sellingPrice.text.trim());

  double? get _profit {
    final s = _sellingPriceValue;
    final c = _costValue;
    if (s == null || c == null) return null;
    return s - c;
  }

  double? get _margin {
    final s = _sellingPriceValue;
    final p = _profit;
    if (s == null || p == null || s <= 0) return null;
    return (p / s) * 100;
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

  void _onSave() {
    if (!_formKey.currentState!.validate()) return;

    final sellingPrice = _sellingPriceValue;
    if (sellingPrice == null || sellingPrice <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid selling price.')),
      );
      return;
    }

    final cost = _costValue ?? (sellingPrice * 0.7);

    final savedItem = CanteenMenuItem(
      id: widget.item?.id ?? '',
      name: _name.text.trim(),
      description: _description.text.trim(),
      store: MenuStoreLabel.parse(_shopKey),
      shopKey: _shopKey,
      category: _category.text.trim(),
      price: sellingPrice,
      cost: cost,
      isVegetarian: _vegetarian,
      isPopular: widget.item?.isPopular ?? false,
      isAvailable: _available,
      isInstant: _instant,
      prepMinutes: widget.item?.prepMinutes ?? 10,
      imageUrl: _imageUrl,
    );

    Navigator.of(context).pop(savedItem);
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.item == null;
    final profit = _profit;
    final margin = _margin;

    return Scaffold(
      appBar: AppBar(
        leading: ModuleBackButton(
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(isNew ? 'Add menu item' : 'Edit menu item'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              onPressed: _uploading ? null : _onSave,
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('Save', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 48),
          children: [
            // Basic Details Card
            CanteenSurface(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Item Details',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _name,
                    decoration: const InputDecoration(
                      labelText: 'Item name *',
                      hintText: 'e.g. Masala Dosa, Cold Coffee',
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) =>
                        val == null || val.trim().isEmpty ? 'Name is required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _description,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      hintText: 'Brief description of ingredients or preparation',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _shopKey,
                    decoration: const InputDecoration(
                      labelText: 'Assigned Shop *',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final shop in widget.shops)
                        DropdownMenuItem(
                          value: shop.shopKey,
                          child: Text(shop.name),
                        ),
                    ],
                    onChanged: (value) => setState(() {
                      _shopKey = value ?? _shopKey;
                    }),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _category,
                    decoration: const InputDecoration(
                      labelText: 'Category *',
                      hintText: 'meals, snacks, drinks, stationery...',
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) =>
                        val == null || val.trim().isEmpty ? 'Category is required' : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Divided Price Section (Cost & Selling Price)
            CanteenSurface(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.payments_outlined, size: 18, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Pricing & Profit',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Set cost and selling price to track profit in the Sales section',
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                  const SizedBox(height: 14),

                  // Side-by-side Cost & Selling Price
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _cost,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Cost *',
                            hintText: 'e.g. 30',
                            prefixText: '₹ ',
                            helperText: 'Expense to make',
                            border: OutlineInputBorder(),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Cost required';
                            }
                            final parsed = double.tryParse(val.trim());
                            if (parsed == null || parsed < 0) {
                              return 'Invalid cost';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: TextFormField(
                          controller: _sellingPrice,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Selling Price *',
                            hintText: 'e.g. 50',
                            prefixText: '₹ ',
                            helperText: 'Charged to student',
                            border: OutlineInputBorder(),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Price required';
                            }
                            final parsed = double.tryParse(val.trim());
                            if (parsed == null || parsed <= 0) {
                              return 'Price > ₹0';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Live Profit Banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: profit == null
                          ? const Color(0xFFF1F5F9)
                          : profit >= 0
                              ? const Color(0xFFECFDF5)
                              : const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: profit == null
                            ? const Color(0xFFCBD5E1)
                            : profit >= 0
                                ? const Color(0xFFA7F3D0)
                                : const Color(0xFFFECACA),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          profit == null
                              ? Icons.calculate_outlined
                              : profit >= 0
                                  ? Icons.trending_up_rounded
                                  : Icons.trending_down_rounded,
                          color: profit == null
                              ? const Color(0xFF64748B)
                              : profit >= 0
                                  ? const Color(0xFF059669)
                                  : const Color(0xFFDC2626),
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                profit == null
                                    ? 'Profit Preview'
                                    : profit >= 0
                                        ? 'Estimated Profit: ${formatCurrency(profit)}'
                                        : 'Operating at a loss: ${formatCurrency(profit)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: profit == null
                                      ? const Color(0xFF475569)
                                      : profit >= 0
                                          ? const Color(0xFF047857)
                                          : const Color(0xFFB91C1C),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                profit == null
                                    ? 'Enter both Cost and Selling Price above'
                                    : '${margin?.toStringAsFixed(1)}% margin on selling price',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: profit == null
                                      ? const Color(0xFF64748B)
                                      : profit >= 0
                                          ? const Color(0xFF065F46)
                                          : const Color(0xFF991B1B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Image Upload Section
            CanteenSurface(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.image_outlined, size: 18, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Item Art / Photo',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: _imageBytes != null
                              ? Image.memory(_imageBytes!, fit: BoxFit.cover)
                              : _imageUrl != null && _imageUrl!.isNotEmpty
                                  ? Image.network(_imageUrl!, fit: BoxFit.cover)
                                  : const ColoredBox(
                                      color: Color(0xFFE9EDF5),
                                      child: Icon(Icons.restaurant_menu_rounded, size: 32, color: AppColors.primary),
                                    ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _uploading ? null : _pickAndUploadImage,
                          icon: _uploading
                              ? const SizedBox.square(
                                  dimension: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.upload_outlined),
                          label: Text(
                            _imageUrl == null ? 'Upload item image' : 'Replace image',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Item Flags & Settings
            CanteenSurface(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Available for ordering', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Visible to students on the counter menu'),
                    value: _available,
                    onChanged: (val) => setState(() => _available = val),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('Vegetarian', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Green vegetarian badge'),
                    value: _vegetarian,
                    onChanged: (val) => setState(() => _vegetarian = val),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('Instant Food', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Served straight from counter (Pending -> Delivered)'),
                    value: _instant,
                    onChanged: (val) => setState(() => _instant = val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Bottom Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _uploading ? null : _onSave,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.check_rounded),
                    label: Text(isNew ? 'Add Item' : 'Save Changes'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
