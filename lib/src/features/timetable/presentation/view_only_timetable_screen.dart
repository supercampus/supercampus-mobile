import 'package:flutter/material.dart';

import 'package:intl/intl.dart';
import '../../authentication/data/auth_repository.dart';
import '../data/mock_timetable_repository.dart';
import 'widgets/timetable_grid_view.dart';
import 'widgets/weekly_date_strip.dart';
import 'widgets/month_calendar_dialog.dart';

class ViewOnlyTimetableScreen extends StatefulWidget {
  const ViewOnlyTimetableScreen({
    super.key,
    required this.session,
    required this.repository,
  });

  final UserSession session;
  final MockTimetableRepository repository;

  @override
  State<ViewOnlyTimetableScreen> createState() =>
      _ViewOnlyTimetableScreenState();
}

class _ViewOnlyTimetableScreenState extends State<ViewOnlyTimetableScreen> {
  DateTime _selectedDate = DateTime.now();
  late String _targetClass;

  @override
  void initState() {
    super.initState();
    _targetClass = widget.session.departmentOrWard ?? 'CS-3A';
    // Fallback if departmentOrWard doesn't look like a class name
    if (!_targetClass.contains('CS') && !_targetClass.contains('-')) {
      _targetClass = 'CS-3A';
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.repository.getConfig();
    final entries = widget.repository.getEntriesForClass(_targetClass);
    final selectedDayStr = DateFormat('EEEE').format(_selectedDate);

    final activeSubs = widget.repository
        .getSubstitutions()
        .where((s) => s.className == _targetClass && s.status == 'Approved' && s.dayOfWeek == selectedDayStr)
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Schedule',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            IconButton.filledTonal(
              onPressed: () async {
                final date = await showDialog<DateTime>(
                  context: context,
                  builder: (ctx) => MonthCalendarDialog(selectedDate: _selectedDate),
                );
                if (date != null) {
                  setState(() => _selectedDate = date);
                }
              },
              icon: const Icon(Icons.calendar_month_outlined),
            ),
          ],
        ),
        const SizedBox(height: 12),
        WeeklyDateStrip(
          selectedDate: _selectedDate,
          onDateSelected: (date) => setState(() => _selectedDate = date),
        ),

        const SizedBox(height: 16),



        // Interactive Schedule Grid View
        TimetableGridView(
          entries: entries,
          workingDays: config.workingDays,
          selectedDay: DateFormat('EEEE').format(_selectedDate),
          selectedDate: _selectedDate,
          activeSubs: activeSubs,
          onDaySelected: (_) {},
          isEditable: false,
          showDayFilterChips: false,
        ),
      ],
    );
  }
}
