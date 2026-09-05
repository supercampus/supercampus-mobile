import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/module_navigation_buttons.dart';
import '../data/canteen_models.dart';
import 'widgets/canteen_surface.dart';

class LaundryOperatorHome extends StatefulWidget {
  const LaundryOperatorHome({
    super.key,
    required this.store,
    required this.onExitModule,
    required this.onRefresh,
    required this.onUpdatePrice,
    required this.onCreateCharge,
  });

  final CanteenStore store;
  final VoidCallback onExitModule;
  final Future<void> Function() onRefresh;
  final Future<double> Function(double price) onUpdatePrice;
  final Future<LaundryCharge> Function({
    required LaundryServiceType serviceType,
    required String name,
    required String description,
    required double quantity,
    double? price,
  })
  onCreateCharge;

  @override
  State<LaundryOperatorHome> createState() => _LaundryOperatorHomeState();
}

class _LaundryOperatorHomeState extends State<LaundryOperatorHome> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _quantity = TextEditingController();
  final _price = TextEditingController();
  var _type = LaundryServiceType.wash;
  var _submitting = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _quantity.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _setRate() async {
    final controller = TextEditingController(
      text: widget.store.laundryPricePerKg > 0
          ? widget.store.laundryPricePerKg.toStringAsFixed(0)
          : '',
    );
    final price = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Wash price per kg'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            prefixText: '₹ ',
            hintText: 'Price',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = double.tryParse(controller.text.trim());
              if (value != null && value > 0) Navigator.pop(context, value);
            },
            child: const Text('Save rate'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (price == null || !mounted) return;
    try {
      await widget.onUpdatePrice(price);
      await widget.onRefresh();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  Future<void> _generate() async {
    if (!_formKey.currentState!.validate()) return;
    if (_type == LaundryServiceType.wash &&
        widget.store.laundryPricePerKg <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Set the wash price per kg first.')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final charge = await widget.onCreateCharge(
        serviceType: _type,
        name: _name.text.trim(),
        description: _description.text.trim(),
        quantity: double.parse(_quantity.text.trim()),
        price: _type == LaundryServiceType.ironing
            ? double.parse(_price.text.trim())
            : null,
      );
      if (!mounted) return;
      _name.clear();
      _description.clear();
      _quantity.clear();
      _price.clear();
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Laundry payment QR'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              QrImageView(data: charge.qrPayload!, size: 220),
              const SizedBox(height: 12),
              Text(
                charge.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${charge.quantity.toStringAsFixed(charge.unitLabel == 'kg' ? 1 : 0)} ${charge.unitLabel} · ${formatCurrency(charge.total)}',
              ),
              const SizedBox(height: 10),
              const Text(
                'Ask the student to scan this QR. The payment card will appear inside Campus Laundry.',
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      );
      await widget.onRefresh();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final washTotal =
        (double.tryParse(_quantity.text) ?? 0) * widget.store.laundryPricePerKg;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 130),
        children: [
          Row(
            children: [
              ModuleBackButton(onPressed: widget.onExitModule),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Campus Laundry',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Create student payment QR',
                      style: TextStyle(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: widget.onRefresh,
                icon: const Icon(Icons.refresh),
              ),
              ModuleHomeButton(onPressed: widget.onExitModule),
            ],
          ),
          const SizedBox(height: 18),
          CanteenSurface(
            color: const Color(0xFFEFE9FF),
            child: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0xFF5B22FF),
                  child: Icon(Icons.local_laundry_service, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Wash rate',
                        style: TextStyle(color: AppColors.muted),
                      ),
                      Text(
                        widget.store.laundryPricePerKg > 0
                            ? '${formatCurrency(widget.store.laundryPricePerKg)} per kg'
                            : 'Not configured',
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                OutlinedButton(
                  onPressed: _setRate,
                  child: Text(
                    widget.store.laundryPricePerKg > 0 ? 'Change' : 'Set rate',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'New laundry charge',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          SegmentedButton<LaundryServiceType>(
            segments: const [
              ButtonSegment(
                value: LaundryServiceType.wash,
                icon: Icon(Icons.local_laundry_service_outlined),
                label: Text('Wash by kg'),
              ),
              ButtonSegment(
                value: LaundryServiceType.ironing,
                icon: Icon(Icons.iron_outlined),
                label: Text('Ironing'),
              ),
            ],
            selected: {_type},
            onSelectionChanged: (value) => setState(() => _type = value.first),
          ),
          const SizedBox(height: 12),
          CanteenSurface(
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _name,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      hintText: 'Student or bundle name',
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter a name'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _description,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      hintText: 'Colour, room, instructions…',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _quantity,
                    onChanged: (_) => setState(() {}),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: _type == LaundryServiceType.wash
                          ? 'Weight of clothes'
                          : 'Number of clothes',
                      suffixText: _type == LaundryServiceType.wash
                          ? 'kg'
                          : 'clothes',
                    ),
                    validator: (value) =>
                        (double.tryParse(value?.trim() ?? '') ?? 0) <= 0
                        ? 'Enter a valid quantity'
                        : null,
                  ),
                  if (_type == LaundryServiceType.ironing) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _price,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Total ironing price',
                        prefixText: '₹ ',
                      ),
                      validator: (value) =>
                          (double.tryParse(value?.trim() ?? '') ?? 0) <= 0
                          ? 'Enter the price'
                          : null,
                    ),
                  ],
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _type == LaundryServiceType.wash
                              ? 'Total: ${formatCurrency(washTotal)}'
                              : 'Enter the agreed total price',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: _submitting ? null : _generate,
                        icon: const Icon(Icons.qr_code_2),
                        label: Text(
                          _submitting ? 'Generating…' : 'Generate QR',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Recent charges',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          if (widget.store.laundryCharges.isEmpty)
            const CanteenSurface(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 22),
                  child: Text('No laundry charges created yet.'),
                ),
              ),
            )
          else
            for (final charge in widget.store.laundryCharges.take(20))
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: CanteenSurface(
                  child: Row(
                    children: [
                      Icon(
                        charge.serviceType == LaundryServiceType.wash
                            ? Icons.local_laundry_service_outlined
                            : Icons.iron_outlined,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              charge.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '${charge.quantity.toStringAsFixed(charge.unitLabel == 'kg' ? 1 : 0)} ${charge.unitLabel} · ${charge.status.name}',
                              style: const TextStyle(color: AppColors.muted),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        formatCurrency(charge.total),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
