import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/core/access/effective_permissions.dart';
import 'package:supercampus_mobile/src/core/access/module_catalog.dart';
import 'package:supercampus_mobile/src/core/theme/app_theme.dart';
import 'package:supercampus_mobile/src/features/authentication/data/auth_repository.dart';
import 'package:supercampus_mobile/src/features/modules/data/glance_source.dart';
import 'package:supercampus_mobile/src/features/modules/presentation/module_dashboard_screen.dart';
import 'package:supercampus_mobile/src/features/modules/presentation/module_stack.dart';
import 'package:supercampus_mobile/src/features/modules/presentation/today_glance.dart';

void main() {
  testWidgets('gatepass QR is square and centered inside its module panel', (
    tester,
  ) async {
    const permissions = EffectivePermissions(
      grants: {
        'gatepass.outpass.read',
        'gatepass.visitor.read',
        'gatepass.access.read',
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: ModuleStack.heightFor(1),
            child: ModuleStack(
              modules: [ModuleCatalog.byId(ModuleCatalog.gatepass)!],
              permissions: permissions,
              onOpenModule: (_) {},
              content: const ModuleCardContent(
                gatepassQr: 'SC-GATE-ALIGNMENT-TEST',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final panelRect = tester.getRect(
      find.byKey(const ValueKey('gatepass-qr-panel')),
    );
    final qrRect = tester.getRect(
      find.byKey(const ValueKey('gatepass-qr-code-frame')),
    );

    expect(qrRect.width, closeTo(qrRect.height, 0.01));
    expect(qrRect.center.dx, closeTo(panelRect.center.dx, 0.01));
    expect(qrRect.center.dy, closeTo(panelRect.center.dy, 0.01));
  });

  testWidgets('announcement card uses high-contrast dark theme colors', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.dark,
        home: ModuleDashboardScreen(
          session: const UserSession(
            email: 'student@mec.local',
            displayName: 'Student',
            role: UserRole.student,
          ),
          permissions: const EffectivePermissions.empty(),
          glanceSource: _EmptyGlanceSource(),
          onOpenModule: (_) {},
          onSignOut: () {},
          onThemeModeChanged: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final card = tester.widget<Material>(
      find.byKey(const ValueKey('announcement-card')),
    );
    expect(card.color, const Color(0xFF1D1A24));

    final datePanel = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('announcement-date-panel')),
    );
    expect(
      (datePanel.decoration as BoxDecoration).color,
      const Color(0xFF292431),
    );

    final title = tester.widget<Text>(
      find.text('Mid-Semester Exam Schedule Revision'),
    );
    expect(title.style?.color, AppTheme.dark.colorScheme.onSurface);
  });
}

class _EmptyGlanceSource implements GlanceSource {
  const _EmptyGlanceSource();

  @override
  Future<GlanceFacts> load(DayShape shape) async => const GlanceFacts();
}
