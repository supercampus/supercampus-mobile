import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/mock_library_repository.dart';
import 'library_wheel_picker.dart';

/// Bottom sheet for booking a new library slot with segmented wheel pickers.
class LibraryBookSlotSheet extends StatefulWidget {
  const LibraryBookSlotSheet({
    super.key,
    required this.repository,
  });

  final MockLibraryRepository repository;

  @override
  State<LibraryBookSlotSheet> createState() => _LibraryBookSlotSheetState();
}

class _LibraryBookSlotSheetState extends State<LibraryBookSlotSheet> {
  // Date
  late int _day;
  late int _month;

  // Start time
  int _startHour = 10;
  int _startMinute = 0;

  // End time
  int _endHour = 12;
  int _endMinute = 0;

  // Description
  final _descriptionController = TextEditingController();

  // Picker visibility
  String? _activePicker;

  // Month names
  static const _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static const _minuteSteps = [0, 15, 30, 45];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _day = now.day;
    _month = now.month;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  int get _available => widget.repository.availableSlots(
    date: DateTime(DateTime.now().year, _month, _day),
    startHour: _startHour,
    startMinute: _startMinute,
    endHour: _endHour,
    endMinute: _endMinute,
  );

  bool get _isValidTimeRange {
    final startTotal = _startHour * 60 + _startMinute;
    final endTotal = _endHour * 60 + _endMinute;
    return endTotal > startTotal;
  }

  void _togglePicker(String id) {
    setState(() => _activePicker = _activePicker == id ? null : id);
  }

