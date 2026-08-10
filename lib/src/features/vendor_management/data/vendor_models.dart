enum VendorStatus { active, pending, suspended }

class Vendor {
  const Vendor({
    required this.id,
    required this.name,
    required this.category,
    required this.contact,
    required this.status,
  });
  final String id;
  final String name;
  final String category;
  final String contact;
  final VendorStatus status;
}

class PurchaseOrder {
  const PurchaseOrder({
    required this.id,
    required this.vendor,
    required this.amount,
    required this.status,
  });
  final String id;
  final String vendor;
  final double amount;
  final String status;
}

class VendorPayment {
  const VendorPayment({
    required this.id,
    required this.vendor,
    required this.amount,
    required this.date,
    required this.status,
  });
  final String id;
  final String vendor;
  final double amount;
  final String date;
  final String status;
}
