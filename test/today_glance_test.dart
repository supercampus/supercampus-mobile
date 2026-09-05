import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/core/access/effective_permissions.dart';
import 'package:supercampus_mobile/src/core/access/module_catalog.dart';
import 'package:supercampus_mobile/src/core/widgets/skeleton_loading.dart';
import 'package:supercampus_mobile/src/features/modules/presentation/today_glance.dart';

EffectivePermissions grants(
  Set<String> keys, {
  Map<String, PermissionScope> scopes = const {},
}) => EffectivePermissions(grants: keys, scopes: scopes);

/// The five personas as their grants actually arrive from /api/v1/bootstrap.
final student = grants(
  {
    'academics.marks.read',
    'attendance.leave.create',
    'canteen.order.create',
    'gatepass.outpass.create',
  },
  scopes: {
    ModuleCatalog.academics: PermissionScope.own,
    ModuleCatalog.attendance: PermissionScope.own,
    ModuleCatalog.canteen: PermissionScope.own,
    ModuleCatalog.gatepass: PermissionScope.own,
  },
);

final faculty = grants(
  {
    'attendance.roster.read',
    'attendance.roster.update',
    'attendance.session.create',
    'academics.marks.read',
    'canteen.menu.read',
  },
  scopes: {
    ModuleCatalog.attendance: PermissionScope.section,
    ModuleCatalog.academics: PermissionScope.section,
  },
);

final hod = grants(
  {
    'attendance.roster.read',
    'attendance.roster.update',
    'attendance.leave.approve',
    'academics.marks.read',
  },
  scopes: {
    ModuleCatalog.attendance: PermissionScope.department,
    ModuleCatalog.academics: PermissionScope.department,
  },
);

final shopOwner = grants(
  {
    'canteen.menu.create',
    'canteen.menu.update',
    'canteen.orders.manage',
    'canteen.order.read',
  },
  scopes: {ModuleCatalog.canteen: PermissionScope.institution},
);

final captain = grants(
  {'canteen.menu.read', 'canteen.orders.manage', 'canteen.order.update'},
  scopes: {ModuleCatalog.canteen: PermissionScope.institution},
);

