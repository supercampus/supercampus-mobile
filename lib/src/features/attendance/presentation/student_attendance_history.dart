import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:table_calendar/table_calendar.dart';
import 'dart:typed_data';

class StudentAttendanceHistory extends StatefulWidget {
  final Map<String, dynamic> summary;
  final bool hasWards;
  final List<Map<String, dynamic>> wards;
  final String? selectedWard;
  final ValueChanged<String?> onWardChanged;

  const StudentAttendanceHistory({
    super.key,
    required this.summary,
    required this.hasWards,
    required this.wards,
    required this.selectedWard,
    required this.onWardChanged,
  });

  @override
  State<StudentAttendanceHistory> createState() => _StudentAttendanceHistoryState();
}

class _StudentAttendanceHistoryState extends State<StudentAttendanceHistory> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay = DateTime.now();
  DateTime? _rangeStart;
  DateTime? _rangeEnd;
  RangeSelectionMode _rangeSelectionMode = RangeSelectionMode.toggledOn;

  Future<void> _exportCsv(List<Map<String, dynamic>> records) async {
    final rows = <List<String>>[
      ['Subject', 'Date', 'Hour', 'Status'],
      for (final record in records)
        [
          record['subjectName']?.toString() ?? '',
          record['heldOn']?.toString() ?? '',
          record['periodLabel']?.toString() ?? '',
          record['status']?.toString() ?? '',
        ],
    ];
    final csvString = rows.map((row) => row.map((v) => '"${v.replaceAll('"', '""')}"').join(',')).join('\r\n');
    final bytes = Uint8List.fromList(utf8.encode(csvString));
    
    String fileName = 'attendance_report';
    if (_rangeStart != null) {
      fileName += '_${_rangeStart!.year}-${_rangeStart!.month}-${_rangeStart!.day}';
    }
    fileName += '.csv';

    await FilePicker.saveFile(
      dialogTitle: 'Save attendance report',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['csv'],
      bytes: bytes,
    );
  }

  @override
  Widget build(BuildContext context) {
    final records = (widget.summary['records'] as List? ?? const []).whereType<Map<String, dynamic>>().toList();
    
    List<Map<String, dynamic>> displayedRecords = [];
    if (_rangeStart != null && _rangeEnd != null) {
      displayedRecords = records.where((r) {
        final d = DateTime.tryParse(r['heldOn']?.toString() ?? '');
        if (d == null) return false;
        final start = DateTime(_rangeStart!.year, _rangeStart!.month, _rangeStart!.day);
        final end = DateTime(_rangeEnd!.year, _rangeEnd!.month, _rangeEnd!.day, 23, 59, 59);
        return d.isAfter(start.subtract(const Duration(days: 1))) && d.isBefore(end.add(const Duration(days: 1)));
      }).toList();
    } else if (_selectedDay != null) {
      displayedRecords = records.where((r) {
        final d = DateTime.tryParse(r['heldOn']?.toString() ?? '');
        return d != null && isSameDay(d, _selectedDay);
      }).toList();
    } else {
      displayedRecords = records;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.hasWards)
          DropdownButtonFormField<String>(
            initialValue: widget.selectedWard,
            decoration: const InputDecoration(labelText: 'Student'),
            items: [
              for (final ward in widget.wards)
                DropdownMenuItem(
                  value: ward['studentUserId'].toString(),
                  child: Text(ward['studentName']?.toString() ?? 'Student'),
                ),
            ],
            onChanged: widget.onWardChanged,
          ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _Metric(label: 'Attendance', value: '${widget.summary['percentage'] ?? 0}%')),
            Expanded(child: _Metric(label: 'Attended', value: '${widget.summary['attendedClasses'] ?? 0}')),
            Expanded(child: _Metric(label: 'Absent', value: '${widget.summary['absences'] ?? 0}')),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Attendance records', style: Theme.of(context).textTheme.titleLarge),
            IconButton(
              icon: const Icon(Icons.download),
              tooltip: 'Download Report',
              onPressed: displayedRecords.isEmpty ? null : () => _exportCsv(displayedRecords),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
            child: TableCalendar<Map<String, dynamic>>(
              firstDay: DateTime(DateTime.now().year - 10, 1, 1),
              lastDay: DateTime(DateTime.now().year + 10, 12, 31),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              rangeStartDay: _rangeStart,
              rangeEndDay: _rangeEnd,
              calendarFormat: CalendarFormat.month,
              availableCalendarFormats: const {CalendarFormat.month: 'Month'},
              rangeSelectionMode: _rangeSelectionMode,
              eventLoader: (day) => records.where((r) {
                final d = DateTime.tryParse(r['heldOn']?.toString() ?? '');
                return d != null && isSameDay(d, day);
              }).toList(),
              onDaySelected: (selectedDay, focusedDay) {
                if (!isSameDay(_selectedDay, selectedDay)) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                    _rangeStart = null;
                    _rangeEnd = null;
                    _rangeSelectionMode = RangeSelectionMode.toggledOff;
                  });
                }
              },
              onRangeSelected: (start, end, focusedDay) {
                setState(() {
                  _selectedDay = null;
                  _focusedDay = focusedDay;
                  _rangeStart = start;
                  _rangeEnd = end;
                  _rangeSelectionMode = RangeSelectionMode.toggledOn;
                });
              },
              onPageChanged: (focusedDay) {
                setState(() {
                  _focusedDay = focusedDay;
                });
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (displayedRecords.isEmpty)
          const ListTile(title: Text('No records found for selected period.')),
        for (final record in displayedRecords)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              record['status'] == 'present'
                  ? Icons.check_circle
                  : Icons.cancel_outlined,
            ),
            title: Text(record['subjectName']?.toString() ?? 'Class'),
            subtitle: Text(
              '${record['heldOn'] ?? ''}  ${record['periodLabel'] ?? ''}',
            ),
            trailing: Text(record['status']?.toString().toUpperCase() ?? ''),
          ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w500)),
        Text(label, style: const TextStyle(color: Colors.black54, fontSize: 13)),
      ],
    );
  }
}