  void _confirm() {
    if (!_isValidTimeRange) return;

    try {
      final pass = widget.repository.book(
        date: DateTime(DateTime.now().year, _month, _day),
        startHour: _startHour,
        startMinute: _startMinute,
        endHour: _endHour,
        endMinute: _endMinute,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
      );
      Navigator.of(context).pop(pass);
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Bad state: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final available = _available;
    final validTime = _isValidTimeRange;
    final canBook = available > 0 && validTime;
    final surfaceColor = isDark ? Colors.black : AppColors.canvas;

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black26,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Row(
              children: [
                const Icon(Icons.local_library_outlined, color: Color(0xFF6D357F)),
                const SizedBox(width: 10),
                Text(
                  'Book Slot',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                // ── Date Selector ──
                _SectionLabel(label: 'DATE'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: SegmentedPill(
                        label: 'DATE',
                        value: _day.toString().padLeft(2, '0'),
                        isActive: _activePicker == 'day',
                        onTap: () => _togglePicker('day'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SegmentedPill(
                        label: 'MONTH',
                        value: _monthNames[_month - 1],
                        isActive: _activePicker == 'month',
                        onTap: () => _togglePicker('month'),
                      ),
                    ),
                  ],
                ),
                _AnimatedPickerContainer(
                  visible: _activePicker == 'day',
                  child: LibraryWheelPicker(
                    itemCount: 31,
                    initialIndex: _day - 1,
                    labelBuilder: (i) => (i + 1).toString().padLeft(2, '0'),
                    onChanged: (i) => setState(() => _day = i + 1),
                  ),
                ),
                _AnimatedPickerContainer(
                  visible: _activePicker == 'month',
                  child: LibraryWheelPicker(
                    itemCount: 12,
                    initialIndex: _month - 1,
                    labelBuilder: (i) => _monthNames[i],
                    onChanged: (i) => setState(() => _month = i + 1),
                  ),
                ),

                const SizedBox(height: 20),

                // ── Start Time ──
                _SectionLabel(label: 'START TIME'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: SegmentedPill(
                        label: 'HOUR',
                        value: _startHour.toString().padLeft(2, '0'),
                        isActive: _activePicker == 'startHour',
                        onTap: () => _togglePicker('startHour'),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        ':',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white54 : AppColors.muted,
                        ),
                      ),
                    ),
                    Expanded(
                      child: SegmentedPill(
                        label: 'MINUTE',
                        value: _startMinute.toString().padLeft(2, '0'),
                        isActive: _activePicker == 'startMinute',
                        onTap: () => _togglePicker('startMinute'),
                      ),
                    ),
                  ],
                ),
                _AnimatedPickerContainer(
                  visible: _activePicker == 'startHour',
                  child: LibraryWheelPicker(
                    itemCount: 24,
                    initialIndex: _startHour,
                    labelBuilder: (i) => i.toString().padLeft(2, '0'),
                    onChanged: (i) => setState(() => _startHour = i),
                  ),
                ),
                _AnimatedPickerContainer(
                  visible: _activePicker == 'startMinute',
                  child: LibraryWheelPicker(
                    itemCount: _minuteSteps.length,
                    initialIndex: _minuteSteps.indexOf(_startMinute).clamp(0, _minuteSteps.length - 1),
                    labelBuilder: (i) => _minuteSteps[i].toString().padLeft(2, '0'),
                    onChanged: (i) => setState(() => _startMinute = _minuteSteps[i]),
                  ),
                ),

                const SizedBox(height: 20),

                // ── End Time ──
                _SectionLabel(label: 'END TIME'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: SegmentedPill(
                        label: 'HOUR',
                        value: _endHour.toString().padLeft(2, '0'),
                        isActive: _activePicker == 'endHour',
                        onTap: () => _togglePicker('endHour'),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        ':',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white54 : AppColors.muted,
                        ),
                      ),
                    ),
                    Expanded(
                      child: SegmentedPill(
                        label: 'MINUTE',
                        value: _endMinute.toString().padLeft(2, '0'),
                        isActive: _activePicker == 'endMinute',
                        onTap: () => _togglePicker('endMinute'),
                      ),
                    ),
                  ],
                ),
                _AnimatedPickerContainer(
                  visible: _activePicker == 'endHour',
                  child: LibraryWheelPicker(
                    itemCount: 24,
                    initialIndex: _endHour,
                    labelBuilder: (i) => i.toString().padLeft(2, '0'),
                    onChanged: (i) => setState(() => _endHour = i),
                  ),
                ),
                _AnimatedPickerContainer(
                  visible: _activePicker == 'endMinute',
                  child: LibraryWheelPicker(
                    itemCount: _minuteSteps.length,
                    initialIndex: _minuteSteps.indexOf(_endMinute).clamp(0, _minuteSteps.length - 1),
                    labelBuilder: (i) => _minuteSteps[i].toString().padLeft(2, '0'),
                    onChanged: (i) => setState(() => _endMinute = _minuteSteps[i]),
                  ),
                ),

                const SizedBox(height: 20),

                // ── Description ──
                _SectionLabel(label: 'DESCRIPTION (OPTIONAL)'),
                const SizedBox(height: 8),
                TextField(
                  controller: _descriptionController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'Add a description',
                  ),
                ),

                const SizedBox(height: 20),

                // ── Availability ──
                if (!validTime)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFB71C1C).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Color(0xFFB71C1C), size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'End time must be after start time.',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Color(0xFFB71C1C),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: available > 0
                          ? const Color(0xFF6D357F).withValues(alpha: 0.08)
                          : const Color(0xFFB71C1C).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          available > 0
                              ? Icons.groups_outlined
                              : Icons.block_outlined,
                          color: available > 0
                              ? const Color(0xFF6D357F)
                              : const Color(0xFFB71C1C),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            available > 0
                                ? '$available slots available'
                                : 'Slot Full – Please select a different time or try later.',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: available > 0
                                  ? null
                                  : const Color(0xFFB71C1C),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 20),

                // ── Confirm Button ──
                FilledButton.icon(
                  onPressed: canBook ? _confirm : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF6D357F),
                    disabledBackgroundColor: isDark
                        ? Colors.white12
                        : const Color(0xFFE0E0E0),
                  ),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Confirm Booking'),
                ),

                const SizedBox(height: 28),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white54
            : AppColors.muted,
        letterSpacing: 1.2,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _AnimatedPickerContainer extends StatelessWidget {
  const _AnimatedPickerContainer({required this.visible, required this.child});
  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeInOut,
      child: visible
          ? Padding(
              padding: const EdgeInsets.only(top: 10),
              child: child,
            )
          : const SizedBox.shrink(),
    );
  }
}
