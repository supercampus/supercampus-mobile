import 'vendor_models.dart';
import 'vendor_repository.dart';

/// Stands in when the app runs without a campus server (demo builds).
///
/// It deliberately holds no sample shops, orders or sales: a figure on this
/// dashboard must always be one somebody measured, so offline it reads as an
/// empty campus rather than an invented one.
class OfflineVendorRepository implements VendorRepository {
  const OfflineVendorRepository();

  static const _offline =
      'Shops and sales need a connection to your campus server.';

  @override
  Future<List<VendorShop>> listVendors() async => const [];

  @override
  Future<VendorShop> createVendor(VendorShopDraft draft) =>
      Future.error(StateError(_offline));

  @override
  Future<VendorShop> updateVendor(String shopId, VendorShopDraft draft) =>
      Future.error(StateError(_offline));

  @override
  Future<void> toggleVendorStatus(VendorShop shop, bool active) =>
      Future.error(StateError(_offline));

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
}
