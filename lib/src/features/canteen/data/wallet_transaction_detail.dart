import 'canteen_models.dart';

/// Reads one of the signed-in user's own wallet transactions in full.
abstract interface class WalletTransactionDetailRepository {
  Future<WalletTransactionDetail> loadWalletTransaction(String transactionId);
}

/// What a wallet movement was, in the words a receipt uses.
enum WalletTransactionKind {
  orderPayment,
  laundryPayment,
  onlineTopUp,
  manualTopUp,
  refund,
  credit,
  debit,
}

extension WalletTransactionKindLabel on WalletTransactionKind {
  String get label => switch (this) {
    WalletTransactionKind.orderPayment => 'Order payment',
    WalletTransactionKind.laundryPayment => 'Laundry payment',
    WalletTransactionKind.onlineTopUp => 'Online top-up',
    WalletTransactionKind.manualTopUp => 'Wallet top-up',
    WalletTransactionKind.refund => 'Refund',
    WalletTransactionKind.credit => 'Wallet credit',
    WalletTransactionKind.debit => 'Wallet payment',
  };

  bool get isTopUp =>
      this == WalletTransactionKind.onlineTopUp ||
      this == WalletTransactionKind.manualTopUp;
}

/// One line of the order a transaction paid for, as snapshotted at checkout.
class ReceiptLine {
  const ReceiptLine({
    required this.name,
    required this.quantity,
    required this.unitPrice,
  });

  final String name;
  final int quantity;
  final double unitPrice;

  double get total => unitPrice * quantity;
}

class ReceiptOrder {
  const ReceiptOrder({
    required this.id,
    required this.displayNumber,
    required this.lines,
    required this.total,
    this.statusLabel,
    this.fulfilmentLabel,
  });

  final String id;

  /// The four-digit number the counter calls out, e.g. `0060`.
  final String displayNumber;
  final List<ReceiptLine> lines;
  final double total;
  final String? statusLabel;
  final String? fulfilmentLabel;
}

class ReceiptLaundry {
  const ReceiptLaundry({
    required this.name,
    required this.quantity,
    required this.unitLabel,
    required this.total,
    this.description,
    this.unitPrice,
  });

  final String name;
  final String? description;
  final double quantity;
  final String unitLabel;
  final double? unitPrice;
  final double total;
}

/// A wallet transaction with everything its details page and receipt show.
///
/// Every field is either reported by the server or read from the student's
/// own loaded data; anything unknown stays null so the page can leave the row
/// out rather than fill it with a placeholder.
class WalletTransactionDetail {
  const WalletTransactionDetail({
    required this.id,
    required this.amount,
    required this.description,
    required this.createdAt,
    this.shopKey,
    this.shopName,
    this.rawKind,
    this.referenceId,
    this.paymentId,
    this.balanceAfter,
    this.order,
    this.laundry,
    this.customerName,
    this.customerNumber,
    this.customerEmail,
    this.institutionName,
  });

  final String id;

  /// Signed: positive credits the wallet, negative debits it.
  final double amount;
  final String description;
  final DateTime createdAt;
  final String? shopKey;
  final String? shopName;
  final String? rawKind;
  final String? referenceId;

  /// The gateway payment id of an online top-up.
  final String? paymentId;
  final double? balanceAfter;
  final ReceiptOrder? order;
  final ReceiptLaundry? laundry;
  final String? customerName;
  final String? customerNumber;
  final String? customerEmail;
  final String? institutionName;

  bool get isCredit => amount > 0;

  WalletTransactionKind get kind {
    switch (rawKind) {
      case 'online_top_up':
        return WalletTransactionKind.onlineTopUp;
      case 'manual_top_up':
        return WalletTransactionKind.manualTopUp;
      case 'refund':
        return WalletTransactionKind.refund;
    }
    if (laundry != null || (shopKey ?? '').contains('laundry')) {
      if (!isCredit) return WalletTransactionKind.laundryPayment;
    }
    if (order != null || rawKind == 'order_debit') {
      return isCredit
          ? WalletTransactionKind.refund
          : WalletTransactionKind.orderPayment;
    }
    return isCredit
        ? WalletTransactionKind.credit
        : WalletTransactionKind.debit;
  }

  /// A ledger row is only written once the money has moved.
  String get statusLabel =>
      kind == WalletTransactionKind.refund ? 'Refunded' : 'Successful';

  /// Paid from the wallet, or paid into it through the gateway. A counter
  /// top-up's method is not recorded, so it has none.
  String? get paymentMethod => switch (kind) {
    WalletTransactionKind.onlineTopUp => 'Razorpay',
    WalletTransactionKind.manualTopUp || WalletTransactionKind.credit => null,
    _ => 'SuperCampus wallet',
  };

  /// The gateway's order id for an online top-up.
  String? get gatewayOrderId =>
      kind == WalletTransactionKind.onlineTopUp ? referenceId : null;

  String get _compactId => id.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');

  /// Short, stable handle for file names: the id's first eight characters.
  String get shortId {
    final compact = _compactId;
    return (compact.length > 8 ? compact.substring(0, 8) : compact)
        .toLowerCase();
  }

  String get receiptNumber => 'SC-${shortId.toUpperCase()}';

  String get receiptFileName => 'SuperCampus-receipt-$shortId.pdf';

