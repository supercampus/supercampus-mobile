import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/core/access/effective_permissions.dart';
import 'package:supercampus_mobile/src/core/widgets/campus_nav_bar.dart';
import 'package:supercampus_mobile/src/features/authentication/data/auth_repository.dart';
import 'package:supercampus_mobile/src/features/modules/presentation/module_navigation_host.dart';

void main() {
  test('the official campus bar is the only docked app navigation', () {
    final root = Directory('lib/src');
    final dockedNavigation = RegExp(
      r'\b(?:BottomNavigationBar|NavigationBar)\s*\(',
    );
    final files = root
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .where((file) => dockedNavigation.hasMatch(file.readAsStringSync()))
        .map((file) => file.path.replaceAll('\\', '/'))
        .toSet();

    expect(
      files,
      isEmpty,
      reason:
          'Every persona lands in the shared portal. Module sections must use the shared in-page switcher so no role can create a second docked bar.',
    );
  });

  testWidgets('official module nav owns a reserved non-overlapping lane', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: ModuleNavigationHost(
          session: const UserSession(
            email: 'student@mec.local',
            displayName: 'Student User',
            role: UserRole.student,
          ),
          permissions: const EffectivePermissions.empty(),
          onExitModule: () {},
          onOpenModule: (_) {},
          onSignOut: () {},
          onThemeModeChanged: (_) {},
          child: const Scaffold(
            key: ValueKey('module-surface'),
            body: SizedBox.expand(),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(CampusNavBar), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(BottomNavigationBar), findsNothing);

    final moduleBottom = tester
        .getRect(find.byKey(const ValueKey('module-surface')))
        .bottom;
    final officialTop = tester.getRect(find.byType(CampusNavBar)).top;
    expect(moduleBottom, lessThanOrEqualTo(officialTop));
  });
}
