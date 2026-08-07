import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/timetable_models.dart';

class TimetableConfigForm extends StatefulWidget {
  const TimetableConfigForm({
    super.key,
    required this.config,
    required this.onSaveConfig,
  });

  final TimetableConfig config;
  final ValueChanged<TimetableConfig> onSaveConfig;

  @override
  State<TimetableConfigForm> createState() => _TimetableConfigFormState();
}

class _TimetableConfigFormState extends State<TimetableConfigForm> {
  late final TextEditingController _acadYearCtrl;
  late final TextEditingController _semesterCtrl;
  late final TextEditingController _batchCtrl;
  late final TextEditingController _periodsCtrl;

  late int _periodDuration;
  late int _teaBreakDuration;
  late int _teaBreakPosition;
  late int _lunchBreakDuration;
  late int _lunchBreakPosition;
  late String _workingDaysOption;
  late List<String> _selectedDays;

  static const List<String> _fiveDays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
  ];

  static const List<String> _sixDays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];

  @override
  void initState() {
    super.initState();
    _acadYearCtrl = TextEditingController(text: widget.config.academicYear);
    _semesterCtrl = TextEditingController(text: widget.config.semester);
    _batchCtrl = TextEditingController(text: widget.config.batchSection);
    _periodsCtrl = TextEditingController(
      text: widget.config.periodsPerDay.toString(),
    );

    _periodDuration = widget.config.periodDurationMinutes;
    _teaBreakDuration = widget.config.teaBreakDurationMinutes;
    _teaBreakPosition = widget.config.teaBreakPosition;
    _lunchBreakDuration = widget.config.lunchBreakDurationMinutes;
    _lunchBreakPosition = widget.config.lunchBreakPosition;
    _workingDaysOption = widget.config.workingDaysOption;
    _selectedDays = List.from(widget.config.workingDays);
  }

  @override
  void dispose() {
    _acadYearCtrl.dispose();
    _semesterCtrl.dispose();
    _batchCtrl.dispose();
    _periodsCtrl.dispose();
    super.dispose();
  }

  void _onWorkingDaysOptionChanged(String option) {
    setState(() {
      _workingDaysOption = option;
      if (option == 'Mon-Fri') {
        _selectedDays = List.from(_fiveDays);
      } else {
        _selectedDays = List.from(_sixDays);
      }
    });
  }

  void _save() {
    final periodsCount = int.tryParse(_periodsCtrl.text) ?? 7;
    final updated = widget.config.copyWith(
      academicYear: _acadYearCtrl.text.trim(),
      semester: _semesterCtrl.text.trim(),
      batchSection: _batchCtrl.text.trim(),
      periodsPerDay: periodsCount,
      periodDurationMinutes: _periodDuration,
      teaBreakDurationMinutes: _teaBreakDuration,
      teaBreakPosition: _teaBreakPosition,
      lunchBreakDurationMinutes: _lunchBreakDuration,
      lunchBreakPosition: _lunchBreakPosition,
      workingDaysOption: _workingDaysOption,
      workingDays: _selectedDays,
      breakSlots: [
        'Tea Break: $_teaBreakDuration mins (After P$_teaBreakPosition)',
        'Lunch Break: $_lunchBreakDuration mins (After P$_lunchBreakPosition)',
      ],
    );

    widget.onSaveConfig(updated);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Class Timetable configuration saved successfully!'),
        backgroundColor: Color(0xFF00695C),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxPeriods = int.tryParse(_periodsCtrl.text) ?? 8;

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00695C).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.tune_outlined,
                    color: Color(0xFF00695C),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Class Schedule & Structure Configuration',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const Text(
                        'Configure working days, period durations, and break positions for the class schedule',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Basic Class & Academic Terms Context
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 160,
                  child: TextField(
                    controller: _acadYearCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Academic Year',
                      prefixIcon: Icon(Icons.calendar_today_outlined, size: 18),
                    ),
                  ),
                ),
                SizedBox(
                  width: 140,
                  child: TextField(
                    controller: _semesterCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Semester',
                      prefixIcon: Icon(Icons.timeline_outlined, size: 18),
                    ),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: TextField(
                    controller: _batchCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Class Section',
                      prefixIcon: Icon(Icons.groups_outlined, size: 18),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),

            // Section Header: Time & Structure Controls
            Row(
              children: [
                const Icon(
                  Icons.timer_outlined,
                  size: 18,
                  color: Color(0xFF00695C),
                ),
                const SizedBox(width: 8),
                Text(
                  'Period & Duration Settings',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Period Duration & Daily Period Count Controls
            Wrap(
              spacing: 16,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 220,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Period Duration',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<int>(
                        initialValue: _periodDuration,
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 40,
                            child: Text('40 minutes'),
                          ),
                          DropdownMenuItem(
                            value: 45,
                            child: Text('45 minutes'),
                          ),
                          DropdownMenuItem(
                            value: 50,
                            child: Text('50 minutes'),
                          ),
                          DropdownMenuItem(
                            value: 60,
                            child: Text('60 minutes (1 hr)'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null)
                            setState(() => _periodDuration = val);
                        },
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Periods Per Day',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _periodsCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          prefixIcon: Icon(
                            Icons.format_list_numbered,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),

            // Section Header: Break Settings
            Row(
              children: [
                const Icon(
                  Icons.coffee_outlined,
                  size: 18,
                  color: Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  'Break Settings (Tea & Lunch)',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Tea Break Duration & Position
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '☕ Tea Break Settings',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.amber,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: 180,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Duration',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.muted,
                              ),
                            ),
                            const SizedBox(height: 4),
                            DropdownButtonFormField<int>(
                              initialValue: _teaBreakDuration,
                              decoration: const InputDecoration(
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 10,
                                  child: Text('10 mins'),
                                ),
                                DropdownMenuItem(
                                  value: 15,
                                  child: Text('15 mins'),
                                ),
                                DropdownMenuItem(
                                  value: 20,
                                  child: Text('20 mins'),
                                ),
                              ],
                              onChanged: (val) {
                                if (val != null)
                                  setState(() => _teaBreakDuration = val);
                              },
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 200,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Slot Position',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.muted,
                              ),
                            ),
                            const SizedBox(height: 4),
                            DropdownButtonFormField<int>(
                              initialValue: _teaBreakPosition <= maxPeriods
                                  ? _teaBreakPosition
                                  : 2,
                              decoration: const InputDecoration(
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                              ),
                              items: List.generate(
                                (maxPeriods - 1).clamp(1, 10),
                                (i) => DropdownMenuItem(
                                  value: i + 1,
                                  child: Text('After Period ${i + 1}'),
                                ),
                              ),
                              onChanged: (val) {
                                if (val != null)
                                  setState(() => _teaBreakPosition = val);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Lunch Break Duration & Position
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '🍱 Lunch Break Settings',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.deepOrange,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: 180,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Duration',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.muted,
                              ),
                            ),
                            const SizedBox(height: 4),
                            DropdownButtonFormField<int>(
                              initialValue: _lunchBreakDuration,
                              decoration: const InputDecoration(
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 30,
                                  child: Text('30 mins'),
                                ),
                                DropdownMenuItem(
                                  value: 45,
                                  child: Text('45 mins'),
                                ),
                                DropdownMenuItem(
                                  value: 60,
                                  child: Text('60 mins (1 hr)'),
                                ),
                              ],
                              onChanged: (val) {
                                if (val != null)
                                  setState(() => _lunchBreakDuration = val);
                              },
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 200,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Slot Position',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.muted,
                              ),
                            ),
                            const SizedBox(height: 4),
                            DropdownButtonFormField<int>(
                              initialValue: _lunchBreakPosition <= maxPeriods
                                  ? _lunchBreakPosition
                                  : 4,
                              decoration: const InputDecoration(
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                              ),
                              items: List.generate(
                                (maxPeriods - 1).clamp(1, 10),
                                (i) => DropdownMenuItem(
                                  value: i + 1,
                                  child: Text('After Period ${i + 1}'),
                                ),
                              ),
                              onChanged: (val) {
                                if (val != null)
                                  setState(() => _lunchBreakPosition = val);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),

            // Working Days & Structure
            Text(
              'Working Days Structure:',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            Wrap(
              children: [
                ChoiceChip(
                  label: const Text('Mon – Fri (5 Days)'),
                  selected: _workingDaysOption == 'Mon-Fri',
                  selectedColor: const Color(0xFF00695C),
                  labelStyle: TextStyle(
                    color: _workingDaysOption == 'Mon-Fri'
                        ? Colors.white
                        : AppColors.ink,
                    fontWeight: _workingDaysOption == 'Mon-Fri'
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                  onSelected: (_) => _onWorkingDaysOptionChanged('Mon-Fri'),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Mon – Sat (6 Days)'),
                  selected: _workingDaysOption == 'Mon-Sat',
                  selectedColor: const Color(0xFF00695C),
                  labelStyle: TextStyle(
                    color: _workingDaysOption == 'Mon-Sat'
                        ? Colors.white
                        : AppColors.ink,
                    fontWeight: _workingDaysOption == 'Mon-Sat'
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                  onSelected: (_) => _onWorkingDaysOptionChanged('Mon-Sat'),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _sixDays.map((day) {
                final isSelected = _selectedDays.contains(day);
                return FilterChip(
                  label: Text(day),
                  selected: isSelected,
                  selectedColor: const Color(0xFF00695C),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : AppColors.ink,
                    fontSize: 12,
                  ),
                  onSelected: (val) {
                    setState(() {
                      if (val) {
                        if (!_selectedDays.contains(day))
                          _selectedDays.add(day);
                      } else {
                        _selectedDays.remove(day);
                      }
                    });
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF00695C),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _save,
                icon: const Icon(Icons.save_outlined),
                label: const Text(
                  'Save Configuration Settings',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
