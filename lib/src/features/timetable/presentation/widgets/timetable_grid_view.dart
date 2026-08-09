import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/timetable_models.dart';
import 'exam_detail_modal.dart';

enum PeriodStatus { present, onDuty, absent, upcoming, cancelled, ongoing }

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
    this.showDayFilterChips = true,
    this.selectedDate,
    this.activeSubs = const [],
  });

  final List<TimetableEntry> entries;
  final List<String> workingDays;
  final String selectedDay;
  final ValueChanged<String> onDaySelected;
  final bool isEditable;
  final ValueChanged<TimetableEntry>? onEditEntry;
  final ValueChanged<String>? onDeleteEntry;
  final Function(String day, int periodIndex)? onAddEntryForSlot;
  final bool showDayFilterChips;
  final DateTime? selectedDate;
  final List<FacultySubstitution> activeSubs;

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
        if (widget.showDayFilterChips)
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
          ..._buildDayListWidgets(context, dayEntries),
      ],
    );
  }

  List<Widget> _buildDayListWidgets(BuildContext context, List<TimetableEntry> dayEntries) {
    final list = <Widget>[];
    final processedPeriodIndexes = <int>{};

    for (final entry in dayEntries) {
      if (entry.isExam) {
        final startIdx = entry.startPeriodIndex ?? entry.periodIndex;
        final endIdx = entry.endPeriodIndex ?? entry.periodIndex;

        if (processedPeriodIndexes.contains(entry.periodIndex)) {
          continue;
        }

        for (int p = startIdx; p <= endIdx; p++) {
          processedPeriodIndexes.add(p);
        }

        list.add(_buildMergedExamCard(context, entry, startIdx, endIdx));
      } else {
        if (processedPeriodIndexes.contains(entry.periodIndex)) {
          continue;
        }
        processedPeriodIndexes.add(entry.periodIndex);
        list.add(_buildEntryCard(context, entry));
      }
    }
    return list;
  }

  Widget _buildMergedExamCard(
    BuildContext context,
    TimetableEntry entry,
    int startIdx,
    int endIdx,
  ) {
    final spanText = startIdx == endIdx ? 'Period $startIdx' : 'Periods $startIdx–$endIdx';
    final examTitle = entry.examTitle ?? 'Official Examination';
    final dateStr = entry.examDate != null
        ? DateFormat('EEEE, dd MMM yyyy').format(entry.examDate!)
        : '${entry.dayOfWeek} (Scheduled Slot)';
    final durationStr = entry.duration != null ? ' [${entry.duration}]' : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: const Color(0xFFF8F9FE),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => showExamDetailModal(context, entry),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFC7D2FE), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF3730A3).withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Container(
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.all(Radius.circular(16)),
                border: Border(
                  left: BorderSide(
                    color: Color(0xFF3730A3),
                    width: 5,
                  ),
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Exam Category Title Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0E7FF),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          examTitle.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF3730A3),
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                      const Row(
                        children: [
                          Text(
                            'Details',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF3730A3),
                            ),
                          ),
                          SizedBox(width: 2),
                          Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF3730A3)),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // 2. Subject & Code
                  Text(
                    '${entry.subjectCode} - ${entry.subjectName}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E1B4B),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 8),

                  // 3. Date of Exam
                  Row(
                    children: [
                      const Icon(Icons.event_note_rounded, size: 15, color: Color(0xFF3730A3)),
                      const SizedBox(width: 6),
                      Text(
                        dateStr,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF3730A3),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  // 4. Duration / Time Slot
                  Row(
                    children: [
                      const Icon(Icons.access_time_rounded, size: 15, color: Color(0xFF4F46E5)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${entry.timeSlot} ($spanText)$durationStr',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E1B4B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
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

  PeriodStatus _getMockPeriodStatus(TimetableEntry entry) {
    if (widget.isEditable || widget.selectedDate == null) return PeriodStatus.upcoming;

    final now = DateTime.now();
    final selectedDate = widget.selectedDate!;
    final targetDate = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    final today = DateTime(now.year, now.month, now.day);

    bool isPast = false;
    bool isOngoing = false;

    if (targetDate.isBefore(today)) {
      isPast = true;
    } else if (targetDate.isAtSameMomentAs(today)) {
      try {
        final parts = entry.timeSlot.split('-');
        if (parts.length == 2) {
          String startStr = parts[0].trim();
          String endStr = parts[1].trim();

          if (!startStr.contains('AM') && !startStr.contains('PM')) {
            final ampm = endStr.substring(endStr.length - 2);
            startStr = '$startStr $ampm';
          }

          final format = DateFormat('hh:mm a');
          final startTime = format.parse(startStr);
          final endTime = format.parse(endStr);

          final startDateTime = DateTime(today.year, today.month, today.day, startTime.hour, startTime.minute);
          final endDateTime = DateTime(today.year, today.month, today.day, endTime.hour, endTime.minute);

          if (now.isAfter(endDateTime)) {
            isPast = true;
          } else if (now.isAfter(startDateTime) && now.isBefore(endDateTime)) {
            isOngoing = true;
          }
        }
      } catch (_) {
        // Fallback if parsing fails
        isPast = true;
      }
    }

    if (isOngoing) return PeriodStatus.ongoing;
    if (!isPast) return PeriodStatus.upcoming;

    // Past deterministic status
    final hash = (entry.periodIndex * 7 + entry.subjectCode.length + widget.selectedDate!.day) % 10;
    if (hash < 5) return PeriodStatus.present;
    if (hash == 5) return PeriodStatus.absent;
    if (hash == 6) return PeriodStatus.onDuty;
    if (hash == 7) return PeriodStatus.cancelled;
    return PeriodStatus.present;
  }

  Color _getStatusColor(PeriodStatus status) {
    switch (status) {
      case PeriodStatus.present: return const Color(0xFF4CAF50);
      case PeriodStatus.onDuty: return const Color(0xFF9C27B0);
      case PeriodStatus.absent: return const Color(0xFFF44336);
      case PeriodStatus.upcoming: return const Color(0xFF2196F3);
      case PeriodStatus.ongoing: return const Color(0xFFFF9800);
      case PeriodStatus.cancelled: return Colors.grey.shade500;
    }
  }

  String _getStatusLabel(PeriodStatus status) {
    switch (status) {
      case PeriodStatus.present: return 'Present';
      case PeriodStatus.onDuty: return 'On-Duty';
      case PeriodStatus.absent: return 'Absent';
      case PeriodStatus.upcoming: return 'Upcoming';
      case PeriodStatus.ongoing: return 'In Progress';
      case PeriodStatus.cancelled: return 'Cancelled';
    }
  }

  Widget _buildEntryCard(BuildContext context, TimetableEntry entry) {
    final status = _getMockPeriodStatus(entry);
    final statusColor = _getStatusColor(status);

    FacultySubstitution? sub;
    try {
      sub = widget.activeSubs.firstWhere((s) => s.subjectCode == entry.subjectCode && s.timeSlot == entry.timeSlot);
    } catch (_) {}

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: statusColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: InkWell(
        onTap: () => showClassDetailModal(context, entry, sub: sub),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border(
              left: BorderSide(
                color: statusColor,
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
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Period ${entry.periodIndex} • ${entry.timeSlot}',
                        softWrap: true,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
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
                    if (widget.isEditable)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Class: ${entry.className}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                  ],
                ),
                Wrap(
                  spacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (sub != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.amber.shade300),
                        ),
                        child: Text(
                          'Substituted',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            status == PeriodStatus.present ? Icons.check_circle_outline :
                            status == PeriodStatus.absent ? Icons.cancel_outlined :
                            status == PeriodStatus.onDuty ? Icons.work_outline :
                            status == PeriodStatus.cancelled ? Icons.block :
                            Icons.schedule,
                            size: 14,
                            color: statusColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _getStatusLabel(status),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
                            child: sub != null
                                ? Wrap(
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    spacing: 6,
                                    children: [
                                      Text(
                                        sub.originalFaculty,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.red,
                                          decoration: TextDecoration.lineThrough,
                                        ),
                                      ),
                                      const Icon(Icons.arrow_right_alt, size: 16, color: AppColors.muted),
                                      Text(
                                        sub.substituteFaculty,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.amber.shade800,
                                        ),
                                      ),
                                    ],
                                  )
                                : Text(
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
                        horizontal: 4,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: matching.categoryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: matching.categoryColor.withValues(alpha: 0.4),
                        ),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              matching.subjectCode,
                              maxLines: 2,
                              softWrap: true,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: matching.categoryColor,
                              ),
                            ),
                            Text(
                              matching.className,
                              maxLines: 2,
                              softWrap: true,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 9,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
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
