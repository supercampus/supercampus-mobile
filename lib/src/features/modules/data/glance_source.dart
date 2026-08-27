import '../../../core/access/effective_permissions.dart';
import '../../attendance/data/attendance_repository.dart';
import '../presentation/today_glance.dart';

/// Loads only what the viewer's day shape actually needs.
///
/// A learner's standing costs one call and a teacher's roll state costs two;
/// asking for both on every login would spend requests on cards nobody is going
/// to see. The shape decides, so the network follows the same rule the layout
/// does.
abstract interface class GlanceSource {
  Future<GlanceFacts> load(DayShape shape);
}

/// The real one, over the operations API.
class BackendGlanceSource implements GlanceSource {
  const BackendGlanceSource({
    required this.attendance,
    required this.viewerUserId,
  });

  final AttendanceRepository attendance;
  final String viewerUserId;

  @override
  Future<GlanceFacts> load(DayShape shape) async {
    try {
      return switch (shape) {
        DayShape.learner => GlanceFacts(standing: await _standing()),
        DayShape.teaching => GlanceFacts(classes: await _classes()),
        DayShape.oversight => GlanceFacts(stats: await _stats()),
        // The counter's queue lives behind the canteen store, which the
        // dashboard does not hold. Until it is threaded through, the counter
        // shape reports nothing rather than a number it did not measure.
        DayShape.counter => GlanceFacts.empty,
        DayShape.none => GlanceFacts.empty,
      };
    } catch (_) {
      // A glance is never worth breaking the dashboard over, and the failures
      // are not all Exceptions — an unauthenticated session throws StateError.
      // An empty day reads the same as a failed one from where the reader is
      // standing, so it is caught broadly and on purpose.
      return GlanceFacts.empty;
    }
  }

  Future<AttendanceStanding> _standing() async {
    final summary = await attendance.summary('me');
    int number(String key) => switch (summary[key]) {
      final int value => value,
      final num value => value.round(),
      _ => 0,
    };
    return AttendanceStanding(
      percentage: number('percentage'),
      attended: number('attendedClasses'),
      total: number('totalClasses'),
      streak: recentAttendanceMarks(summary['records']),
    );
  }

  /// The learner's last seven published subject rolls, oldest to newest.
  ///
  /// The API returns newest first. Reversing the selected window makes the
  /// latest roll land at the far right while every earlier box keeps its
  /// previous Present, Absent, or OD state. A short history is left-padded.
  Future<List<TodayClass>> _classes() async {
    final results = await Future.wait([
      attendance.todayTimetableClasses(),
      attendance.sessions(),
    ]);
    final classes = results[0];
    final sessions = results[1];

    // A roll counts as taken when a session exists today for that subject. The
    // sessions endpoint returns the caller's own, so no further filtering is
    // needed.
    final today = DateTime.now();
    final stamp =
        '${today.year.toString().padLeft(4, '0')}-'
        '${today.month.toString().padLeft(2, '0')}-'
        '${today.day.toString().padLeft(2, '0')}';
    return [
      for (final entry in classes)
        TodayClass(
          subject: entry['subjectName']?.toString() ?? 'Class',
          section: [
            entry['sectionName']?.toString() ?? '',
            entry['periodLabel']?.toString() ?? '',
          ].where((value) => value.isNotEmpty).join(' · '),
          rollTaken: sessions.any(
            (session) => _isPublishedRollFor(entry, session, stamp),
          ),
          timetableEntryId: entry['timetableEntryId']?.toString() ?? '',
          subjectOfferingId: entry['subjectOfferingId']?.toString() ?? '',
          sectionId: entry['sectionId']?.toString() ?? '',
          periodLabel: entry['periodLabel']?.toString() ?? '',
        ),
    ];
  }

  static bool _isPublishedRollFor(
    Map<String, dynamic> entry,
    Map<String, dynamic> session,
    String dateStamp,
  ) {
    if (!(session['heldOn']?.toString() ?? '').startsWith(dateStamp) ||
        session['status']?.toString() == 'draft' ||
        session['subjectName']?.toString() !=
            entry['subjectName']?.toString()) {
      return false;
    }

    bool identityMatchesWhenPresent(String key) {
      final actual = session[key]?.toString() ?? '';
      return actual.isEmpty || actual == entry[key]?.toString();
    }

    if (!identityMatchesWhenPresent('subjectOfferingId') ||
        !identityMatchesWhenPresent('sectionId')) {
      return false;
    }
    final hasIdentity =
        (session['subjectOfferingId']?.toString() ?? '').isNotEmpty ||
        (session['sectionId']?.toString() ?? '').isNotEmpty;
    final period = session['periodLabel']?.toString() ?? '';
    return !hasIdentity ||
        period.isEmpty ||
        period == entry['periodLabel']?.toString();
  }

  Future<List<OversightStat>> _stats() async {
    final sessions = await attendance.sessions();
    final unpublished = sessions
        .where((session) => session['status']?.toString() != 'published')
        .length;

    return [
      OversightStat(
        label: unpublished == 1 ? 'roll to review' : 'rolls to review',
        value: '$unpublished',
        moduleId: 'attendance',
        urgent: unpublished > 0,
      ),
      OversightStat(
        label: sessions.length == 1 ? 'class held' : 'classes held',
        value: '${sessions.length}',
        moduleId: 'attendance',
      ),
    ];
  }
}

/// Converts newest-first API records into the fixed, oldest-to-newest strip.
List<AttendanceMark?> recentAttendanceMarks(Object? records) {
  if (records is! List) {
    return List<AttendanceMark?>.filled(attendanceStreakLength, null);
  }
  final latest = <AttendanceMark>[];
  for (final record in records) {
    if (record is! Map) continue;
    final mark = switch (record['status']?.toString().toLowerCase()) {
      'present' => AttendanceMark.present,
      'absent' => AttendanceMark.absent,
      'od' || 'on_duty' => AttendanceMark.onDuty,
      _ => null,
    };
    if (mark == null) continue;
    latest.add(mark);
    if (latest.length == attendanceStreakLength) break;
  }
  final chronological = latest.reversed.toList();
  final marks = List<AttendanceMark?>.filled(attendanceStreakLength, null);
  final offset = attendanceStreakLength - chronological.length;
  for (var index = 0; index < chronological.length; index++) {
    marks[offset + index] = chronological[index];
  }
  return marks;
}

/// Used when the app runs without a backend, and by tests that only care about
/// layout.
class EmptyGlanceSource implements GlanceSource {
  const EmptyGlanceSource();

  @override
  Future<GlanceFacts> load(DayShape shape) async => GlanceFacts.empty;
}

/// Reads the same shape rule the layout does, so a caller can decide whether a
/// request is worth making at all.
bool glanceNeedsLoading(EffectivePermissions permissions) =>
    dayShapeFor(permissions) != DayShape.none;
