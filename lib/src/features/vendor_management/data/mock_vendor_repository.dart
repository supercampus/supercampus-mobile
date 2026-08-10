import 'vendor_models.dart';

class MockVendorRepository {
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
}
