import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../../core/theme/app_theme.dart';

class MonthCalendarDialog extends StatefulWidget {
  const MonthCalendarDialog({super.key, required this.selectedDate});

  final DateTime selectedDate;

  @override
  State<MonthCalendarDialog> createState() => _MonthCalendarDialogState();
}

class _MonthCalendarDialogState extends State<MonthCalendarDialog> {
  late DateTime _focusedDay;
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    _focusedDay = widget.selectedDate;
    _selectedDay = widget.selectedDate;
  }

  Widget _buildCalendarCell(
    BuildContext context,
    DateTime date, {
    bool isSelected = false,
    bool isToday = false,
  }) {
    return Container(
      margin: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primary : Colors.transparent,
        shape: BoxShape.circle,
        border: isToday && !isSelected
            ? Border.all(color: AppColors.primary, width: 1.5)
            : null,
      ),
      alignment: Alignment.center,
      child: Text(
        '${date.day}',
        style: TextStyle(
          color: isSelected
              ? Colors.white
              : (isToday ? AppColors.primary : AppColors.ink),
          fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.w500,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TableCalendar(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              currentDay: DateTime.now(),
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
                Navigator.of(context).pop(_selectedDay);
              },
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
              ),
              calendarBuilders: CalendarBuilders(
                defaultBuilder: (context, date, _) =>
                    _buildCalendarCell(context, date),
                todayBuilder: (context, date, _) =>
                    _buildCalendarCell(context, date, isToday: true),
                selectedBuilder: (context, date, _) =>
                    _buildCalendarCell(context, date, isSelected: true),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
