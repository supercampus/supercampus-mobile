import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/core/access/effective_permissions.dart';
import 'package:supercampus_mobile/src/core/access/module_catalog.dart';
import 'package:supercampus_mobile/src/core/access/portal_module_presentation.dart';
import 'package:supercampus_mobile/src/features/authentication/data/auth_repository.dart';
import 'package:supercampus_mobile/src/features/modules/presentation/widgets/home_sheets.dart';

void main() {
  test('saved module order keeps new and unknown modules safe', () {
    final modules = [
      ModuleCatalog.byId(ModuleCatalog.academics)!,
      ModuleCatalog.byId(ModuleCatalog.canteen)!,
      ModuleCatalog.byId(ModuleCatalog.gatepass)!,
    ];

    expect(
      orderModules(modules, const [
        'unknown',
        'gatepass',
        'academics',
      ]).map((module) => module.id),
      [ModuleCatalog.gatepass, ModuleCatalog.academics, ModuleCatalog.canteen],
    );
  });

  testWidgets('customization opens full screen with ordered module handles', (
    tester,
  ) async {
    List<String>? savedOrder;
    const permissions = EffectivePermissions(
      grants: {
        'academics.attendance.read',
        'canteen.menu.read',
        'gatepass.outpass.read',
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileSheet(
            session: const UserSession(
              email: 'student@mec.local',
              displayName: 'Student User',
              role: UserRole.student,
            ),
            permissions: permissions,
            moduleOrder: const ['gatepass', 'canteen', 'academics'],
            onModuleOrderChanged: (value) => savedOrder = value,
            onOpenModule: (_) {},
            onSignOut: () {},
            onThemeModeChanged: (_) {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Customization'));
    await tester.pumpAndSettle();

    expect(find.byType(AppBar), findsOneWidget);
    expect(find.text('Module sequence'), findsOneWidget);
    expect(find.byIcon(Icons.drag_handle_rounded), findsNWidgets(3));
    expect(
      tester.getTopLeft(find.text('Gatepass')).dy,
      lessThan(tester.getTopLeft(find.text('Shops')).dy),
    );

    await tester.tap(find.text('Reset'));
    await tester.pump();
    expect(savedOrder, isEmpty);
  });
}
