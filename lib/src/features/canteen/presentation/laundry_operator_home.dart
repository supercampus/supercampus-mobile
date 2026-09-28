import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/user_facing_error.dart';
import '../../../core/widgets/campus_nav_bar.dart';
import '../../../core/widgets/module_navigation_buttons.dart';
import '../data/canteen_models.dart';
import 'laundry_workspace_nav.dart';
import 'widgets/canteen_surface.dart';

/// The laundry counter's workspace: the wash rate, a form that turns a bundle
/// of clothes into a payment QR, the charges still waiting on a student, and
/// the full charge history.
class LaundryOperatorHome extends StatefulWidget {
  const LaundryOperatorHome({
    super.key,
    required this.store,
    required this.onExitModule,
    required this.onRefresh,
    required this.onUpdatePrice,
    required this.onCreateCharge,
    required this.onCancelCharge,
    this.onShopMode,
    this.isMainHome = false,
    this.onProfileTap,
    this.photoUrl,
    this.nav,
  });

  final CanteenStore store;

  /// Switches the operator to Shop mode, where they buy like any student.
  final VoidCallback? onShopMode;
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

  /// Voids a charge the student has not paid yet.
  final Future<void> Function(LaundryCharge charge) onCancelCharge;

  /// Whether this workspace is the account's home screen, under the host's
  /// floating bottom bar, rather than a module opened on top of it.
  final bool isMainHome;
  final VoidCallback? onProfileTap;
  final String? photoUrl;

  /// Lets the host's bottom bar switch between Home and History.
  final LaundryWorkspaceNav? nav;

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
  var _section = LaundrySection.home;

  /// The latest charges, so an open QR sheet follows the server live.
  late final ValueNotifier<List<LaundryCharge>> _charges = ValueNotifier(
    widget.store.laundryCharges,
  );

  @override
  void initState() {
    super.initState();
    widget.nav?.attach(_showSection);
  }

