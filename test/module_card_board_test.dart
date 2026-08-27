import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/core/access/academic_presentation.dart';
import 'package:supercampus_mobile/src/core/access/effective_permissions.dart';
import 'package:supercampus_mobile/src/core/access/module_catalog.dart';
import 'package:supercampus_mobile/src/features/modules/presentation/module_stack.dart';
import 'package:supercampus_mobile/src/features/modules/presentation/today_glance.dart';

/// Which board each persona's academic card is drawn on.
///
/// The streak strip is one person's sessions — present, absent, not taken yet
/// — so it belongs to the person being counted, not to the person doing the
/// counting. A learner's folded Academics entry carries it; staff, who mark a
/// whole class no single streak describes, get the plain three-tile board.
EffectivePermissions grants(
  Set<String> grants, {
  Map<String, PermissionScope> scopes = const {},
}) => EffectivePermissions(grants: grants, scopes: scopes);

Widget host(
  EffectivePermissions permissions, {
  ModuleCardContent content = const ModuleCardContent(),
}) {
  final modules = presentedModules(permissions);
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        height: ModuleStack.heightFor(modules.length),
        child: ModuleStack(
          modules: modules,
          permissions: permissions,
          onOpenModule: (_) {},
          content: content,
        ),
      ),
    ),
  );
}

/// The streak marks, left to right, by the colour each one is painted.
List<Color?> streakColours(WidgetTester tester) => tester
    .widgetList<Container>(find.byType(Container))
    .map((c) => c.decoration)
    .whereType<BoxDecoration>()
    .where((d) => d.borderRadius == BorderRadius.circular(12 * (157.0 / 360)))
    .map((d) => d.color)
    .toList();

/// The gradient of the one card on screen.
LinearGradient cardGradient(WidgetTester tester) => tester
    .widgetList<Container>(find.byType(Container))
    .map((c) => c.decoration)
    .whereType<BoxDecoration>()
    .map((d) => d.gradient)
    .whereType<LinearGradient>()
    .first;

/// student001@mec.local: reads its own record, approves nothing.
final learner = grants(
  {
    'academics.attendance.read',
    'academics.marks.read',
    'academics.analysis.read',
  },
  scopes: {ModuleCatalog.academics: PermissionScope.own},
);

/// faculty01@mec.local: marks other people's attendance.
final staff = grants(
  {
    'attendance.roster.read',
    'attendance.records.update',
    'attendance.reports.create',
  },
  scopes: {ModuleCatalog.attendance: PermissionScope.section},
);

void main() {
  group('learner Academics card', () {
    testWidgets('carries the streak, under the Academics name', (tester) async {
      await tester.pumpWidget(host(learner));
      await tester.pumpAndSettle();

      expect(find.text('Academics'), findsOneWidget);
      expect(find.text('Read only'), findsOneWidget);
      expect(find.text('last 7 attendance'), findsOneWidget);

      // A learner is never shown a module called Attendance; attendance is one
      // thing they look up inside Academics, not a place they go.
      expect(find.text('Attendance'), findsNothing);
    });

    testWidgets('is purple', (tester) async {
      await tester.pumpWidget(host(learner));
      await tester.pumpAndSettle();

      final gradient = cardGradient(tester);
      expect(gradient.colors.first, const Color(0xFF423A91));
      expect(gradient.colors.last, const Color(0xFF262458));
    });

    testWidgets('draws every mark grey until the standing lands', (
      tester,
    ) async {
      await tester.pumpWidget(host(learner));
      await tester.pumpAndSettle();

      expect(streakColours(tester), everyElement(const Color(0xFF7C7C7C)));
      expect(streakColours(tester), hasLength(attendanceStreakLength));
    });

    testWidgets('paints present, absent and OD with distinct colours', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          learner,
          content: const ModuleCardContent(
            attendanceMarks: [
              AttendanceMark.present,
              AttendanceMark.absent,
              AttendanceMark.present,
              AttendanceMark.present,
              AttendanceMark.onDuty,
              AttendanceMark.present,
              AttendanceMark.present,
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      const present = Color(0xFF1DCF00);
      const absent = Color(0xFFFF1723);
      const onDuty = Color(0xFFFFD600);
      expect(streakColours(tester), const [
        present,
        absent,
        present,
        present,
        onDuty,
        present,
        present,
      ]);
    });

    testWidgets('pads a short streak rather than inventing sessions', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          learner,
          content: const ModuleCardContent(
            attendanceMarks: [AttendanceMark.present, AttendanceMark.absent],
          ),
        ),
      );
      await tester.pumpAndSettle();

      const pending = Color(0xFF7C7C7C);
      expect(streakColours(tester).sublist(2), everyElement(pending));
    });
  });

  group('staff Attendance card', () {
    testWidgets('is the three-tile board, with no streak', (tester) async {
      await tester.pumpWidget(host(staff));
      await tester.pumpAndSettle();

      expect(find.text('Attendance'), findsOneWidget);
      expect(find.text('Create & edit'), findsOneWidget);
      expect(find.text("today's attendance"), findsNothing);

      expect(find.byIcon(Icons.fact_check_outlined), findsOneWidget);
      expect(find.byIcon(Icons.format_list_bulleted_add), findsOneWidget);
      expect(find.byIcon(Icons.auto_graph_rounded), findsOneWidget);
    });

    testWidgets('is green, so it never reads as the learner card', (
      tester,
    ) async {
      await tester.pumpWidget(host(staff));
      await tester.pumpAndSettle();

      final gradient = cardGradient(tester);
      expect(gradient.colors.first, const Color(0xFF217F49));
      expect(gradient.colors.last, const Color(0xFF12502D));
    });
  });
}
