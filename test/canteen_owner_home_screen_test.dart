import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/core/access/effective_permissions.dart';
import 'package:supercampus_mobile/src/features/authentication/data/auth_repository.dart';
import 'package:supercampus_mobile/src/features/canteen/data/mock_canteen_repository.dart';
import 'package:supercampus_mobile/src/features/modules/presentation/module_dashboard_screen.dart';
import 'package:supercampus_mobile/src/core/widgets/campus_nav_bar.dart';

void main() {
  group('Canteen Owner Identity & Home Page Tests', () {
    test('akhil@gmail.com is identified as canteen owner and not faculty', () {
      const session = UserSession(
        email: 'akhil@gmail.com',
        displayName: 'Akhil',
        role: UserRole.staff,
        roleId: 'owner',
        roleIds: ['owner'],
      );

      expect(session.isCanteenOwner, isTrue);
      expect(session.isFaculty, isFalse);
      expect(session.isAdmin, isFalse);
      expect(session.isStudent, isFalse);
      expect(session.roleBadgeText, 'OWNER');
      expect(session.roleDisplayTitle, 'Canteen & Food Court Owner Workspace');
    });

    testWidgets(
      'akhil@gmail.com renders Shop operations (Image 2) as actual home page without faculty cards',
      (tester) async {
        const session = UserSession(
          email: 'akhil@gmail.com',
          displayName: 'Akhil',
          role: UserRole.staff,
          roleId: 'owner',
          roleIds: ['owner'],
        );

        final permissions = const EffectivePermissions(
          grants: {
            'canteen.menu.read',
            'canteen.menu.create',
            'canteen.menu.update',
            'canteen.menu.delete',
            'canteen.order.read',
            'canteen.order.update',
            'attendance.mark.read',
            'timetable.schedule.read',
          },
        );

        final repository = MockCanteenRepository(
          studentName: 'Akhil',
          email: 'akhil@gmail.com',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: ModuleDashboardScreen(
              session: session,
              permissions: permissions,
              onOpenModule: (id, [action]) {},
              onSignOut: () {},
              onThemeModeChanged: (_) {},
              canteenRepository: repository,
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Verify Image 2 (Shop operations / Owner workspace) is the home page
        expect(find.text('Shop operations'), findsOneWidget);
        expect(find.text('Owner workspace'), findsOneWidget);
        expect(find.text('Campus Canteen'), findsOneWidget);
        // No section tabs at the top: the sections are the bar's destinations.
        expect(find.text('Orders'), findsNothing);
        expect(find.text('Sales & Profit'), findsNothing);
        expect(find.text('Live order queue'), findsOneWidget);
        // The counter switch moved to the profile.
        expect(find.text('Counter open'), findsNothing);

        // Verify CampusNavBar is present at the bottom
        final bar = find.byType(CampusNavBar);
        expect(bar, findsOneWidget);
        for (final label in ['Home', 'Menu', 'Settled', 'Sales']) {
          expect(
            find.descendant(of: bar, matching: find.text(label)),
            findsOneWidget,
          );
        }
        expect(find.text('Modules'), findsNothing);

        // The bar's Menu opens the owner's menu management, and marks Menu.
        await tester.tap(find.byKey(const ValueKey('nav-menu')));
        await tester.pumpAndSettle();
        expect(find.text('Menu management'), findsOneWidget);
        expect(find.text('Orders'), findsNothing);
        expect(find.text('Sales & Profit'), findsNothing);
        expect(
          tester
              .widget<Text>(
                find.descendant(of: bar, matching: find.text('Menu')),
              )
              .style!
              .fontWeight,
          FontWeight.w700,
        );

        await tester.tap(find.byKey(const ValueKey('nav-settled')));
        await tester.pumpAndSettle();
        expect(find.text('Settled orders'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('nav-sales')));
        await tester.pumpAndSettle();
        expect(find.text('Sales & Profit Analytics'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('nav-home')));
        await tester.pumpAndSettle();
        expect(find.text('Live order queue'), findsOneWidget);

        // The profile sheet carries Counter open, beside Settings.
        await tester.tap(find.byIcon(Icons.person).first);
        await tester.pumpAndSettle();
        expect(find.text('Counter open'), findsOneWidget);
        expect(find.text('Taking new orders'), findsOneWidget);
        expect(find.text('Settings'), findsOneWidget);
        expect(
          tester.getRect(find.text('Counter open')).top,
          lessThan(tester.getRect(find.text('Settings')).top),
        );
        await tester.tap(find.byKey(const ValueKey('counter-open-switch')));
        await tester.pumpAndSettle();
        expect(find.text('Counter closed'), findsOneWidget);
        expect(find.text('Not taking new orders'), findsOneWidget);
        Navigator.of(tester.element(find.text('Settings'))).pop();
        await tester.pumpAndSettle();

        // Verify faculty cards from Image 1 are NOT displayed
        expect(find.text('Take Roll Call'), findsNothing);
        expect(find.text('My Schedule'), findsNothing);
        expect(find.text("Today's Mark"), findsNothing);
        expect(find.text('Attendance Desk'), findsNothing);
        expect(find.text('Lectures'), findsNothing);
      },
    );
  });
}