  @override
  void didUpdateWidget(LaundryOperatorHome oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.nav != widget.nav) {
      oldWidget.nav?.detach(_showSection);
      widget.nav?.attach(_showSection);
    }
    if (!identical(oldWidget.store.laundryCharges, widget.store.laundryCharges)) {
      _charges.value = widget.store.laundryCharges;
    }
  }

  @override
  void dispose() {
    widget.nav?.detach(_showSection);
    _charges.dispose();
    _name.dispose();
    _description.dispose();
    _quantity.dispose();
    _price.dispose();
    super.dispose();
  }

  void _showSection(LaundrySection section) {
    if (!mounted) return;
    setState(() => _section = section);
    widget.nav?.report(section);
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
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
          decoration: const InputDecoration(prefixText: '₹ ', hintText: 'Price'),
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
      if (mounted) _showSnack(userFacingError(error));
    }
  }

  Future<void> _generate() async {
    if (!_formKey.currentState!.validate()) return;
    if (_type == LaundryServiceType.wash &&
        widget.store.laundryPricePerKg <= 0) {
      _showSnack('Set the wash price per kg first.');
      return;
    }
    FocusScope.of(context).unfocus();
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
      setState(() => _submitting = false);
      await _openCharge(charge);
    } catch (error) {
      if (mounted) _showSnack(userFacingError(error));
    } finally {
      if (mounted && _submitting) setState(() => _submitting = false);
    }
  }

  /// Opens a charge: its QR while nobody has scanned it, then its payment
  /// state, which follows the server live while the sheet is open.
  Future<void> _openCharge(LaundryCharge charge) async {
    final cancelled = await showLaundryChargeSheet(
      context,
      charge: charge,
      charges: _charges,
      onRefresh: widget.onRefresh,
      onCancel: widget.onCancelCharge,
    );
    if (cancelled == true && mounted) _showSnack('Charge cancelled');
  }

  @override
  Widget build(BuildContext context) {
    final floatingNav = widget.nav != null;
    final bottom = floatingNav
        ? CampusNavBar.heightFor(context) +
              MediaQuery.paddingOf(context).bottom +
              28
        : 32.0;
    final padding = EdgeInsets.fromLTRB(16, 8, 16, bottom);
    return Scaffold(
      backgroundColor: context.palette.canvas,
      appBar: AppBar(
        backgroundColor: context.palette.canvas,
        surfaceTintColor: Colors.transparent,
        titleSpacing: widget.isMainHome ? null : 0,
        leading: widget.isMainHome
            ? null
            : ModuleBackButton(onPressed: widget.onExitModule),
        automaticallyImplyLeading: !widget.isMainHome,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _section == LaundrySection.history
                  ? 'Charge history'
                  : 'Campus Laundry',
            ),
            Text(
              _section == LaundrySection.history
                  ? 'Every QR this counter has raised'
                  : 'Create student payment QR',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: context.palette.inkSecondary,
              ),
            ),
          ],
        ),
        actions: [
          // Without the host's bottom bar, History needs a way in up here.
          if (!floatingNav)
            IconButton(
              tooltip: _section == LaundrySection.history
                  ? 'Back to counter'
                  : 'Charge history',
              onPressed: () => _showSection(
                _section == LaundrySection.history
                    ? LaundrySection.home
                    : LaundrySection.history,
              ),
              icon: Icon(
                _section == LaundrySection.history
                    ? Icons.local_laundry_service_outlined
                    : Icons.history,
              ),
            ),
          if (widget.onShopMode != null)
            TextButton.icon(
              onPressed: widget.onShopMode,
              icon: const Icon(Icons.shopping_bag_outlined, size: 18),
              label: const Text('Shop'),
            ),
          if (widget.onProfileTap != null)
            Padding(
              padding: const EdgeInsets.only(right: 12, left: 4),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: widget.onProfileTap,
                child: CircleAvatar(
                  radius: 17,
                  backgroundColor: context.palette.brandSoft,
                  backgroundImage:
                      (widget.photoUrl != null && widget.photoUrl!.isNotEmpty)
                      ? NetworkImage(widget.photoUrl!)
                      : null,
                  child: (widget.photoUrl == null || widget.photoUrl!.isEmpty)
                      ? Icon(
                          Icons.person,
                          size: 20,
                          color: context.palette.brandInk,
                        )
                      : null,
                ),
              ),
            )
          else
            const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: widget.onRefresh,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: _section == LaundrySection.history
                ? _historyList(padding)
                : _homeList(padding),
          ),
        ),
      ),
    );
  }

  Widget _homeList(EdgeInsets padding) {
    final charges = widget.store.laundryCharges;
    final open = [for (final charge in charges) if (charge.isOpen) charge];
    final now = DateTime.now();
    final paidToday = [
      for (final charge in charges)
        if (charge.status == LaundryChargeStatus.paid &&
            _sameDay((charge.paidAt ?? charge.createdAt).toLocal(), now))
          charge,
    ];
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: padding,
      children: [
        _RateCard(
          pricePerKg: widget.store.laundryPricePerKg,
          onChange: _setRate,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatTile(
                label: 'Awaiting payment',
                value: '${open.length}',
                caption: formatCurrency(
                  open.fold(0.0, (sum, charge) => sum + charge.total),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatTile(
                label: 'Collected today',
                value: formatCurrency(
                  paidToday.fold(0.0, (sum, charge) => sum + charge.total),
                ),
                caption:
                    '${paidToday.length} payment${paidToday.length == 1 ? '' : 's'}',
              ),
            ),
          ],
        ),
        const _SectionHeader(title: 'New charge'),
        _chargeForm(),
        _SectionHeader(
          title: 'Pending',
          trailing: open.isEmpty ? null : '${open.length}',
        ),
        if (open.isEmpty)
          const _EmptyGroup(
            icon: Icons.qr_code_2,
            title: 'Nothing waiting',
            message:
                'Charges stay here, with their QR, until the student pays.',
          )
        else
          _ChargeGroup(charges: open, onTap: _openCharge),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _showSection(LaundrySection.history),
            icon: const Icon(Icons.history, size: 18),
            label: const Text('See all charges'),
          ),
        ),
      ],
    );
  }

  Widget _historyList(EdgeInsets padding) {
    final charges = widget.store.laundryCharges;
    final groups = <(String, List<LaundryCharge>)>[
      ('Pending', [for (final c in charges) if (c.isOpen) c]),
      (
        'Paid',
        [for (final c in charges) if (c.status == LaundryChargeStatus.paid) c],
      ),
      (
        'Cancelled',
        [
          for (final c in charges)
            if (c.status == LaundryChargeStatus.cancelled) c,
        ],
      ),
    ];
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: padding,
      children: [
        if (charges.isEmpty) ...[
          const SizedBox(height: 24),
          const _EmptyGroup(
            icon: Icons.receipt_long_outlined,
            title: 'No charges yet',
            message:
                'Every laundry QR you create appears here with its payment status.',
          ),
        ] else
          for (final (title, group) in groups)
            if (group.isNotEmpty) ...[
              _SectionHeader(title: title, trailing: '${group.length}'),
              _ChargeGroup(
                charges: group.take(100).toList(growable: false),
                onTap: _openCharge,
              ),
            ],
      ],
    );
  }

  Widget _chargeForm() {
    final quantity = double.tryParse(_quantity.text.trim()) ?? 0;
    final washTotal = quantity * widget.store.laundryPricePerKg;
    final ironTotal = double.tryParse(_price.text.trim()) ?? 0;
    final total = _type == LaundryServiceType.wash ? washTotal : ironTotal;
    return CanteenSurface(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<LaundryServiceType>(
              showSelectedIcon: false,
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
              onSelectionChanged: (value) =>
                  setState(() => _type = value.first),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'Student or bundle name',
              ),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Enter a name' : null,
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
                suffixText: _type == LaundryServiceType.wash ? 'kg' : 'clothes',
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
                onChanged: (_) => setState(() {}),
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
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              maxLines: 2,
              minLines: 1,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                hintText: 'Colour, room, instructions…',
              ),
            ),
            const SizedBox(height: 16),
            Divider(height: 1, color: context.palette.divider),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Total',
                    style: TextStyle(color: context.palette.inkSecondary),
                  ),
                ),
                Text(
                  formatCurrency(total),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: _submitting ? null : _generate,
              icon: const Icon(Icons.qr_code_2),
              label: Text(_submitting ? 'Generating…' : 'Generate QR'),
            ),
          ],
        ),
      ),
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

