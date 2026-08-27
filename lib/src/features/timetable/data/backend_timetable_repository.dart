import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../authentication/data/auth_repository.dart';
import 'mock_timetable_repository.dart';
import 'timetable_models.dart';

/// Read-only timetable repository backed by the principal's published schedule.
///
/// The API already applies tenant, section, faculty and publication visibility,
/// so this client never guesses which class a user may see.
class BackendTimetableRepository extends MockTimetableRepository {
  BackendTimetableRepository._({
    required TimetableConfig config,
    required List<TimetableEntry> entries,
  }) : _publishedConfig = config,
       _publishedEntries = entries;

  final TimetableConfig _publishedConfig;
  final List<TimetableEntry> _publishedEntries;

  static Future<BackendTimetableRepository> load({
    required String baseUrl,
    required AccessTokenProvider accessTokenProvider,
    http.Client? client,
  }) async {
    final ownedClient = client ?? http.Client();
    try {
      final token = await accessTokenProvider();
      final root = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
      final response = await ownedClient.get(
        Uri.parse('$root/api/v1/timetable/context'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw TimetableLoadException(
          response.statusCode == 403
              ? 'Timetable access is not enabled for this account.'
              : 'The published timetable could not be loaded.',
        );
      }

      final decoded = jsonDecode(response.body);
      final envelope = decoded is Map<String, dynamic> ? decoded : null;
      final raw = envelope?['data'];
      if (raw is! Map<String, dynamic>) {
        throw const TimetableLoadException(
          'The timetable response is invalid.',
        );
      }
      return BackendTimetableRepository._fromContext(raw);
    } on TimetableLoadException {
      rethrow;
    } catch (_) {
      throw const TimetableLoadException(
        'The published timetable is temporarily unavailable.',
      );
    } finally {
      if (client == null) ownedClient.close();
    }
  }

  factory BackendTimetableRepository._fromContext(Map<String, dynamic> data) {
    final slots = _maps(data['slots']);
    final slotById = <String, Map<String, dynamic>>{
      for (final slot in slots) _text(slot['id']): slot,
    };
    final instructional = slots
        .where((slot) => _text(slot['slotType']) == 'instructional')
        .toList();

    final entries = <TimetableEntry>[];
    for (final entry in _maps(data['entries'])) {
      final slot = slotById[_text(entry['slotId'])];
      if (slot == null) continue;
      final day = _integer(slot['dayOfWeek'], fallback: 1).clamp(1, 7);
      final sequence = _integer(slot['sequence'], fallback: 1);
      final delivery = _text(entry['deliveryType']).toLowerCase();
      entries.add(
        TimetableEntry(
          id: _text(entry['id']),
          subjectCode: _text(entry['subjectCode'], fallback: 'SUBJECT'),
          subjectName: _text(entry['subjectName'], fallback: 'Scheduled class'),
          facultyId: _text(entry['facultyUserId']),
          facultyName: _text(entry['facultyName'], fallback: 'Faculty'),
          className: _text(entry['sectionName'], fallback: 'Class'),
          dayOfWeek: _dayName(day),
          timeSlot: '${_clock(slot['startsAt'])} - ${_clock(slot['endsAt'])}',
          periodIndex: sequence,
          isLab: delivery == 'laboratory' || delivery == 'lab',
          combinedClassCode: _nullableText(entry['combinedClassCode']),
          combinedClassName: _nullableText(entry['combinedClassName']),
        ),
      );
    }

    final workingDayNumbers =
        instructional
            .map((slot) => _integer(slot['dayOfWeek'], fallback: 1).clamp(1, 7))
            .toSet()
            .toList()
          ..sort();
    final maxSequence = instructional.fold<int>(
      0,
      (value, slot) => _integer(slot['sequence'], fallback: value) > value
          ? _integer(slot['sequence'], fallback: value)
          : value,
    );
    final starts =
        instructional.map((slot) => _clock(slot['startsAt'])).toList()..sort();
    final ends = instructional.map((slot) => _clock(slot['endsAt'])).toList()
      ..sort();

    final config = TimetableConfig(
      academicYear: 'Published schedule',
      semester: 'Current term',
      batchSection: entries.isEmpty
          ? 'Assigned class'
          : entries.first.className,
      workingDays: workingDayNumbers.map(_dayName).toList(),
      collegeStartTime: starts.isEmpty ? '08:30' : starts.first,
      collegeEndTime: ends.isEmpty ? '16:30' : ends.last,
      periodsPerDay: maxSequence == 0 ? 1 : maxSequence,
      periodDurationMinutes: 50,
      breakSlots: slots
          .where((slot) => _text(slot['slotType']) != 'instructional')
          .map(
            (slot) =>
                '${_clock(slot['startsAt'])} - ${_clock(slot['endsAt'])} (${_text(slot['label'], fallback: 'Break')})',
          )
          .toSet()
          .toList(),
    );
    return BackendTimetableRepository._(config: config, entries: entries);
  }

  @override
  TimetableConfig getConfig() => _publishedConfig;

  @override
  List<String> getAvailableClasses() => _publishedEntries
      .map((entry) => entry.className)
      .toSet()
      .toList(growable: false);

  @override
  List<TimetableEntry> getEntriesForClass(String className) {
    final exact = _publishedEntries
        .where(
          (entry) =>
              entry.className.trim().toLowerCase() ==
              className.trim().toLowerCase(),
        )
        .toList();
    // A student's section claim can be a UUID while the timetable presents a
    // friendly section name. The server has already returned only their rows.
    return exact.isEmpty ? List.unmodifiable(_publishedEntries) : exact;
  }

  @override
  List<TimetableEntry> getEntriesForFaculty(
    String facultyName, {
    String? facultyId,
  }) {
    final id = facultyId?.trim().toLowerCase();
    final name = facultyName.trim().toLowerCase();
    final exact = _publishedEntries.where((entry) {
      if (id != null && id.isNotEmpty && entry.facultyId.toLowerCase() == id) {
        return true;
      }
      return entry.facultyName.trim().toLowerCase() == name;
    }).toList();
    // Department-scoped advisors may receive the rest of their department in
    // the same server response. Never turn a failed identity match into every
    // visible class: a faculty schedule must contain only their allocations.
    final visible = <TimetableEntry>[];
    final sharedIndexes = <String, int>{};
    for (final entry in exact) {
      final sharedCode = entry.combinedClassCode?.trim();
      if (sharedCode == null || sharedCode.isEmpty) {
        visible.add(entry);
        continue;
      }
      final key = '${sharedCode.toLowerCase()}|${entry.dayOfWeek}|${entry.periodIndex}';
      final existingIndex = sharedIndexes[key];
      if (existingIndex == null) {
        sharedIndexes[key] = visible.length;
        visible.add(
          entry.copyWith(
            className: entry.combinedClassName?.trim().isNotEmpty == true
                ? entry.combinedClassName
                : entry.className,
          ),
        );
        continue;
      }
      final existing = visible[existingIndex];
      if (existing.combinedClassName?.trim().isNotEmpty == true) continue;
      final classNames = <String>{
        ...existing.className.split(' + ').map((value) => value.trim()),
        entry.className.trim(),
      }..removeWhere((value) => value.isEmpty);
      visible[existingIndex] = existing.copyWith(className: classNames.join(' + '));
    }
    return List.unmodifiable(visible);
  }
}

class TimetableLoadException implements Exception {
  const TimetableLoadException(this.message);
  final String message;
}

List<Map<String, dynamic>> _maps(Object? value) =>
    value is List ? value.whereType<Map<String, dynamic>>().toList() : const [];

String _text(Object? value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

String? _nullableText(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

int _integer(Object? value, {required int fallback}) => value is num
    ? value.toInt()
    : int.tryParse(value?.toString() ?? '') ?? fallback;

String _clock(Object? value) {
  final text = _text(value);
  return text.length >= 5 ? text.substring(0, 5) : text;
}

String _dayName(int day) => const [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
][day - 1];
