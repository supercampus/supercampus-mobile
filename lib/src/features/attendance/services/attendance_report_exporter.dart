import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class AttendanceReportExporter {
  const AttendanceReportExporter();

  Future<void> saveCsv(
    Map<String, dynamic> session,
    List<Map<String, dynamic>> entries,
  ) async {
    await _save('csv', buildCsv(entries), session);
  }

  Uint8List buildCsv(List<Map<String, dynamic>> entries) {
    final rows = <List<String>>[
      ['Register Number', 'Student Name', 'Status', 'Marked At'],
      for (final entry in entries)
        [
          entry['studentNumber']?.toString() ?? '',
          entry['studentName']?.toString() ?? '',
          entry['status']?.toString() ?? '',
          entry['markedAt']?.toString() ?? '',
        ],
    ];
    final value = rows.map((row) => row.map(_csvCell).join(',')).join('\r\n');
    return Uint8List.fromList(utf8.encode(value));
  }

  Future<void> saveXlsx(
    Map<String, dynamic> session,
    List<Map<String, dynamic>> entries,
  ) async {
    await _save('xlsx', buildXlsx(session, entries), session);
  }

  Uint8List buildXlsx(
    Map<String, dynamic> session,
    List<Map<String, dynamic>> entries,
  ) {
    final book = Excel.createExcel();
    final sheet = book['Attendance'];
    sheet.appendRow([
      TextCellValue('Subject'),
      TextCellValue(session['subjectName']?.toString() ?? ''),
    ]);
    sheet.appendRow([
      TextCellValue('Date'),
      TextCellValue(session['heldOn']?.toString() ?? ''),
      TextCellValue('Hour'),
      TextCellValue(session['periodLabel']?.toString() ?? ''),
    ]);
    sheet.appendRow(const []);
    sheet.appendRow([
      TextCellValue('Register Number'),
      TextCellValue('Student Name'),
      TextCellValue('Status'),
      TextCellValue('Marked At'),
    ]);
    for (final entry in entries) {
      sheet.appendRow([
        TextCellValue(entry['studentNumber']?.toString() ?? ''),
        TextCellValue(entry['studentName']?.toString() ?? ''),
        TextCellValue(entry['status']?.toString().toUpperCase() ?? ''),
        TextCellValue(entry['markedAt']?.toString() ?? ''),
      ]);
    }
    return Uint8List.fromList(book.save() ?? const <int>[]);
  }

  Future<void> savePdf(
    Map<String, dynamic> session,
    List<Map<String, dynamic>> entries,
  ) async {
    await _save('pdf', await buildPdf(session, entries), session);
  }

  Future<Uint8List> buildPdf(
    Map<String, dynamic> session,
    List<Map<String, dynamic>> entries,
  ) async {
    final document = pw.Document();
    final present = entries
        .where((entry) => entry['status'] == 'present')
        .length;
    final absent = entries.where((entry) => entry['status'] == 'absent').length;
    final onDuty = entries.where((entry) => entry['status'] == 'od').length;
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (_) => [
          pw.Text(
            'SuperCampus attendance report',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            '${session['subjectName'] ?? 'Class'} | ${session['heldOn'] ?? ''} | ${session['periodLabel'] ?? ''}',
          ),
          pw.Text(
            'Present: $present   Absent: $absent   OD: $onDuty   Total: ${entries.length}',
          ),
          pw.SizedBox(height: 14),
          pw.TableHelper.fromTextArray(
            headers: const ['Register No.', 'Student', 'Status'],
            data: [
              for (final entry in entries)
                [
                  entry['studentNumber'] ?? '',
                  entry['studentName'] ?? '',
                  entry['status'] ?? '',
                ],
            ],
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          ),
        ],
      ),
    );
    return document.save();
  }

  Future<void> _save(
    String extension,
    Uint8List bytes,
    Map<String, dynamic> session,
  ) async {
    final subject = (session['subjectName']?.toString() ?? 'attendance')
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
        .toLowerCase();
    await FilePicker.saveFile(
      dialogTitle: 'Save attendance report',
      fileName: '${subject}_${session['heldOn'] ?? 'report'}.$extension',
      type: FileType.custom,
      allowedExtensions: [extension],
      bytes: bytes,
    );
  }

  String _csvCell(String value) => '"${value.replaceAll('"', '""')}"';
}