/// Shows [charge] in a sheet that follows [charges] live. Resolves to true
/// when the operator cancelled the charge from it.
///
/// While the sheet is open it also asks for a refresh every few seconds, in
/// case a realtime event is missed.
Future<bool?> showLaundryChargeSheet(
  BuildContext context, {
  required LaundryCharge charge,
  required ValueListenable<List<LaundryCharge>> charges,
  required Future<void> Function() onRefresh,
  required Future<void> Function(LaundryCharge charge) onCancel,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: context.palette.surfaceRaised,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => LaundryChargeSheet(
      charge: charge,
      charges: charges,
      onRefresh: onRefresh,
      onCancel: onCancel,
    ),
  );
}

/// One laundry charge as the counter sees it:
///
/// * nobody has scanned it — its QR with **Cancel** and **Done**;
/// * a student scanned it — **Pending payment**;
/// * the student paid — **Payment successful**;
/// * the counter voided it — **Charge cancelled**.
class LaundryChargeSheet extends StatefulWidget {
  const LaundryChargeSheet({
    super.key,
    required this.charge,
    required this.charges,
    required this.onRefresh,
    required this.onCancel,
    this.pollInterval = const Duration(seconds: 5),
  });

  /// The charge as it was when the sheet opened.
  final LaundryCharge charge;

  /// The counter's latest charges; the sheet shows its charge from here.
  final ValueListenable<List<LaundryCharge>> charges;
  final Future<void> Function() onRefresh;
  final Future<void> Function(LaundryCharge charge) onCancel;
  final Duration pollInterval;

  @override
  State<LaundryChargeSheet> createState() => _LaundryChargeSheetState();
}

