import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/timetable_models.dart';

class TimetableGridView extends StatefulWidget {
  const TimetableGridView({
    super.key,
    required this.entries,
    required this.workingDays,
    required this.selectedDay,
    required this.onDaySelected,
    this.isEditable = false,
    this.onEditEntry,
    this.onDeleteEntry,
    this.onAddEntryForSlot,
  });

  final List<TimetableEntry> entries;
  final List<String> workingDays;
  final String selectedDay;
  final ValueChanged<String> onDaySelected;
  final bool isEditable;
  final ValueChanged<TimetableEntry>? onEditEntry;
  final ValueChanged<String>? onDeleteEntry;
  final Function(String day, int periodIndex)? onAddEntryForSlot;

  @override
  State<TimetableGridView> createState() => _TimetableGridViewState();
}

class _TimetableGridViewState extends State<TimetableGridView> {
  bool _isWeeklyGrid = false;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final dayEntries = widget.entries
        .where((e) => e.dayOfWeek == widget.selectedDay)
        .where((e) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return e.subjectName.toLowerCase().contains(q) ||
          e.subjectCode.toLowerCase().contains(q) ||
          e.facultyName.toLowerCase().contains(q) ||
          e.className.toLowerCase().contains(q);
    }).toList();

    dayEntries.sort((a, b) => a.periodIndex.compareTo(b.periodIndex));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Controls Bar
        Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: widget.workingDays.map((day) {
                    final isSelected = day == widget.selectedDay;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        selected: isSelected,
                        label: Text(day),
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : AppColors.ink,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w400,
                        ),
                        onSelected: (_) => widget.onDaySelected(day),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: _isWeeklyGrid ? 'List View' : 'Weekly Overview',
              icon: Icon(_isWeeklyGrid ? Icons.view_agenda : Icons.grid_on),
              onPressed: () => setState(() => _isWeeklyGrid = !_isWeeklyGrid),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Search box
        TextField(
          decoration: InputDecoration(
            hintText: 'Search subject, code, faculty or class...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() => _searchQuery = ''),
                  )
                : null,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
          ),
          onChanged: (val) => setState(() => _searchQuery = val),
        ),

        const SizedBox(height: 16),

        if (_isWeeklyGrid)
          _buildWeeklyMatrix(context)
        else if (dayEntries.isEmpty)
          _buildEmptyState(context)
        else
          ...dayEntries.map((entry) => _buildEntryCard(context, entry)),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.event_note, size: 56, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            'No classes scheduled for ${widget.selectedDay}',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          Text(
            widget.isEditable
                ? 'Tap "Add Period" to manually assign a subject slot.'
                : 'Enjoy your free day or check back later for updates.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          if (widget.isEditable && widget.onAddEntryForSlot != null) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () =>
                  widget.onAddEntryForSlot!(widget.selectedDay, 1),
              icon: const Icon(Icons.add),
              label: const Text('Add Period Slot'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEntryCard(BuildContext context, TimetableEntry entry) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: entry.categoryColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border(
            left: BorderSide(
              color: entry.categoryColor,
              width: 5,
            ),
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: entry.categoryColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Period ${entry.periodIndex} • ${entry.timeSlot}',
                        softWrap: true,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: entry.categoryColor,
                        ),
                      ),
                    ),
                    if (entry.isLab)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.purple.shade200),
                        ),
                        child: Text(
                          'LAB',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: Colors.purple.shade800,
                          ),
                        ),
                      ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.groups_outlined,
                        size: 14,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Class: ${entry.className}',
                        softWrap: true,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${entry.subjectCode} - ${entry.subjectName}',
                        softWrap: true,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.person_outline,
                            size: 15,
                            color: AppColors.muted,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              entry.facultyName,
                              softWrap: true,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (widget.isEditable) ...[
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    color: AppColors.primary,
                    onPressed: () => widget.onEditEntry?.call(entry),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    color: Colors.red,
                    onPressed: () => widget.onDeleteEntry?.call(entry.id),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyMatrix(BuildContext context) {
    final timeSlots = [
      '08:30 - 09:20 AM',
      '09:30 - 10:20 AM',
      '10:20 - 11:10 AM',
      '11:30 - 12:20 PM',
      '02:00 - 02:50 PM',
      '02:50 - 03:40 PM',
    ];

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(const Color(0xFFF0F4F8)),
          columns: [
            const DataColumn(
              label: Text('Time Slot', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            ...widget.workingDays.map(
              (day) => DataColumn(
                label: Text(
                  day,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: day == widget.selectedDay
                        ? AppColors.primary
                        : Colors.black,
                  ),
                ),
              ),
            ),
          ],
          rows: List.generate(timeSlots.length, (slotIndex) {
            final slotText = timeSlots[slotIndex];
            return DataRow(
              cells: [
                DataCell(
                  Text(
                    'P${slotIndex + 1}\n$slotText',
                    style: const TextStyle(fontSize: 11, color: AppColors.muted),
                  ),
                ),
                ...widget.workingDays.map((day) {
                  TimetableEntry? matching;
                  for (final e in widget.entries) {
                    if (e.dayOfWeek == day && e.periodIndex == slotIndex + 1) {
                      matching = e;
                      break;
                    }
                  }

                  if (matching == null) {
                    return DataCell(
                      Text(
                        '--',
                        style: TextStyle(color: Colors.grey.shade400),
                      ),
                    );
                  }

                  return DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: matching.categoryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: matching.categoryColor.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            matching.subjectCode,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: matching.categoryColor,
                            ),
                          ),
                          Text(
                            matching.className,
                            style: const TextStyle(
                              fontSize: 9,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            );
          }),
        ),
      ),
    );
  }
}
