import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../data/canteen_models.dart';
import '../data/wallet_transaction_detail.dart';
import '../services/wallet_receipt_pdf.dart';

/// Loads the server's full record of one of the user's wallet transactions.
typedef WalletTransactionDetailLoader =
    Future<WalletTransactionDetail> Function(String transactionId);

/// Everything known about one wallet transaction, with its PDF receipt.
///
/// It opens at once on what the wallet already holds, then settles on the
/// server's fuller record (order lines, gateway references, balance after)
/// when that arrives. Rows whose data does not exist are left out.
class WalletTransactionDetailsScreen extends StatefulWidget {
  const WalletTransactionDetailsScreen({
    super.key,
    required this.transaction,
    required this.store,
    this.loadDetail,
  });

  final WalletTransaction transaction;
  final CanteenStore store;
  final WalletTransactionDetailLoader? loadDetail;

  @override
  State<WalletTransactionDetailsScreen> createState() =>
      _WalletTransactionDetailsScreenState();
}

class _WalletTransactionDetailsScreenState
    extends State<WalletTransactionDetailsScreen> {
  late WalletTransactionDetail _detail;
  bool _loading = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _detail = WalletTransactionDetail.fromLocal(
      widget.transaction,
      widget.store,
    );
    _load();
  }

  Future<void> _load() async {
    final loader = widget.loadDetail;
    if (loader == null) return;
    setState(() => _loading = true);
    try {
      final detail = await loader(widget.transaction.id);
      if (mounted && detail.id.isNotEmpty) setState(() => _detail = detail);
    } catch (_) {
      // The wallet's own copy is already on screen and is accurate; the
      // server record only adds to it.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _copyId() async {
    await Clipboard.setData(ClipboardData(text: _detail.id));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Transaction ID copied')));
  }

  Future<void> _downloadReceipt() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      final fonts = await WalletReceiptPdf.loadFonts();
      final bytes = await WalletReceiptPdf.build(
        _detail,
        regular: fonts.regular,
        medium: fonts.medium,
      );
      // The web starts a browser download; Android and iOS open the system
      // save dialog. Null is a cancel on native platforms only.
      final saved = await FilePicker.saveFile(
        dialogTitle: 'Save receipt',
        fileName: _detail.receiptFileName,
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
        bytes: bytes,
      );
      if (saved == null && !kIsWeb) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Receipt downloaded')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't save the receipt. Try again.")),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final detail = _detail;
    final order = detail.order;
    final laundry = detail.laundry;
    final tone = detail.isCredit ? palette.success : palette.danger;
    final toneSoft = detail.isCredit ? palette.successSoft : palette.dangerSoft;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: palette.canvas,
      appBar: AppBar(
        title: const Text('Transaction details'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: _loading
              ? const LinearProgressIndicator(minHeight: 2)
              : const SizedBox(height: 2),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          children: [
            Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: toneSoft,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    detail.isCredit ? Icons.south_west : Icons.north_east,
                    color: tone,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  formatCurrency(detail.amount, signed: true),
                  key: const Key('transaction-detail-amount'),
                  style: TextStyle(
                    color: tone,
                    fontSize: 36,
                    height: 1.1,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.8,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  detail.description,
                  textAlign: TextAlign.center,
                  style: textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: palette.successSoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        size: 14,
                        color: palette.success,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        detail.statusLabel,
                        style: TextStyle(
                          color: palette.success,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _Section(
              title: 'Details',
              children: [
                _DetailRow(label: 'Type', value: detail.kind.label),
                if (detail.shopName != null)
                  _DetailRow(
                    label: detail.kind.isTopUp ? 'Wallet' : 'Shop',
                    value: detail.shopName!,
                  ),
                _DetailRow(
                  label: 'Date',
                  value: DateFormat(
                    'EEEE, d MMMM yyyy',
                  ).format(detail.createdAt),
                ),
                _DetailRow(label: 'Time', value: formatTime(detail.createdAt)),
                _DetailRow(
                  label: 'Transaction ID',
                  value: detail.id,
                  monospace: true,
                  trailing: IconButton(
                    tooltip: 'Copy transaction ID',
                    visualDensity: VisualDensity.compact,
                    iconSize: 18,
                    color: palette.inkSecondary,
                    onPressed: _copyId,
                    icon: const Icon(Icons.copy_rounded),
                  ),
                ),
                if (order != null)
                  _DetailRow(label: 'Order', value: '#${order.displayNumber}'),
                if (order?.statusLabel != null)
                  _DetailRow(label: 'Order status', value: order!.statusLabel!),
                if (order?.fulfilmentLabel != null)
                  _DetailRow(label: 'Service', value: order!.fulfilmentLabel!),
                if (detail.paymentMethod != null)
                  _DetailRow(
                    label: 'Payment method',
                    value: detail.paymentMethod!,
                  ),
                if (detail.paymentId != null)
                  _DetailRow(
                    label: 'Razorpay payment ID',
                    value: detail.paymentId!,
                    monospace: true,
                  ),
                if (detail.gatewayOrderId != null)
                  _DetailRow(
                    label: 'Razorpay order ID',
                    value: detail.gatewayOrderId!,
                    monospace: true,
                  ),
                if (detail.balanceAfter != null)
                  _DetailRow(
                    label: 'Balance after',
                    value: formatCurrency(detail.balanceAfter!),
                  ),
              ],
            ),
            if (order != null && order.lines.isNotEmpty) ...[
              const SizedBox(height: 16),
              _Section(
                title: 'Items',
                children: [
                  for (final line in order.lines)
                    _LineRow(
                      name: line.name,
                      detail:
                          '${line.quantity} × ${formatCurrency(line.unitPrice)}',
                      amount: formatCurrency(line.total),
                    ),
                  _LineRow(
                    name: 'Total',
                    amount: formatCurrency(order.total),
                    emphasised: true,
                  ),
                ],
              ),
            ] else if (laundry != null) ...[
              const SizedBox(height: 16),
              _Section(
                title: 'Service',
                children: [
                  _LineRow(
                    name: laundry.name,
                    detail: [
                      '${_quantity(laundry.quantity)} ${laundry.unitLabel}'
                          .trim(),
                      if (laundry.unitPrice != null)
                        '× ${formatCurrency(laundry.unitPrice!)}',
                    ].join(' '),
                    amount: formatCurrency(laundry.total),
                  ),
                ],
              ),
            ],
            if (detail.customerName != null ||
                detail.customerNumber != null ||
                detail.customerEmail != null ||
                detail.institutionName != null) ...[
              const SizedBox(height: 16),
              _Section(
                title: 'Account',
                children: [
                  if (detail.customerName != null)
                    _DetailRow(label: 'Student', value: detail.customerName!),
                  if (detail.customerNumber != null)
                    _DetailRow(
                      label: 'Campus ID',
                      value: detail.customerNumber!,
                    ),
                  if (detail.customerEmail != null)
                    _DetailRow(label: 'Email', value: detail.customerEmail!),
                  if (detail.institutionName != null)
                    _DetailRow(
                      label: 'Institution',
                      value: detail.institutionName!,
                    ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _downloadReceipt,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_rounded),
              label: Text(
                _saving ? 'Preparing receipt…' : 'Download invoice (PDF)',
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _quantity(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: TextStyle(
              color: palette.inkSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: palette.border),
          ),
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    indent: 14,
                    endIndent: 14,
                    color: palette.divider,
                  ),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.trailing,
    this.monospace = false,
  });

  final String label;
  final String value;
  final Widget? trailing;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: EdgeInsets.fromLTRB(14, 12, trailing == null ? 14 : 4, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 124,
            child: Text(
              label,
              style: TextStyle(color: palette.inkSecondary, fontSize: 14),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: palette.ink,
                fontSize: monospace ? 13 : 14,
                fontWeight: FontWeight.w500,
                fontFeatures: monospace
                    ? const [FontFeature.tabularFigures()]
                    : null,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({
    required this.name,
    required this.amount,
    this.detail,
    this.emphasised = false,
  });

  final String name;
  final String? detail;
  final String amount;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: palette.ink,
                    fontSize: 14,
                    fontWeight: emphasised ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
                if (detail != null && detail!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    detail!,
                    style: TextStyle(
                      color: palette.inkSecondary,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            amount,
            style: TextStyle(
              color: palette.ink,
              fontSize: emphasised ? 15 : 14,
              fontWeight: emphasised ? FontWeight.w600 : FontWeight.w500,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