class _LaundryChargeSheetState extends State<LaundryChargeSheet> {
  Timer? _poll;
  var _cancelling = false;

  /// Kept so the QR is still at hand when a reload no longer carries it.
  String? _qrPayload;

  @override
  void initState() {
    super.initState();
    _qrPayload = widget.charge.qrPayload;
    widget.charges.addListener(_changed);
    if (widget.charge.isOpen) {
      _poll = Timer.periodic(widget.pollInterval, (_) async {
        if (!_current.isOpen) {
          _poll?.cancel();
          return;
        }
        try {
          await widget.onRefresh();
        } catch (_) {
          // The next tick, or a realtime event, tries again.
        }
      });
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    widget.charges.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  LaundryCharge get _current {
    for (final charge in widget.charges.value) {
      if (charge.id == widget.charge.id) return charge;
    }
    return widget.charge;
  }

  Future<void> _cancel(LaundryCharge charge) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this charge?'),
        content: Text(
          'The QR for ${formatCurrency(charge.total)} stops working and the '
          'student can no longer pay it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: context.palette.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel charge'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _cancelling = true);
    try {
      await widget.onCancel(charge);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _cancelling = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(userFacingError(error)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final charge = _current;
    _qrPayload ??= charge.qrPayload;
    final p = context.palette;
    final Widget state = switch (charge.status) {
      LaundryChargeStatus.pending => _QrState(
        key: const ValueKey('laundry-qr'),
        payload: _qrPayload,
      ),
      LaundryChargeStatus.claimed => _StatusState(
        key: const ValueKey('laundry-claimed'),
        icon: Icons.hourglass_top_rounded,
        color: p.warning,
        background: p.warningSoft,
        title: 'Pending payment',
        message:
            'A student scanned this QR. It is paid once they confirm with '
            'their wallet PIN.',
      ),
      LaundryChargeStatus.paid => _StatusState(
        key: const ValueKey('laundry-paid'),
        icon: Icons.check_circle_rounded,
        color: p.success,
        background: p.successSoft,
        title: 'Payment successful',
        message: charge.paidAt == null
            ? 'Paid from the student\'s laundry wallet.'
            : 'Paid from the student\'s laundry wallet at '
                  '${formatTime(charge.paidAt!.toLocal())}.',
      ),
      LaundryChargeStatus.cancelled => _StatusState(
        key: const ValueKey('laundry-cancelled'),
        icon: Icons.block_rounded,
        color: p.inkSecondary,
        background: p.surfaceSunken,
        title: 'Charge cancelled',
        message: 'This QR no longer works.',
      ),
    };
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: p.borderStrong,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Laundry payment QR',
            style: TextStyle(color: p.inkSecondary, fontSize: 13),
          ),
          const SizedBox(height: 2),
          Text(
            charge.name,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            '${_chargeQuantity(charge)} · ${formatCurrency(charge.total)}',
            style: TextStyle(color: p.inkSecondary),
          ),
          const SizedBox(height: 18),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: state,
          ),
          const SizedBox(height: 20),
          if (charge.status == LaundryChargeStatus.pending)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      foregroundColor: p.danger,
                    ),
                    onPressed: _cancelling ? null : () => _cancel(charge),
                    child: Text(_cancelling ? 'Cancelling…' : 'Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: _cancelling
                        ? null
                        : () => Navigator.of(context).pop(false),
                    child: const Text('Done'),
                  ),
                ),
              ],
            )
          else ...[
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Close'),
            ),
            if (charge.status == LaundryChargeStatus.claimed) ...[
              const SizedBox(height: 4),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: p.danger),
                onPressed: _cancelling ? null : () => _cancel(charge),
                child: Text(_cancelling ? 'Cancelling…' : 'Cancel charge'),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _QrState extends StatelessWidget {
  const _QrState({super.key, required this.payload});

  final String? payload;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            // Payment QR stays dark-on-white in both themes.
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: p.border),
          ),
          child: payload == null
              ? SizedBox(
                  width: 220,
                  height: 220,
                  child: Center(
                    child: Text(
                      'This older charge has no QR on file. Cancel it and '
                      'create a new one.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ),
                )
              : QrImageView(
                  data: payload!,
                  size: 220,
                  backgroundColor: Colors.white,
                ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.qr_code_scanner_rounded, size: 16, color: p.inkTertiary),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Waiting for the student to scan',
                style: TextStyle(color: p.inkSecondary, fontSize: 13),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatusState extends StatelessWidget {
  const _StatusState({
    super.key,
    required this.icon,
    required this.color,
    required this.background,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final Color color;
  final Color background;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 26),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, size: 48, color: color),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.palette.inkSecondary),
          ),
        ],
      ),
    );
  }
}

