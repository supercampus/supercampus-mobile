import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/core/access/effective_permissions.dart';
import 'package:supercampus_mobile/src/core/access/module_catalog.dart';
import 'package:supercampus_mobile/src/features/authentication/data/auth_repository.dart';
import 'package:supercampus_mobile/src/features/modules/data/glance_source.dart';
import 'package:supercampus_mobile/src/features/modules/presentation/module_dashboard_screen.dart';
import 'package:supercampus_mobile/src/features/modules/presentation/today_glance.dart';

class _GlanceSource implements GlanceSource {
  _GlanceSource(this.loadFacts);

  final Future<GlanceFacts> Function() loadFacts;
  int calls = 0;

  @override
  Future<GlanceFacts> load(DayShape shape) {
    calls++;
    return loadFacts();
  }
}

const _session = UserSession(
  email: 'student@mec.local',
  displayName: 'Student',
  role: UserRole.student,
);

final _permissions = EffectivePermissions(
  grants: const {'academics.marks.read'},
  scopes: const {ModuleCatalog.academics: PermissionScope.own},
);

Widget _dashboard(GlanceSource source, {required int revision}) => MaterialApp(
  home: ModuleDashboardScreen(
    session: _session,
    permissions: _permissions,
    glanceSource: source,
    glanceRevision: revision,
    onOpenModule: (_, [_]) {},
    onSignOut: () {},
    onThemeModeChanged: (_) {},
  ),
);

void main() {
  testWidgets('announcement carousel uses the selected date and page dots', (
    tester,
  ) async {
    final source = _GlanceSource(() async => const GlanceFacts());

    await tester.pumpWidget(_dashboard(source, revision: 0));
    await tester.pumpAndSettle();

    final card = tester.widget<Material>(
      find.byKey(const ValueKey('announcement-card')),
    );
    expect(card.color, const Color(0xFFF0F1F3));

    final datePanel = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('announcement-date-panel')),
    );
    expect(
      (datePanel.decoration as BoxDecoration).color,
      const Color(0xFFE3E5E8),
    );
    expect(
      find.byKey(const ValueKey('announcement-carousel-indicator')),
      findsOneWidget,
    );
    for (var index = 0; index < 4; index++) {
      expect(find.byKey(ValueKey('announcement-dot-$index')), findsOneWidget);
    }

    await tester.drag(
      find.byKey(const ValueKey('announcement-carousel')),
      const Offset(-400, 0),
    );
    await tester.pumpAndSettle();

    expect(find.text('FEE REMINDER'), findsOneWidget);
    expect(find.text('30'), findsOneWidget);
    expect(find.text('AUG'), findsOneWidget);
  });

  testWidgets(
    'parent rebuilds do not reload Your day and socket revisions do not flash',
    (tester) async {
      final initial = _GlanceSource(
        () async => const GlanceFacts(
          standing: AttendanceStanding(percentage: 91, attended: 10, total: 11),
        ),
      );
      final refreshed = Completer<GlanceFacts>();
      final replacement = _GlanceSource(() => refreshed.future);

      await tester.pumpWidget(_dashboard(initial, revision: 0));
      await tester.pump();
      expect(find.text('91% attendance'), findsOneWidget);
      expect(initial.calls, 1);

      // Repositories are inexpensive wrappers and can have a new identity
      // after an unrelated parent setState. That is not a data invalidation.
      await tester.pumpWidget(_dashboard(replacement, revision: 0));
      await tester.pump();
      expect(replacement.calls, 0);
      expect(find.text('91% attendance'), findsOneWidget);

      // A relevant WebSocket event increments the revision and fetches again,
      // but keeps the last truthful value visible until the request completes.
      await tester.pumpWidget(_dashboard(replacement, revision: 1));
      await tester.pump();
      expect(replacement.calls, 1);
      expect(find.text('91% attendance'), findsOneWidget);

      refreshed.complete(
        const GlanceFacts(
          standing: AttendanceStanding(percentage: 92, attended: 11, total: 12),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('92% attendance'), findsOneWidget);
    },
  );
}
