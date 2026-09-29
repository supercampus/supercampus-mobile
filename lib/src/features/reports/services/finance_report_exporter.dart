import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../data/finance_report.dart';

/// A report too long to print; the CSV still carries every row.
class ReportTooLargeForPdf implements Exception {
  const ReportTooLargeForPdf(this.rows);

  final int rows;

  @override
  String toString() =>
      'This report has $rows rows, too many for a PDF. Download the CSV, '
      'or choose a shorter period or a single shop.';
}

/// Renders a [FinanceReport] as CSV or PDF. Both come from the same tables,
/// so the two files always agree.
class FinanceReportExporter {
  const FinanceReportExporter._();

  /// Rows beyond this make the PDF unwieldy (hundreds of pages).
  static const maxPdfRows = 10000;

  // ---------------------------------------------------------------------------
  // Cell formatting
  // ---------------------------------------------------------------------------

  static final _money = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );
  static final _plainMoney = NumberFormat.currency(
    locale: 'en_IN',
    symbol: 'Rs. ',
    decimalDigits: 2,
  );

  /// The value as a person reads it (PDF, on-screen summary).
  static String display(Object? value, String format, {bool rupee = true}) {
    if (value == null) return '';
    switch (format) {
      case 'money':
        final number = _asNumber(value);
        if (number == null) return value.toString();
        return (rupee ? _money : _plainMoney).format(number);
      case 'number':
        final number = _asNumber(value);
        if (number == null) return value.toString();
        return number == number.roundToDouble()
            ? NumberFormat.decimalPattern('en_IN').format(number.round())
            : NumberFormat('#,##,##0.##', 'en_IN').format(number);
      case 'datetime':
        final parsed = DateTime.tryParse(value.toString());
        return parsed == null
            ? value.toString()
            : DateFormat('d MMM yyyy, h:mm a').format(parsed);
      case 'date':
        final parsed = DateTime.tryParse(value.toString());
        return parsed == null
            ? value.toString()
            : DateFormat('d MMM yyyy').format(parsed);
      default:
        return value.toString();
    }
  }

  /// The value as a spreadsheet reads it: plain numbers, ISO-like times.
  static String csvValue(Object? value, String format) {
    if (value == null) return '';
    switch (format) {
      case 'money':
        final number = _asNumber(value);
        return number == null ? value.toString() : number.toStringAsFixed(2);
      case 'number':
        final number = _asNumber(value);
        if (number == null) return value.toString();
        return number == number.roundToDouble()
            ? number.round().toString()
            : number.toString();
      case 'datetime':
        // `2026-09-28T00:43:01` → `2026-09-28 00:43:01`; a label such as a
        // totals row's "Total" is left as written.
        final text = value.toString();
        return RegExp(r'^\d{4}-\d{2}-\d{2}T').hasMatch(text)
            ? text.replaceFirst('T', ' ')
            : text;
      default:
        return value.toString();
    }
  }

  static double? _asNumber(Object? value) => switch (value) {
    num() => value.toDouble(),
    String() => double.tryParse(value),
    _ => null,
  };

  // ---------------------------------------------------------------------------
  // CSV
  // ---------------------------------------------------------------------------

  /// RFC 4180 CSV: a short heading block, then each table with its title,
  /// header row, rows and total row, then the notes. CRLF line endings.
  static String csv(FinanceReport report) {
    final lines = <String>[];
    void line(List<String> cells) => lines.add(cells.map(_csvCell).join(','));

    line(['Report', report.title]);
    if (report.institutionName != null) {
      line(['Institution', report.institutionName!]);
    }
    line(['Period', report.periodLabel]);
    if (report.from.isNotEmpty) line(['From', report.from]);
    if (report.to.isNotEmpty) line(['To', report.to]);
    line(['Shop', report.shopName ?? 'All shops']);
    line(['Generated', csvValue(report.generatedAt, 'datetime')]);
    if (report.summary.isNotEmpty) {
      lines.add('');
      line(['Summary', 'Value']);
      for (final stat in report.summary) {
        line([stat.label, csvValue(stat.value, stat.format)]);
      }
    }
    for (final table in report.tables) {
      lines.add('');
      line([table.title]);
      line([for (final column in table.columns) column.label]);
      for (final row in table.rows) {
        line([
          for (final column in table.columns)
            csvValue(row[column.key], column.format),
        ]);
      }
      final totals = table.totals;
      if (totals != null) {
        line([
          for (final column in table.columns)
            csvValue(totals[column.key], column.format),
        ]);
      }
    }
    if (report.notes.isNotEmpty) {
      lines.add('');
      for (final note in report.notes) {
        line(['Note', note]);
      }
    }
    return '${lines.join('\r\n')}\r\n';
  }

  /// UTF-8 with a byte-order mark, so spreadsheet apps read names correctly.
  static Uint8List csvBytes(FinanceReport report) =>
      Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(csv(report))]);

  static String _csvCell(String value) {
    var text = value;
    // A cell starting with a formula sign runs as a formula in spreadsheet
    // apps; names and descriptions never should. Numbers are left alone.
    if (text.isNotEmpty &&
        '=+-@'.contains(text[0]) &&
        double.tryParse(text) == null) {
      text = "'$text";
    }
    if (text.contains(RegExp(r'[",\r\n]'))) {
      return '"${text.replaceAll('"', '""')}"';
    }
    return text;
  }

  // ---------------------------------------------------------------------------
  // PDF
  // ---------------------------------------------------------------------------

  static final PdfColor _accent = PdfColor.fromHex('#7B42F6');
  static const PdfColor _ink = PdfColor.fromInt(0xFF15161A);
  static const PdfColor _muted = PdfColor.fromInt(0xFF6B6F7A);
  static const PdfColor _rule = PdfColor.fromInt(0xFFE4E5EA);
  static const PdfColor _band = PdfColor.fromInt(0xFFF4F2FA);
  static const PdfColor _negative = PdfColor.fromInt(0xFFFDE7EF);

  /// Poppins carries the rupee sign, which the PDF base fonts lack.
  static Future<({pw.Font regular, pw.Font medium})> loadFonts() async {
    final regular = await rootBundle.load('assets/fonts/Poppins-Regular.ttf');
    final medium = await rootBundle.load('assets/fonts/Poppins-Medium.ttf');
    return (regular: pw.Font.ttf(regular), medium: pw.Font.ttf(medium));
  }

  /// Without [regular]/[medium] the base font is used and amounts read "Rs.".
  static Future<Uint8List> pdf(
    FinanceReport report, {
    pw.Font? regular,
    pw.Font? medium,
  }) async {
    if (report.rowCount > maxPdfRows) {
      throw ReportTooLargeForPdf(report.rowCount);
    }
    final rupee = regular != null;
    final widest = report.tables.fold<int>(
      0,
      (max, table) => table.columns.length > max ? table.columns.length : max,
    );
    final format = widest > 6 ? PdfPageFormat.a4.landscape : PdfPageFormat.a4;
    final document = pw.Document(
      title: report.title,
      author: 'SuperCampus',
      theme: regular == null
          ? null
          : pw.ThemeData.withFont(base: regular, bold: medium ?? regular),
    );

    document.addPage(
      pw.MultiPage(
        pageFormat: format,
        margin: const pw.EdgeInsets.fromLTRB(32, 32, 32, 28),
        maxPages: 1000,
        header: (context) => context.pageNumber == 1
            ? pw.SizedBox()
            : pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Text(
                  '${report.title} · ${report.periodLabel}',
                  style: const pw.TextStyle(fontSize: 8, color: _muted),
                ),
              ),
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Generated ${display(report.generatedAt, 'datetime')}',
              style: const pw.TextStyle(fontSize: 8, color: _muted),
            ),
            pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: _muted),
            ),
          ],
        ),
        build: (context) => [
          _heading(report),
          if (report.summary.isNotEmpty) ...[
            pw.SizedBox(height: 14),
            _summary(report, rupee),
          ],
          if (report.notes.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            for (final note in report.notes)
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 3),
                child: pw.Text(
                  note,
                  style: const pw.TextStyle(fontSize: 8.5, color: _muted),
                ),
              ),
          ],
          for (final table in report.tables) ...[
            pw.SizedBox(height: 16),
            pw.Text(
              table.title,
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: _ink,
              ),
            ),
            pw.SizedBox(height: 6),
            if (table.rows.isEmpty)
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: _rule),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Text(
                  report.available
                      ? 'No records in this period.'
                      : 'No records exist for this report.',
                  style: const pw.TextStyle(fontSize: 9, color: _muted),
                ),
              )
            else
              _table(table, rupee),
          ],
        ],
      ),
    );
    return document.save();
  }

  static pw.Widget _heading(FinanceReport report) {
    final meta = <String>[
      report.periodLabel,
      report.shopName ?? 'All shops',
    ].where((part) => part.isNotEmpty).join(' · ');
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                report.title,
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                  color: _ink,
                ),
              ),
              if (report.description.isNotEmpty)
                pw.Text(
                  report.description,
                  style: const pw.TextStyle(fontSize: 9.5, color: _muted),
                ),
              pw.SizedBox(height: 4),
              pw.Text(meta, style: const pw.TextStyle(fontSize: 9.5)),
            ],
          ),
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              'SuperCampus',
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                color: _accent,
              ),
            ),
            if (report.institutionName != null)
              pw.Text(
                report.institutionName!,
                style: const pw.TextStyle(fontSize: 8.5, color: _muted),
              ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _summary(FinanceReport report, bool rupee) => pw.Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final stat in report.summary)
        pw.Container(
          width: 118,
          padding: const pw.EdgeInsets.fromLTRB(10, 7, 10, 7),
          decoration: pw.BoxDecoration(
            color: _band,
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                stat.label,
                style: const pw.TextStyle(fontSize: 7.5, color: _muted),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                display(stat.value, stat.format, rupee: rupee),
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: _ink,
                ),
              ),
            ],
          ),
        ),
    ],
  );

  static pw.Widget _table(ReportTable table, bool rupee) {
    final alignments = <int, pw.Alignment>{
      for (var i = 0; i < table.columns.length; i++)
        i: table.columns[i].isNumeric
            ? pw.Alignment.centerRight
            : pw.Alignment.centerLeft,
    };
    final data = <List<String>>[
      for (final row in table.rows)
        [
          for (final column in table.columns)
            display(row[column.key], column.format, rupee: rupee),
        ],
      if (table.totals != null)
        [
          for (final column in table.columns)
            display(table.totals![column.key], column.format, rupee: rupee),
        ],
    ];
    final totalsIndex = table.totals == null ? -1 : data.length;
    // Rows the server flags (an overdrawn wallet, an overdue request) are
    // tinted; row 0 is the header, so data row i is rowNum i + 1.
    final negativeRows = <int>{
      for (var i = 0; i < table.rows.length; i++)
        if (table.rows[i][FinanceReport.toneKey] == 'negative') i + 1,
    };
    return pw.TableHelper.fromTextArray(
      headers: [for (final column in table.columns) column.label],
      data: data,
      border: null,
      headerStyle: pw.TextStyle(
        fontSize: 8,
        fontWeight: pw.FontWeight.bold,
        color: _ink,
      ),
      headerDecoration: const pw.BoxDecoration(color: _band),
      cellStyle: const pw.TextStyle(fontSize: 8, color: _ink),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      headerAlignments: alignments,
      cellAlignments: alignments,
      rowDecoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _rule, width: 0.5)),
      ),
      // Row 0 is the header; the totals row is last.
      cellDecoration: (index, data, rowNum) => rowNum == totalsIndex
          ? const pw.BoxDecoration(color: _band)
          : negativeRows.contains(rowNum)
          ? const pw.BoxDecoration(color: _negative)
          : const pw.BoxDecoration(),
    );
  }
}
