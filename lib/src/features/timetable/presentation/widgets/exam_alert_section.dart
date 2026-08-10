import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/notifications/exam_alert_service.dart';
import '../../data/timetable_models.dart';

/// Lets a student put a reminder on an exam, at a stock offset before it or at
/// a time of their own choosing.
///
/// It replaces the modal's old close button: the dialog already closes from
/// the × in its corner, so the one action worth a full-width button is the one
/// that does something.
class ExamAlertSection extends StatefulWidget {
  const ExamAlertSection({super.key, required this.exam});

  final TimetableEntry exam;

  @override
  State<ExamAlertSection> createState() => _ExamAlertSectionState();
}

/// The offsets worth one tap. Anything else is what "Custom" is for.
const _presets = <(String, Duration)>[
  ('1 day before', Duration(days: 1)),
  ('3 hours before', Duration(hours: 3)),
  ('1 hour before', Duration(hours: 1)),
  ('30 min before', Duration(minutes: 30)),
];

class _ExamAlertSectionState extends State<ExamAlertSection> {
  final _service = ExamAlertService.instance;

  /// The moment the student has picked but not yet confirmed.
  DateTime? _pending;
  String? _pendingLabel;
  String? _error;
  bool _busy = false;

  DateTime? get _examStart => examStartOf(widget.exam);

  DateTime? get _existing => _service.alertFor(widget.exam.id);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _service,
      builder: (context, _) {
        final existing = _existing;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: existing != null
                ? const Color(0xFFF0FDF4)
                : const Color(0xFFF8F9FE),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: existing != null
                  ? const Color(0xFFBBF7D0)
                  : const Color(0xFFC7D2FE),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(existing),
              const SizedBox(height: 12),
              if (existing != null) ..._setState(existing) else ..._pickState(),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFB91C1C),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _header(DateTime? existing) {
    final on = existing != null;

    return Row(
      children: [
        Icon(
          on
              ? Icons.notifications_active_rounded
              : Icons.notifications_none_rounded,
          size: 18,
          color: on ? const Color(0xFF15803D) : const Color(0xFF3730A3),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            on ? 'Alert set' : 'Remind me about this exam',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: on ? const Color(0xFF15803D) : const Color(0xFF3730A3),
            ),
          ),
        ),
      ],
    );
  }

  /// What the section shows once an alert exists: when it will arrive, and the
  /// two things left to do about it.
  List<Widget> _setState(DateTime existing) => [
    Text(
      _fullFormat(existing),
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: Color(0xFF14532D),
      ),
    ),
    const SizedBox(height: 2),
    Text(
      _relativeToExam(existing),
      style: const TextStyle(fontSize: 12, color: Color(0xFF166534)),
    ),
    const SizedBox(height: 12),
    Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _busy ? null : _remove,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFB91C1C),
              side: const BorderSide(color: Color(0xFFFECACA)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text(
              'Remove alert',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton(
            onPressed: _busy ? null : _pickCustom,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF15803D),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text(
              'Change time',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ),
      ],
    ),
  ];

  /// What it shows before there is one: the offsets, then the confirm button.
  List<Widget> _pickState() {
    final start = _examStart;
    final pending = _pending;

    return [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final (label, offset) in _presets)
            _chip(
              label: label,
              selected: _pendingLabel == label,
              // An offset that has already gone by cannot be set, and saying
              // so up front beats an error after the tap.
              enabled: start != null && _isFuture(start.subtract(offset)),
              onTap: () => setState(() {
                _pending = start!.subtract(offset);
                _pendingLabel = label;
                _error = null;
              }),
            ),
          _chip(
            label: 'Custom…',
            selected: _pendingLabel == 'Custom',
            enabled: true,
            onTap: _pickCustom,
          ),
        ],
      ),
      if (pending != null) ...[
        const SizedBox(height: 12),
        Text(
          'Notifies you on ${_fullFormat(pending)}',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E1B4B),
          ),
        ),
      ],
      const SizedBox(height: 12),
      SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: pending == null || _busy ? null : _confirm,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF3730A3),
            disabledBackgroundColor: const Color(0xFFC7D2FE),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          child: Text(
            pending == null ? 'Choose when to be alerted' : 'Set alert',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
    ];
  }

  Widget _chip({
    required String label,
    required bool selected,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF3730A3) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? const Color(0xFF3730A3) : const Color(0xFFC7D2FE),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected
                ? Colors.white
                : enabled
                ? const Color(0xFF3730A3)
                : const Color(0xFFA5B4FC),
          ),
        ),
      ),
    );
  }

  /// Any date and time the student likes, defaulting to an hour before the
  /// exam so the common case is two taps of confirmation.
  Future<void> _pickCustom() async {
    final now = DateTime.now();
    final start = _examStart;
    final seed = _existing ?? _pending ?? _suggestedSeed(start, now);

    final date = await showDatePicker(
      context: context,
      initialDate: seed.isBefore(now) ? now : seed,
      firstDate: now,
      lastDate: (start ?? now).add(const Duration(days: 365)),
      helpText: 'Alert me on',
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(seed),
      helpText: 'Alert me at',
    );
    if (time == null || !mounted) return;

    setState(() {
      _pending = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      _pendingLabel = 'Custom';
      _error = null;
    });

    // Changing an existing alert goes straight through: the student has
    // already said what they want twice over.
    if (_existing != null) await _confirm();
  }

  DateTime _suggestedSeed(DateTime? start, DateTime now) {
    if (start == null) return now.add(const Duration(hours: 1));
    final hourBefore = start.subtract(const Duration(hours: 1));
    return hourBefore.isAfter(now)
        ? hourBefore
        : now.add(const Duration(minutes: 10));
  }

  Future<void> _confirm() async {
    final at = _pending;
    if (at == null) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    final exam = widget.exam;
    final failure = await _service.setAlert(
      examId: exam.id,
      title: '${exam.subjectCode} — ${exam.examTitle ?? 'Exam'}',
      body: _notificationBody(exam),
      at: at,
    );

    if (!mounted) return;

    setState(() {
      _busy = false;
      _error = _messageFor(failure);
      if (failure == AlertFailure.none) {
        _pending = null;
        _pendingLabel = null;
      }
    });
  }

  Future<void> _remove() async {
    setState(() => _busy = true);
    await _service.cancelAlert(widget.exam.id);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = null;
    });
  }

  /// The notification has to stand on its own on a lock screen, so it carries
  /// the two things a student needs before an exam: when, and where.
  String _notificationBody(TimetableEntry exam) {
    final start = _examStart;
    final when = start != null
        ? DateFormat('EEE d MMM, h:mm a').format(start)
        : exam.timeSlot;
    final hall = exam.hallNumber;
    final seat = exam.seatNumber;

    final place = [if (hall != null) hall, if (seat != null) seat].join(' • ');

    return place.isEmpty
        ? '${exam.subjectName} at $when'
        : '${exam.subjectName} at $when · $place';
  }

  String? _messageFor(AlertFailure failure) => switch (failure) {
    AlertFailure.none => null,
    AlertFailure.denied =>
      'Notifications are turned off for SuperCampus. Turn them on in '
          'your device settings to be alerted.',
    AlertFailure.inThePast => 'Pick a time that has not already passed.',
    AlertFailure.unsupported => 'Alerts are not available on this device.',
  };

  String _fullFormat(DateTime at) =>
      DateFormat('EEE, d MMM yyyy • h:mm a').format(at);

  /// How far ahead of the exam the alert lands, in the words a student would
  /// use — "2 hours before the exam", not a timestamp difference.
  String _relativeToExam(DateTime at) {
    final start = _examStart;
    if (start == null) return 'You will be notified on your device.';

    final gap = start.difference(at);
    if (gap.isNegative) return 'After the exam starts.';

    if (gap.inMinutes < 60) return '${gap.inMinutes} minutes before the exam.';
    if (gap.inHours < 24) {
      final hours = gap.inHours;
      return '$hours ${hours == 1 ? 'hour' : 'hours'} before the exam.';
    }

    final days = gap.inDays;
    return '$days ${days == 1 ? 'day' : 'days'} before the exam.';
  }

  bool _isFuture(DateTime at) => at.isAfter(DateTime.now());
}

