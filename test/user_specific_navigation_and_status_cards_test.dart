import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/core/widgets/campus_nav_bar.dart';
import 'package:supercampus_mobile/src/features/authentication/data/auth_repository.dart';
import 'package:supercampus_mobile/src/features/canteen/data/canteen_models.dart';
import 'package:supercampus_mobile/src/features/canteen/presentation/canteen_owner_home.dart';

void main() {
  group('User Permissions & QR Scan Access', () {
    test('canScanQr returns true only for authorized roles', () {
      const canteenOwner = UserSession(
        email: 'akhil@gmail.com',
        displayName: 'Akhil',
        role: UserRole.staff,
        roleId: 'owner',
        roleIds: ['owner'],
      );
      const stationeryOwner = UserSession(
        email: 'stationary@mec.local',
        displayName: 'Stationery Desk',
        role: UserRole.staff,
        roleId: 'stationery_owner',
        roleIds: ['stationery_owner'],
      );
      const laundryOwner = UserSession(
        email: 'laundry@mec.local',
        displayName: 'Laundry Desk',
        role: UserRole.staff,
        roleId: 'laundry_owner',
        roleIds: ['laundry_owner'],
      );
      const security = UserSession(
        email: 'security@mec.local',
        displayName: 'Security Guard',
        role: UserRole.security,
        roleId: 'security',
        roleIds: ['security'],
      );
      const captain = UserSession(
        email: 'captain@mec.local',
        displayName: 'Campus Captain',
        role: UserRole.staff,
        roleId: 'captain',
        roleIds: ['captain'],
      );
      const student = UserSession(
        email: 'student@mec.local',
        displayName: 'Student',
        role: UserRole.student,
        roleId: 'student',
        roleIds: ['student'],
      );
      const faculty = UserSession(
        email: 'faculty@mec.local',
        displayName: 'Faculty',
        role: UserRole.staff,
        roleId: 'faculty',
        roleIds: ['faculty'],
      );
      const admin = UserSession(
        email: 'admin@mec.local',
        displayName: 'Admin',
        role: UserRole.admin,
        roleId: 'admin',
        roleIds: ['admin'],
      );

      expect(canteenOwner.canScanQr, isTrue);
      expect(stationeryOwner.canScanQr, isTrue);
      expect(laundryOwner.canScanQr, isTrue);
      expect(security.canScanQr, isTrue);
      expect(captain.canScanQr, isTrue);

      expect(student.canScanQr, isFalse);
      expect(faculty.canScanQr, isFalse);
      expect(admin.canScanQr, isFalse);
    });
  });

  group('CampusNavBar Redesign', () {
    testWidgets('CampusNavBar has no center avatar and toggles Scan button',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: CampusNavBar(
              onHome: () {},
              onModules: () {},
              showScan: true,
              onScan: () {},
            ),
          ),
        ),
      );

      // Verify Scan button exists when showScan is true
      expect(find.text('Scan'), findsOneWidget);
      // Verify center avatar does not exist
      expect(find.byType(CircleAvatar), findsNothing);

      // Re-pump with showScan = false
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: CampusNavBar(
              onHome: () {},
              onModules: () {},
              showScan: false,
            ),
          ),
        ),
      );

      // Verify Scan button does NOT exist
      expect(find.text('Scan'), findsNothing);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Modules'), findsOneWidget);
    });
  });

  group('CanteenOwnerHome Enhancements', () {
    const sampleStore = CanteenStore(
      user: CanteenUser(
        name: 'Akhil',
        email: 'akhil@gmail.com',
        rollNumber: 'STAFF01',
        department: 'Canteen',
      ),
      menu: [
        CanteenMenuItem(
          id: 'item_1',
          name: 'Veg Meals',
          description: 'Delicious hot lunch',
          category: 'Meals',
          price: 50.0,
          isVegetarian: true,
          isAvailable: true,
        ),
        CanteenMenuItem(
          id: 'item_2',
          name: 'Tea',
          description: 'Hot spiced chai',
          category: 'Beverages',
          price: 10.0,
          isVegetarian: true,
          isAvailable: false,
        ),
      ],
      orders: [],
      walletTransactions: [],
      shops: [
        CanteenShop(
          id: '1',
          shopKey: 'classic',
          name: 'Campus Canteen',
          category: 'Food',
          isOpen: true,
        ),
      ],
      assignedShopKeys: ['classic'],
    );

    testWidgets('No "✓ Campus Canteen" chip when single shop assigned',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CanteenOwnerHome(
              store: sampleStore,
              onExitModule: () {},
              onSignOut: () {},
              onRefresh: () async {},
              onModeChanged: (_) async {},
              onShopOpenChanged: (_) async {},
              onOrderStatusChanged: (_, __) async {},
              onSaveMenuItem: (_, __) async {},
              onDeleteMenuItem: (_) async {},
              onUploadMedia: (_, __) async => '',
            ),
          ),
        ),
      );

      expect(find.text('✓ Campus Canteen'), findsNothing);
      expect(find.text('Shop operations'), findsOneWidget);
    });

    testWidgets('Has search field and toggle switch on each menu item',
        (tester) async {
      CanteenMenuItem? updatedItem;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CanteenOwnerHome(
              store: sampleStore,
              onExitModule: () {},
              onSignOut: () {},
              onRefresh: () async {},
              onModeChanged: (_) async {},
              onShopOpenChanged: (_) async {},
              onOrderStatusChanged: (_, __) async {},
              onSaveMenuItem: (item, isNew) async {
                updatedItem = item;
              },
              onDeleteMenuItem: (_) async {},
              onUploadMedia: (_, __) async => '',
            ),
          ),
        ),
      );

      // Switch to Menu tab (index 1)
      final menuTab = find.text('Menu');
      expect(menuTab, findsOneWidget);
      await tester.tap(menuTab);
      await tester.pumpAndSettle();

      // Verify Search field exists
      final searchField = find.byType(TextField);
      expect(searchField, findsOneWidget);

      // Search for 'Tea'
      await tester.enterText(searchField, 'Tea');
      await tester.pumpAndSettle();

      // Veg Meals should be filtered out, Tea item card should be visible
      expect(
        find.byWidgetPredicate((w) => w is Text && w.data == 'Tea'),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate((w) => w is Text && w.data == 'Veg Meals'),
        findsNothing,
      );

      // Find switch on Tea card and toggle it
      final switches = find.byType(Switch);
      expect(switches, findsOneWidget);
      await tester.tap(switches.first);
      await tester.pumpAndSettle();

      expect(updatedItem, isNotNull);
      expect(updatedItem!.id, 'item_2');
      expect(updatedItem!.isAvailable, isTrue);
    });
  });
}
