import 'vendor_models.dart';
import 'vendor_repository.dart';

class MockVendorRepository implements VendorRepository {
  final List<VendorShop> _shops = [
    VendorShop(
      id: 'shop-1',
      shopKey: 'mec-canteen',
      name: 'Madras Kitchen',
      category: 'Canteen',
      description: 'Campus cafeteria & fresh meals',
      isActive: true,
      isOpen: true,
      mealCompliance: true,
      qrPayments: true,
      createdAt: DateTime.now().subtract(const Duration(days: 120)),
    ),
    VendorShop(
      id: 'shop-2',
      shopKey: 'mec-stationery',
      name: 'Stationery Store',
      category: 'Stationery',
      description: 'Academic stationery, books, and printing',
      isActive: true,
      isOpen: true,
      mealCompliance: false,
      qrPayments: true,
      createdAt: DateTime.now().subtract(const Duration(days: 90)),
    ),
    VendorShop(
      id: 'shop-3',
      shopKey: 'mec-laundry',
      name: 'Campus Laundry',
      category: 'Laundry',
      description: 'Hostel and campus laundry service',
      isActive: true,
      isOpen: true,
      mealCompliance: false,
      qrPayments: true,
      createdAt: DateTime.now().subtract(const Duration(days: 60)),
    ),
  ];

  final vendors = <Vendor>[
    const Vendor(
      id: 'VEN-001',
      name: 'FreshBite Supplies',
      category: 'Canteen & Mess',
      contact: 'ops@freshbite.example',
      status: VendorStatus.active,
    ),
    const Vendor(
      id: 'VEN-002',
      name: 'Campus Tech Systems',
      category: 'IT Services',
      contact: 'support@campustech.example',
      status: VendorStatus.active,
    ),
    const Vendor(
      id: 'VEN-003',
      name: 'GreenScape Works',
      category: 'Facilities',
      contact: 'hello@greenscape.example',
      status: VendorStatus.pending,
    ),
  ];

  final purchaseOrders = <PurchaseOrder>[
    const PurchaseOrder(
      id: 'PO-2026-041',
      vendor: 'FreshBite Supplies',
      amount: 128500,
      status: 'Approved',
    ),
    const PurchaseOrder(
      id: 'PO-2026-042',
      vendor: 'Campus Tech Systems',
      amount: 76400,
      status: 'Pending approval',
    ),
  ];

  final payments = <VendorPayment>[
    const VendorPayment(
      id: 'PAY-118',
      vendor: 'FreshBite Supplies',
      amount: 92000,
      date: '08 Aug 2026',
      status: 'Paid',
    ),
    const VendorPayment(
      id: 'PAY-117',
      vendor: 'Campus Tech Systems',
      amount: 45000,
      date: '02 Aug 2026',
      status: 'Processing',
    ),
  ];

  @override
  Future<List<VendorShop>> listVendors() async => List.unmodifiable(_shops);

  @override
  Future<VendorShop> createVendor(VendorShopDraft draft) async {
    final shop = VendorShop(
      id: 'shop-${DateTime.now().millisecondsSinceEpoch}',
      shopKey: draft.shopKey,
      name: draft.name,
      category: draft.category,
      description: draft.description,
      isActive: draft.isActive,
      isOpen: true,
      mealCompliance: draft.mealCompliance,
      qrPayments: draft.qrPayments,
      createdAt: DateTime.now(),
    );
    _shops.insert(0, shop);
    return shop;
  }

  @override
  Future<VendorShop> updateVendor(String shopId, VendorShopDraft draft) async {
    final idx = _shops.indexWhere((s) => s.id == shopId);
    if (idx < 0) throw Exception('Shop not found');
    final updated = _shops[idx].copyWith(
      shopKey: draft.shopKey,
      name: draft.name,
      category: draft.category,
      description: draft.description,
      isActive: draft.isActive,
      mealCompliance: draft.mealCompliance,
      qrPayments: draft.qrPayments,
      updatedAt: DateTime.now(),
    );
    _shops[idx] = updated;
    return updated;
  }

  @override
  Future<void> toggleVendorStatus(VendorShop shop, bool active) async {
    final idx = _shops.indexWhere((s) => s.id == shop.id);
    if (idx >= 0) {
      _shops[idx] = _shops[idx].copyWith(isActive: active);
    }
  }

  @override
  Future<SalesDashboardData> getSalesDashboard() async {
    return SalesDashboardData.defaults;
  }
}