/// When the exam actually begins.
///
/// The model keeps the date and the clock time apart — [TimetableEntry.examDate]
/// is a date and [TimetableEntry.timeSlot] is text like `08:30 AM – 10:20 AM`
/// — so scheduling anything against an exam means putting the two back
/// together.
DateTime? examStartOf(TimetableEntry exam) {
  final date = exam.examDate;
  if (date == null) return null;

  final start = _parseSlotStart(exam.timeSlot);
  if (start == null) return date;

  return DateTime(date.year, date.month, date.day, start.hour, start.minute);
}

final _timePattern = RegExp(
  r'(\d{1,2}):(\d{2})\s*(AM|PM)?',
  caseSensitive: false,
);

/// The first clock time in a slot string.
///
/// Slots are written both ways in the timetable — `08:30 AM – 10:20 AM` spells
/// out both halves, `09:30 - 10:20 AM` leaves the meridiem to the end time —
/// so a start without one borrows it, and is pulled back a half day if that
/// borrowing would put the start after the end.
TimeOfDay? _parseSlotStart(String slot) {
  final matches = _timePattern.allMatches(slot).toList();
  if (matches.isEmpty) return null;

  final start = matches.first;
  var hour = int.parse(start.group(1)!);
  final minute = int.parse(start.group(2)!);

  final own = start.group(3)?.toUpperCase();
  final borrowed = matches.length > 1
      ? matches[1].group(3)?.toUpperCase()
      : null;
  final meridiem = own ?? borrowed;

  if (meridiem == 'PM' && hour != 12) hour += 12;
  if (meridiem == 'AM' && hour == 12) hour = 0;

  if (own == null && matches.length > 1) {
    final end = matches[1];
    var endHour = int.parse(end.group(1)!);
    if (borrowed == 'PM' && endHour != 12) endHour += 12;
    if (borrowed == 'AM' && endHour == 12) endHour = 0;

    final endMinute = int.parse(end.group(2)!);
    if (hour * 60 + minute > endHour * 60 + endMinute) hour -= 12;
  }

  if (hour < 0 || hour > 23) return null;
  return TimeOfDay(hour: hour, minute: minute);
}
