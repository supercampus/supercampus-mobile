import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../features/authentication/data/auth_repository.dart';
import 'tuition_fee_repository.dart';

class FeeReceiptExporter {
  const FeeReceiptExporter();

  Future<void> save(UserSession session, StudentFeeRecord payment) async {
    final bytes = await build(session, payment);
    final reference = _text(
      payment.data['paymentReference'],
      fallback: payment.id,
    ).replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');
    await FilePicker.saveFile(
      dialogTitle: 'Save fee receipt',
      fileName: 'SuperCampus_fee_receipt_$reference.pdf',
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      bytes: bytes,
    );
  }

  Future<Uint8List> build(UserSession session, StudentFeeRecord payment) async {
    final data = payment.data;
    final amount = _number(data['amount']);
    final reference = _text(data['paymentReference'], fallback: payment.id);
    final document = pw.Document(
      title: 'SuperCampus fee receipt $reference',
      author: 'SuperCampus',
    );
    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(42),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'SuperCampus',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('#4818E8'),
                      ),
                    ),
                    pw.Text('Digital fee receipt'),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#EAF8EF'),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Text(
                    'PAYMENT VERIFIED',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('#176B39'),
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 30),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(22),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#F5F1FF'),
                borderRadius: pw.BorderRadius.circular(10),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'AMOUNT PAID',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    'INR ${amount.toStringAsFixed(2)}',
                    style: pw.TextStyle(
                      fontSize: 28,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 25),
            _row('Student', session.displayName),
            _row('Campus ID', session.idNumber ?? session.email),
            _row('Email', session.email),
            _row(
              'Fee purpose',
              _text(data['paymentPurpose'], fallback: 'Tuition fee'),
            ),
            _row('Payment reference', reference),
            _row('Razorpay order', _text(data['razorpayOrderId'])),
            _row('Receipt number', _text(data['receipt'], fallback: reference)),
            _row('Payment date', _text(data['paymentDate'])),
            _row('Method', _text(data['method'], fallback: 'Online payment')),
            pw.Spacer(),
            pw.Divider(color: PdfColors.grey300),
            pw.SizedBox(height: 8),
            pw.Text(
              'This computer-generated receipt records a payment verified by the SuperCampus server. No signature is required.',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
          ],
        ),
      ),
    );
    return document.save();
  }

  pw.Widget _row(String label, String value) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 7),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 130,
          child: pw.Text(
            label,
            style: const pw.TextStyle(color: PdfColors.grey700),
          ),
        ),
        pw.Expanded(
          child: pw.Text(
            value,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
        ),
      ],
    ),
  );
}

double _number(Object? value) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
String _text(Object? value, {String fallback = '—'}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}
