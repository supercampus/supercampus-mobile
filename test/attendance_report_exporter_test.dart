import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/features/attendance/services/attendance_report_exporter.dart';

void main() {
  const exporter = AttendanceReportExporter();
  const session = <String, dynamic>{
    'subjectName': 'Operating Systems',
    'heldOn': '2026-09-02',
    'periodLabel': 'Period 1',
  };
  const entries = <Map<String, dynamic>>[
    {
      'studentNumber': 'MEC26AI001',
      'studentName': 'Priya Kumar',
      'status': 'present',
      'markedAt': '2026-09-02T09:05:00Z',
    },
  ];

  test('creates a CSV report with student attendance', () {
    final text = utf8.decode(exporter.buildCsv(entries));
    expect(text, contains('MEC26AI001'));
    expect(text, contains('Priya Kumar'));
    expect(text, contains('present'));
  });

  test('creates a native XLSX workbook', () {
    final bytes = exporter.buildXlsx(session, entries);
    expect(bytes.take(2), [0x50, 0x4b]);
    expect(bytes.length, greaterThan(1000));
  });

  test('creates a PDF attendance report', () async {
    final bytes = await exporter.buildPdf(session, entries);
    expect(ascii.decode(bytes.take(4).toList()), '%PDF');
    expect(bytes.length, greaterThan(1000));
  });
}
