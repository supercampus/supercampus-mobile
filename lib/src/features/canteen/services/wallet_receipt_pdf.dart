import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../data/wallet_transaction_detail.dart';

/// Builds the downloadable PDF receipt for one wallet transaction.
///
/// White page, one accent (the brand purple), and only data the transaction
/// actually carries. Poppins is embedded because the PDF base fonts have no
/// rupee sign.
class WalletReceiptPdf {
  const WalletReceiptPdf._();

  static final PdfColor _accent = PdfColor.fromHex('#7B42F6');
  static const PdfColor _ink = PdfColor.fromInt(0xFF15161A);
  static const PdfColor _muted = PdfColor.fromInt(0xFF6B6F7A);
  static const PdfColor _rule = PdfColor.fromInt(0xFFE4E5EA);

  static Future<({pw.Font regular, pw.Font medium})> loadFonts() async {
    final regular = await rootBundle.load('assets/fonts/Poppins-Regular.ttf');
    final medium = await rootBundle.load('assets/fonts/Poppins-Medium.ttf');
    return (regular: pw.Font.ttf(regular), medium: pw.Font.ttf(medium));
  }

  static String money(double value) => NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  ).format(value);

  static String dateTime(DateTime value) =>
      DateFormat('d MMM yyyy, h:mm a').format(value);

  static Future<Uint8List> build(
    WalletTransactionDetail detail, {
    required pw.Font regular,
    required pw.Font medium,
  }) async {
    final document = pw.Document(
      title: 'SuperCampus receipt ${detail.receiptNumber}',
      author: 'SuperCampus',
      theme: pw.ThemeData.withFont(base: regular, bold: medium),
    );
    final total = detail.amount.abs();
    final merchant = detail.shopName;

    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(44, 44, 44, 36),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'SuperCampus',
                        style: pw.TextStyle(
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                          color: _accent,
                        ),
                      ),
                      if (detail.institutionName != null)
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(top: 2),
                          child: pw.Text(
                            detail.institutionName!,
                            style: const pw.TextStyle(
                              fontSize: 10,
                              color: _muted,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Receipt',
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: _ink,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    _meta('Receipt no.', detail.receiptNumber),
                    _meta('Date', dateTime(detail.createdAt)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 18),
            pw.Container(height: 2, color: _accent),
            pw.SizedBox(height: 20),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: _block('Billed to', [
                    if (detail.customerName != null) detail.customerName!,
                    if (detail.customerNumber != null)
                      'Campus ID: ${detail.customerNumber}',
                    if (detail.customerEmail != null) detail.customerEmail!,
                  ]),
                ),
                pw.SizedBox(width: 24),
                pw.Expanded(
                  child: _block('Merchant', [
                    merchant ?? detail.description,
                    if (detail.institutionName != null) detail.institutionName!,
                  ]),
                ),
              ],
            ),
            pw.SizedBox(height: 24),
            _itemsTable(detail),
            pw.SizedBox(height: 10),
            pw.Row(
              children: [
                pw.Spacer(),
                pw.Container(
                  width: 220,
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: _accent, width: 1),
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Row(
                    children: [
                      pw.Text(
                        detail.isCredit ? 'Total credited' : 'Total paid',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          color: _ink,
                        ),
                      ),
                      pw.Spacer(),
                      pw.Text(
                        money(total),
                        style: pw.TextStyle(
                          fontSize: 13,
                          fontWeight: pw.FontWeight.bold,
                          color: _accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 26),
            pw.Text(
              'Payment details',
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: _ink,
              ),
            ),
            pw.SizedBox(height: 6),
            ..._paymentRows(detail),
            pw.Spacer(),
            pw.Container(height: 0.6, color: _rule),
            pw.SizedBox(height: 8),
            pw.Text(
              'This is a computer-generated receipt.',
              style: const pw.TextStyle(fontSize: 9, color: _muted),
            ),
          ],
        ),
      ),
    );
    return document.save();
  }

  static List<pw.Widget> _paymentRows(WalletTransactionDetail detail) {
    final rows = <(String, String)>[
      ('Type', detail.kind.label),
      if (detail.paymentMethod != null)
        ('Payment method', detail.paymentMethod!),
      ('Transaction ID', detail.id),
      ('Status', detail.statusLabel),
      ('Date & time', dateTime(detail.createdAt)),
      if (detail.order != null) ('Order', '#${detail.order!.displayNumber}'),
      if (detail.paymentId != null) ('Razorpay payment ID', detail.paymentId!),
      if (detail.gatewayOrderId != null)
        ('Razorpay order ID', detail.gatewayOrderId!),
      if (detail.balanceAfter != null)
        ('Wallet balance after', money(detail.balanceAfter!)),
    ];
    return [
      for (final (label, value) in rows)
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 3.5),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(
                width: 150,
                child: pw.Text(
                  label,
                  style: const pw.TextStyle(fontSize: 10, color: _muted),
                ),
              ),
              pw.Expanded(
                child: pw.Text(
                  value,
                  style: const pw.TextStyle(fontSize: 10, color: _ink),
                ),
              ),
            ],
          ),
        ),
    ];
  }

  static pw.Widget _itemsTable(WalletTransactionDetail detail) {
    final rows = <List<String>>[];
    final order = detail.order;
    final laundry = detail.laundry;
    if (order != null && order.lines.isNotEmpty) {
      for (final line in order.lines) {
        rows.add([
          line.name,
          '${line.quantity}',
          money(line.unitPrice),
          money(line.total),
        ]);
      }
    } else if (laundry != null) {
      final quantity = _quantity(laundry.quantity);
      rows.add([
        laundry.description == null
            ? laundry.name
            : '${laundry.name} (${laundry.description})',
        laundry.unitLabel.isEmpty ? quantity : '$quantity ${laundry.unitLabel}',
        laundry.unitPrice == null ? '' : money(laundry.unitPrice!),
        money(laundry.total),
      ]);
    } else {
      final amount = detail.amount.abs();
      rows.add([detail.description, '1', money(amount), money(amount)]);
    }

    pw.Widget cell(
      String text, {
      bool header = false,
      pw.TextAlign align = pw.TextAlign.left,
    }) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: header ? 9 : 10,
          fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: header ? _muted : _ink,
        ),
      ),
    );

    return pw.Table(
      columnWidths: const {
        0: pw.FlexColumnWidth(4),
        1: pw.FlexColumnWidth(1.2),
        2: pw.FlexColumnWidth(1.8),
        3: pw.FlexColumnWidth(1.8),
      },
      border: const pw.TableBorder(
        horizontalInside: pw.BorderSide(color: _rule, width: 0.6),
        bottom: pw.BorderSide(color: _rule, width: 0.6),
      ),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: _ink, width: 0.8)),
          ),
          children: [
            cell('ITEM', header: true),
            cell('QTY', header: true, align: pw.TextAlign.right),
            cell('RATE', header: true, align: pw.TextAlign.right),
            cell('AMOUNT', header: true, align: pw.TextAlign.right),
          ],
        ),
        for (final row in rows)
          pw.TableRow(
            children: [
              cell(row[0]),
              cell(row[1], align: pw.TextAlign.right),
              cell(row[2], align: pw.TextAlign.right),
              cell(row[3], align: pw.TextAlign.right),
            ],
          ),
      ],
    );
  }

  static pw.Widget _meta(String label, String value) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 2),
    child: pw.RichText(
      text: pw.TextSpan(
        children: [
          pw.TextSpan(
            text: '$label  ',
            style: const pw.TextStyle(fontSize: 9, color: _muted),
          ),
          pw.TextSpan(
            text: value,
            style: const pw.TextStyle(fontSize: 9, color: _ink),
          ),
        ],
      ),
    ),
  );

  static pw.Widget _block(String title, List<String> lines) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        title.toUpperCase(),
        style: pw.TextStyle(
          fontSize: 8.5,
          fontWeight: pw.FontWeight.bold,
          color: _accent,
          letterSpacing: 0.8,
        ),
      ),
      pw.SizedBox(height: 6),
      for (var i = 0; i < lines.length; i++)
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 2),
          child: pw.Text(
            lines[i],
            style: pw.TextStyle(
              fontSize: i == 0 ? 11 : 10,
              fontWeight: i == 0 ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: i == 0 ? _ink : _muted,
            ),
          ),
        ),
    ],
  );

  static String _quantity(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);
}
