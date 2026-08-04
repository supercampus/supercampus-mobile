import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../authentication/data/auth_repository.dart';
import '../data/mock_timetable_repository.dart';
import 'widgets/timetable_grid_view.dart';

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
  String _selectedDay = 'Monday';
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

  void _downloadTimetable() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Downloading active timetable PDF for $_targetClass (Odd Sem 2026-27)...',
        ),
        backgroundColor: AppColors.primary,
        action: SnackBarAction(
          label: 'OPEN',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.repository.getConfig();
    final entries = widget.repository.getEntriesForClass(_targetClass);
    final activeSubs = widget.repository
        .getSubstitutions()
        .where((s) => s.className == _targetClass && s.status == 'Approved')
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        // Role & Academic Context Header
        Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Wrap(
              spacing: 14,
              runSpacing: 14,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.calendar_month_outlined,
                        color: AppColors.primary,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                'Class Timetable: $_targetClass',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.green.shade200),
                                ),
                                child: const Text(
                                  'PUBLISHED',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2E7D32),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${config.programme} • ${config.semester} (${config.academicYear})',
                            softWrap: true,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                  ),
                  onPressed: _downloadTimetable,
                  icon: const Icon(Icons.download_outlined, size: 18),
                  label: const Text('Export PDF'),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Active Faculty Substitutions Banner (if any)
        if (activeSubs.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.swap_horiz,
                      color: Colors.amber.shade900,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Active Faculty Substitutions for $_targetClass',
                        softWrap: true,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.amber.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...activeSubs.map((sub) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '• ${sub.dayOfWeek} ${sub.timeSlot}: ${sub.subjectName} (${sub.subjectCode}) — ${sub.substituteFaculty} (replacing ${sub.originalFaculty})',
                      softWrap: true,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.amber.shade900,
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Interactive Schedule Grid View
        TimetableGridView(
          entries: entries,
          workingDays: config.workingDays,
          selectedDay: _selectedDay,
          onDaySelected: (day) => setState(() => _selectedDay = day),
          isEditable: false,
        ),
      ],
    );
  }
}