  factory WalletTransactionDetail.fromJson(Map<String, dynamic> json) {
    final orderJson = _map(json['order']);
    final laundryJson = _map(json['laundryCharge']);
    final customer = _map(json['customer']);
    return WalletTransactionDetail(
      id: _text(json['id']) ?? '',
      amount: _number(json['amount']) ?? 0,
      description: _text(json['description']) ?? 'Wallet activity',
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
      shopKey: _text(json['shopKey']),
      shopName: _text(json['shopName']),
      rawKind: _text(json['transactionType']),
      referenceId: _text(json['referenceId']),
      paymentId: _text(json['paymentId']),
      balanceAfter: _number(json['balanceAfter']),
      order: orderJson.isEmpty ? null : _orderFromJson(orderJson),
      laundry: laundryJson.isEmpty ? null : _laundryFromJson(laundryJson),
      customerName: _text(customer['name']),
      customerNumber: _text(customer['studentNumber']),
      customerEmail: _text(customer['email']),
      institutionName: _text(json['institutionName']),
    );
  }

  /// Built from what the wallet already holds, for when the server's detail is
  /// unavailable: the order and laundry charge are matched by reference.
  factory WalletTransactionDetail.fromLocal(
    WalletTransaction transaction,
    CanteenStore store,
  ) {
    final reference = transaction.referenceId;
    CanteenOrder? order;
    LaundryCharge? laundry;
    if (reference != null) {
      for (final candidate in store.orders) {
        if (candidate.id == reference) order = candidate;
      }
      for (final candidate in store.laundryCharges) {
        if (candidate.id == reference) laundry = candidate;
      }
    }
    String? shopName;
    for (final shop in store.shops) {
      if (shop.shopKey == transaction.shopKey) shopName = shop.name;
    }
    final roll = store.user.rollNumber.trim();
    return WalletTransactionDetail(
      id: transaction.id,
      amount: transaction.signedAmount,
      description: transaction.description,
      createdAt: transaction.createdAt,
      shopKey: transaction.shopKey,
      shopName: shopName,
      rawKind: transaction.kind,
      referenceId: reference,
      order: order == null
          ? null
          : ReceiptOrder(
              id: order.id,
              displayNumber: order.displayId,
              lines: [
                for (final line in order.lines)
                  ReceiptLine(
                    name: line.item.name,
                    quantity: line.quantity,
                    unitPrice: line.item.price,
                  ),
              ],
              total: order.total,
              statusLabel: order.status.label,
              fulfilmentLabel: order.fulfilmentMode.label,
            ),
      laundry: laundry == null
          ? null
          : ReceiptLaundry(
              name: laundry.name,
              description: laundry.description.trim().isEmpty
                  ? null
                  : laundry.description,
              quantity: laundry.quantity,
              unitLabel: laundry.unitLabel,
              unitPrice: laundry.unitPrice > 0 ? laundry.unitPrice : null,
              total: laundry.total,
            ),
      customerName: _text(store.user.name),
      customerNumber: roll.isEmpty || roll == 'Not assigned' ? null : roll,
      customerEmail: _text(store.user.email),
    );
  }
}

ReceiptOrder _orderFromJson(Map<String, dynamic> json) {
  final id = _text(json['id']) ?? '';
  final statusName = _text(json['status']);
  CanteenOrderStatus? status;
  for (final value in CanteenOrderStatus.values) {
    if (value.apiValue == statusName) status = value;
  }
  final fulfilment = switch (_text(json['fulfilmentMode'])) {
    'dine_in' => FulfilmentMode.dineIn.label,
    'pickup' => FulfilmentMode.pickup.label,
    _ => null,
  };
  final lines = <ReceiptLine>[
    for (final raw
        in (json['lines'] is List ? json['lines'] as List : const []))
      if (raw is Map<String, dynamic>)
        ReceiptLine(
          name: _text(raw['name']) ?? 'Item',
          quantity: (_number(raw['quantity']) ?? 1).round(),
          unitPrice: _number(raw['price']) ?? 0,
        ),
  ];
  // The same display rule the order history uses, so `#0060` matches.
  final displayNumber = CanteenOrder(
    id: id,
    lines: const [],
    total: 0,
    status: CanteenOrderStatus.completed,
    fulfilmentMode: FulfilmentMode.pickup,
    createdAt: DateTime.fromMillisecondsSinceEpoch(0),
    orderNumber: json['orderNumber']?.toString(),
  ).displayId;
  return ReceiptOrder(
    id: id,
    displayNumber: displayNumber,
    lines: lines,
    total:
        _number(json['total']) ??
        lines.fold<double>(0, (sum, line) => sum + line.total),
    statusLabel: status?.label,
    fulfilmentLabel: fulfilment,
  );
}

ReceiptLaundry _laundryFromJson(Map<String, dynamic> json) => ReceiptLaundry(
  name: _text(json['name']) ?? 'Laundry service',
  description: _text(json['description']),
  quantity: _number(json['quantity']) ?? 0,
  unitLabel: _text(json['unitLabel']) ?? '',
  unitPrice: _number(json['unitPrice']),
  total: _number(json['total']) ?? 0,
);

Map<String, dynamic> _map(Object? value) =>
    value is Map<String, dynamic> ? value : const <String, dynamic>{};

String? _text(Object? value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

double? _number(Object? value) {
  if (value is num) return value.toDouble();
  if (value == null) return null;
  return double.tryParse(value.toString());
}