class _RateCard extends StatelessWidget {
  const _RateCard({required this.pricePerKg, required this.onChange});

  final double pricePerKg;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final configured = pricePerKg > 0;
    return CanteenSurface(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: p.brandSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.local_laundry_service, color: p.brandInk),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Wash rate',
                  style: TextStyle(color: p.inkSecondary, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  configured
                      ? '${formatCurrency(pricePerKg)} per kg'
                      : 'Not set yet',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: configured ? p.ink : p.warning,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onChange,
            child: Text(configured ? 'Change' : 'Set rate'),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.caption,
  });

  final String label;
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return CanteenSurface(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: p.inkSecondary, fontSize: 12)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
          ),
          Text(caption, style: TextStyle(color: p.inkTertiary, fontSize: 12)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
          ),
          if (trailing != null)
            Text(
              trailing!,
              style: TextStyle(
                color: context.palette.inkSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyGroup extends StatelessWidget {
  const _EmptyGroup({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return CanteenSurface(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        children: [
          Icon(icon, size: 32, color: p.inkTertiary),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: p.inkSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

/// Charges as one grouped card, a divider between rows.
class _ChargeGroup extends StatelessWidget {
  const _ChargeGroup({required this.charges, required this.onTap});

  final List<LaundryCharge> charges;
  final ValueChanged<LaundryCharge> onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return CanteenSurface(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < charges.length; i++) ...[
            if (i > 0)
              Divider(height: 1, indent: 64, color: p.divider),
            _ChargeRow(charge: charges[i], onTap: () => onTap(charges[i])),
          ],
        ],
      ),
    );
  }
}

class _ChargeRow extends StatelessWidget {
  const _ChargeRow({required this.charge, required this.onTap});

  final LaundryCharge charge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final (label, color, background) = switch (charge.status) {
      LaundryChargeStatus.pending => ('Not scanned', p.info, p.infoSoft),
      LaundryChargeStatus.claimed => ('Pending payment', p.warning, p.warningSoft),
      LaundryChargeStatus.paid => ('Paid', p.success, p.successSoft),
      LaundryChargeStatus.cancelled => (
        'Cancelled',
        p.inkSecondary,
        p.surfaceSunken,
      ),
    };
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: p.surfaceSunken,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                charge.status == LaundryChargeStatus.pending
                    ? Icons.qr_code_2
                    : charge.serviceType == LaundryServiceType.wash
                    ? Icons.local_laundry_service_outlined
                    : Icons.iron_outlined,
                size: 20,
                color: p.brandInk,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    charge.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_chargeQuantity(charge)} · ${_timestamp(charge.createdAt)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: p.inkSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatCurrency(charge.total),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: background,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
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

String _chargeQuantity(LaundryCharge charge) {
  final amount = charge.quantity.toStringAsFixed(
    charge.unitLabel == 'kg' ? 1 : 0,
  );
  final service = charge.serviceType == LaundryServiceType.wash
      ? 'Wash'
      : 'Ironing';
  return '$service · $amount ${charge.unitLabel}';
}

String _timestamp(DateTime value) {
  final local = value.toLocal();
  final now = DateTime.now();
  final today =
      local.year == now.year && local.month == now.month && local.day == now.day;
  return today
      ? 'Today, ${formatTime(local)}'
      : '${formatShortDate(local)}, ${formatTime(local)}';
}
