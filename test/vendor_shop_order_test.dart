import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/core/access/effective_permissions.dart';
import 'package:supercampus_mobile/src/core/theme/app_theme.dart';
import 'package:supercampus_mobile/src/features/authentication/data/auth_repository.dart';
import 'package:supercampus_mobile/src/features/vendor_management/data/vendor_models.dart';
import 'package:supercampus_mobile/src/features/vendor_management/data/vendor_repository.dart';
import 'package:supercampus_mobile/src/features/vendor_management/presentation/vendor_management_shell.dart';

const _admin = UserSession(
  email: 'admin@mec.local',
  displayName: 'MEC Admin',
  role: UserRole.admin,
  roleId: 'tenant_admin',
  roleIds: ['tenant_admin'],
);

VendorShop _shop(String key, String name, String category) => VendorShop(
  id: 'id-$key',
  shopKey: key,
  name: name,
  category: category,
  description: '',
  isActive: true,
  isOpen: true,
);

class _ArrangingRepository implements VendorRepository, ShopAdministration {
  List<VendorShop> shops = [
    _shop('mec-canteen', 'Canteen', 'canteen'),
    _shop('mec-laundry', 'Campus Laundry', 'laundry'),
    _shop('mec-stationery', 'Campus Stationery', 'stationery'),
  ];
  final saved = <List<String>>[];

  @override
  Future<List<VendorShop>> reorderVendors(List<String> shopKeys) async {
    saved.add(shopKeys);
    shops = [
      for (final key in shopKeys) shops.firstWhere((s) => s.shopKey == key),
    ];
    return shops;
  }

  @override
  Future<List<ShopStaffCandidate>> listShopStaffCandidates() async => const [];

  @override
  Future<List<VendorShop>> listVendors() async => shops;

  @override
  Future<SalesDashboardData> getSalesDashboard({
    SalesPeriod period = SalesPeriod.today,
  }) async => SalesDashboardData(period: period);

  @override
  Future<SalesOrderPage> listSalesOrders({
    SalesPeriod period = SalesPeriod.all,
    String? shopKey,
    OrderStatusFilter status = OrderStatusFilter.all,
    int limit = 100,
  }) async => const SalesOrderPage();

  @override
  Future<VendorShop> createVendor(VendorShopDraft draft) =>
      throw UnimplementedError();

  @override
  Future<VendorShop> updateVendor(String shopId, VendorShopDraft draft) =>
      throw UnimplementedError();

  @override
  Future<void> toggleVendorStatus(VendorShop shop, bool active) =>
      throw UnimplementedError();
}

Future<void> _openVendors(
  WidgetTester tester,
  VendorRepository repository, {
  Set<String> grants = const {'*'},
}) async {
  tester.view.physicalSize = const Size(390, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: VendorManagementShell(
        session: _admin,
        onExitModule: () {},
        repository: repository,
        permissions: EffectivePermissions(grants: grants),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Vendors'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the admin drags shops into their own order and saves it', (
    tester,
  ) async {
    final repository = _ArrangingRepository();
    await _openVendors(tester, repository);

    await tester.tap(find.text('Arrange'));
    await tester.pumpAndSettle();
    expect(find.text('Arrange shops'), findsOneWidget);

    // Drag Campus Stationery (third) above Canteen (first).
    final handle = find.byIcon(Icons.drag_handle_rounded).at(2);
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump(const Duration(milliseconds: 50));
    for (var i = 0; i < 20; i++) {
      await gesture.moveBy(const Offset(0, -12));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.saved, hasLength(1));
    expect(repository.saved.single.first, 'mec-stationery');
    expect(repository.saved.single.toSet(), {
      'mec-canteen',
      'mec-laundry',
      'mec-stationery',
    });
    expect(find.text('Arrange shops'), findsNothing);
    // The register now lists shops in the saved order.
    final stationery = tester.getTopLeft(find.text('Campus Stationery')).dy;
    // (Category chips also read "Canteen"; the shop row is the last match.)
    final canteen = tester.getTopLeft(find.text('Canteen').last).dy;
    final laundry = tester.getTopLeft(find.text('Campus Laundry')).dy;
    expect(stationery, lessThan(canteen));
    expect(stationery, lessThan(laundry));
  });

  testWidgets('cancel leaves the order untouched', (tester) async {
    final repository = _ArrangingRepository();
    await _openVendors(tester, repository);

    await tester.tap(find.text('Arrange'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repository.saved, isEmpty);
    expect(find.text('Arrange'), findsOneWidget);
  });

  testWidgets('without the shop update grant there is nothing to arrange', (
    tester,
  ) async {
    await _openVendors(
      tester,
      _ArrangingRepository(),
      grants: {'vendor_management.vendors.read'},
    );
    expect(find.text('Campus Laundry'), findsOneWidget);
    expect(find.text('Arrange'), findsNothing);
  });

  test('live counters follow the administrator\'s positions', () {
    StoreSales store(String name, int? position) => StoreSales(
      shopKey: name,
      name: name,
      category: 'Other',
      position: position,
    );
    final stores = [store('A', 2), store('Z', 0), store('M', null), store('B', 1)]
      ..sort(compareStoresByPosition);
    expect(stores.map((s) => s.name), ['Z', 'B', 'A', 'M']);
  });

  test('shop staff are recognised by permissions, not role names', () {
    expect(grantsShopCounterWork(['canteen.orders.manage']), isTrue);
    expect(grantsShopCounterWork(['canteen.menu.update']), isTrue);
    expect(
      grantsShopCounterWork([
        'canteen.orders.manage',
        'vendor_management.vendors.update',
      ]),
      isFalse,
    );
    expect(grantsShopCounterWork(['canteen.wallet.read']), isFalse);
    expect(suggestedShopRole(['canteen.orders.manage']), 'captain');
    expect(
      suggestedShopRole(['canteen.orders.manage', 'canteen.menu.create']),
      'owner',
    );
  });
}