Future<void> pumpGlance(
  WidgetTester tester,
  EffectivePermissions permissions, {
  GlanceFacts facts = GlanceFacts.empty,
  List<String>? opened,
  List<TodayClass>? openedClasses,
  DateTime? date,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: TodayGlance(
            permissions: permissions,
            facts: facts,
            onOpenModule: (id) => opened?.add(id),
            onOpenClass: (value) => openedClasses?.add(value),
            date: date,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('the day takes its shape from what someone does', () {
    test('a learner gets their own day', () {
      expect(dayShapeFor(student), DayShape.learner);
    });

    test('section reach plus the power to open a roll is teaching', () {
      expect(dayShapeFor(faculty), DayShape.teaching);
    });

    test('wider reach reviews rolls rather than taking them', () {
      // An HOD can still update a roster, but across a department — that is a
      // different day from standing in front of one class.
      expect(dayShapeFor(hod), DayShape.oversight);
    });

    test('running a shop is a counter, owner and captain alike', () {
      expect(dayShapeFor(shopOwner), DayShape.counter);
      expect(dayShapeFor(captain), DayShape.counter);
    });

    test('no grants worth a today shows nothing at all', () {
      expect(dayShapeFor(grants({'documents.records.read'})), DayShape.none);
    });

    test('the shape follows the grants, not what the holder is called', () {
      // One bundle of grants, described two ways a tenant might name it. The
      // decision only ever reads keys and scope, so both land on teaching.
      const keys = {
        'attendance.roster.update',
        'attendance.session.create',
        'academics.marks.read',
      };
      const sectionScope = {
        ModuleCatalog.attendance: PermissionScope.section,
        ModuleCatalog.academics: PermissionScope.section,
      };
      expect(
        dayShapeFor(EffectivePermissions(grants: keys, scopes: sectionScope)),
        DayShape.teaching,
      );
      // Add the advisor's extra approval and the day is still a teaching day —
      // it is the same person with one more grant, not a new persona.
      expect(
        dayShapeFor(
          EffectivePermissions(
            grants: {...keys, 'attendance.leave.approve'},
            scopes: sectionScope,
          ),
        ),
        DayShape.teaching,
      );
    });
  });

  group('each operational shape is titled for what is under it', () {
    test('while the learner glance stays visually compact', () {
      final titles = {
        glanceTitleFor(dayShapeFor(faculty)),
        glanceTitleFor(dayShapeFor(hod)),
        glanceTitleFor(dayShapeFor(shopOwner)),
      };
      expect(titles.length, 3, reason: 'the headings collapsed together');
      expect(glanceTitleFor(dayShapeFor(student)), isEmpty);
    });

    testWidgets('a student and a teacher do not read the same screen', (
      tester,
    ) async {
      await pumpGlance(tester, student);
      expect(find.text('Your day'), findsNothing);
      expect(find.text('Your classes today'), findsNothing);

      await pumpGlance(tester, faculty);
      expect(find.text('Your classes today'), findsOneWidget);
      expect(find.text('Your day'), findsNothing);
    });
  });

  group('a learner reads their standing', () {
    testWidgets('a real percentage, not a placeholder', (tester) async {
      await pumpGlance(
        tester,
        student,
        facts: const GlanceFacts(
          standing: AttendanceStanding(percentage: 82, attended: 41, total: 50),
        ),
      );

      expect(find.text('82% attendance'), findsOneWidget);
      expect(find.text('41 of 50 classes attended'), findsOneWidget);
      // The figures the old grid showed every account regardless of truth.
      expect(find.text('74%'), findsNothing);
      expect(find.text('8.42'), findsNothing);
    });

    testWidgets('an unmarked term says so instead of showing 0%', (
      tester,
    ) async {
      await pumpGlance(
        tester,
        student,
        facts: const GlanceFacts(
          standing: AttendanceStanding(percentage: 0, attended: 0, total: 0),
        ),
      );

      expect(find.text('No attendance recorded yet'), findsOneWidget);
      expect(find.text('0% attendance'), findsNothing);
    });

    testWidgets('tapping the standing opens academics', (tester) async {
      final opened = <String>[];
      await pumpGlance(
        tester,
        student,
        opened: opened,
        facts: const GlanceFacts(
          standing: AttendanceStanding(percentage: 90, attended: 9, total: 10),
        ),
      );

      await tester.tap(find.text('90% attendance'));
      await tester.pump();

      expect(opened, [ModuleCatalog.academics]);
    });
  });

  group('a teacher reads a worklist', () {
    testWidgets('the current weekday appears above the worklist heading', (
      tester,
    ) async {
      await pumpGlance(tester, faculty, date: DateTime(2026, 8, 26));

      expect(find.text('Wednesday'), findsOneWidget);
      expect(find.text('Your classes today'), findsOneWidget);

      final weekdayTop = tester.getTopLeft(find.text('Wednesday')).dy;
      final headingTop = tester.getTopLeft(find.text('Your classes today')).dy;
      expect(weekdayTop, lessThan(headingTop));
    });

    testWidgets('the rolls, and how many are left', (tester) async {
      await pumpGlance(
        tester,
        faculty,
        facts: const GlanceFacts(
          classes: [
            TodayClass(
              subject: 'Operating Systems',
              section: 'AIDS - Section A',
              rollTaken: true,
            ),
            TodayClass(
              subject: 'Computer Networks',
              section: 'IT - Section A',
              rollTaken: false,
            ),
          ],
        ),
      );

      expect(find.text('1 of 2 rolls taken'), findsOneWidget);
      expect(find.text('Operating Systems'), findsOneWidget);
      // Only the outstanding one is asking for anything.
      expect(find.text('Take roll'), findsOneWidget);
    });

    testWidgets('a roll row carries its exact timetable allocation', (
      tester,
    ) async {
      final opened = <TodayClass>[];
      await pumpGlance(
        tester,
        faculty,
        openedClasses: opened,
        facts: const GlanceFacts(
          classes: [
            TodayClass(
              subject: 'Exploratory Data Analysis',
              section: 'AIDS - Section A · Period 1',
              rollTaken: false,
              timetableEntryId: 'entry-eda',
              sectionId: 'section-aids',
              periodLabel: 'Period 1',
            ),
            TodayClass(
              subject: 'Java Programming',
              section: 'CSBS - Section A · Period 4',
              rollTaken: false,
              timetableEntryId: 'entry-jp-csbs',
              sectionId: 'section-csbs',
              periodLabel: 'Period 4',
            ),
          ],
        ),
      );

      await tester.tap(find.text('Java Programming'));
      await tester.pump();

      expect(opened, hasLength(1));
      expect(opened.single.timetableEntryId, 'entry-jp-csbs');
      expect(opened.single.sectionId, 'section-csbs');
      expect(opened.single.periodLabel, 'Period 4');
    });

    testWidgets('a finished day says so', (tester) async {
      await pumpGlance(
        tester,
        faculty,
        facts: const GlanceFacts(
          classes: [
            TodayClass(subject: 'A', section: 'S', rollTaken: true),
            TodayClass(subject: 'B', section: 'S', rollTaken: true),
          ],
        ),
      );

      expect(find.text('All 2 rolls taken'), findsOneWidget);
      expect(find.text('Take roll'), findsNothing);
    });

    testWidgets('no assignment is explained, not left blank', (tester) async {
      await pumpGlance(tester, faculty);
      expect(find.text('No classes assigned to you yet'), findsOneWidget);
    });
  });

  group('oversight reads volume and exceptions', () {
    testWidgets('stats appear as a band, and urgency is marked', (
      tester,
    ) async {
      await pumpGlance(
        tester,
        hod,
        facts: const GlanceFacts(
          stats: [
            OversightStat(
              label: 'rolls to review',
              value: '5',
              moduleId: ModuleCatalog.attendance,
              urgent: true,
            ),
            OversightStat(
              label: 'classes held',
              value: '18',
              moduleId: ModuleCatalog.attendance,
            ),
          ],
        ),
      );

      expect(find.text('Needs your attention'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('rolls to review'), findsOneWidget);
      // Not a learner's ring and not a teacher's checklist.
      expect(find.text('Take roll'), findsNothing);
    });

    testWidgets('a clear desk says so', (tester) async {
      await pumpGlance(tester, hod);
      expect(find.text('Nothing is waiting on you'), findsOneWidget);
    });
  });

  group('a counter reads the queue', () {
    testWidgets('as a strip that moves left to right', (tester) async {
      await pumpGlance(
        tester,
        shopOwner,
        facts: const GlanceFacts(
          queue: CounterQueue(waiting: 3, preparing: 2, ready: 1),
        ),
      );

      expect(find.text('At the counter'), findsOneWidget);
      expect(find.text('Waiting'), findsOneWidget);
      expect(find.text('Preparing'), findsOneWidget);
      expect(find.text('Ready'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('an empty counter is stated plainly', (tester) async {
      await pumpGlance(
        tester,
        shopOwner,
        facts: const GlanceFacts(
          queue: CounterQueue(waiting: 0, preparing: 0, ready: 0),
        ),
      );

      expect(find.text('No orders waiting'), findsOneWidget);
    });
  });

  group('nothing is invented while loading', () {
    testWidgets('a pending day shows progress, never a number', (tester) async {
      await pumpGlance(tester, student, facts: GlanceFacts.pending);

      expect(find.byType(SkeletonListRow), findsNWidgets(3));
      expect(find.textContaining('%'), findsNothing);
    });

    testWidgets('a shape with no today renders nothing', (tester) async {
      await pumpGlance(tester, grants({'documents.records.read'}));
      expect(find.byType(Card), findsNothing);
      expect(find.textContaining('Your'), findsNothing);
    });
  });
}
