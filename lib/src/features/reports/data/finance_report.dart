import 'package:flutter/material.dart';

import '../../../core/access/effective_permissions.dart';
import '../../../core/theme/app_theme.dart';

/// Whether these grants may generate finance reports: tenant-wide sales and
/// every member's wallet ledger. Matches the backend's `REPORT_GRANTS`, so
/// the entry is shown only to people whose reports will actually load.
bool canGenerateFinanceReports(EffectivePermissions permissions) =>
    permissions.can('canteen', 'analytics', 'read') &&
    permissions.can('canteen', 'wallet', 'top_up');

/// One kind of report on the "Report Kind" grid, and which parameters it asks
/// for. Keys match `GET /api/v1/operations/reports/{kind}`.
class ReportKindSpec {
  const ReportKindSpec({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.monthly = false,
    this.snapshot = false,
    this.shop = ReportShopMode.optional,
    this.pickItems = false,
    this.maxDays = 731,
    this.requiredGrant,
  });

  final String key;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  /// Settles by calendar month instead of a free date range.
  final bool monthly;

  /// A point-in-time picture ("as of now"): no period to choose.
  final bool snapshot;
  final ReportShopMode shop;

  /// Asks which menu items to include (Parameter Sales).
  final bool pickItems;

  /// Longest date range the backend accepts for this kind.
  final int maxDays;

  /// A grant this kind needs on top of the report grants (fee records), as
  /// `module.feature.action`. Matches the backend's `extra_grant`.
  final String? requiredGrant;

  bool get usesPeriod => !snapshot;

  /// Whether these grants may open this kind (the report grants are checked
  /// before the page is reachable at all).
  bool allowedFor(EffectivePermissions permissions) {
    final grant = requiredGrant;
    if (grant == null) return true;
    final parts = grant.split('.');
    return parts.length == 3 && permissions.can(parts[0], parts[1], parts[2]);
  }

  static List<ReportKindSpec> allowed(EffectivePermissions? permissions) => [
    for (final kind in all)
      if (permissions == null || kind.allowedFor(permissions)) kind,
  ];

  static ReportKindSpec? byKey(String key) {
    for (final kind in all) {
      if (kind.key == key) return kind;
    }
    return null;
  }

  static const all = <ReportKindSpec>[
    ReportKindSpec(
      key: 'master',
      title: 'Master Report',
      subtitle: 'Full operations: sales, vendors, ledger',
      icon: Icons.summarize_rounded,
      color: AppColors.brandPurple,
    ),
    ReportKindSpec(
      key: 'daily_sales',
      title: 'Daily Sales Summary',
      subtitle: 'Completed sales, orders and cancellations by day and shop',
      icon: Icons.calendar_view_day_rounded,
      color: AppColors.success,
    ),
    ReportKindSpec(
      key: 'item_sales',
      title: 'Item-wise Sales',
      subtitle: 'Top items with quantity, revenue, cost and profit',
      icon: Icons.leaderboard_rounded,
      color: AppColors.brandPurple,
    ),
    ReportKindSpec(
      key: 'captain_performance',
      title: 'Captain Performance',
      subtitle: 'Orders handled, revenue and handling time per staff member',
      icon: Icons.badge_rounded,
      color: AppColors.brandViolet,
    ),
    ReportKindSpec(
      key: 'hourly_sales',
      title: 'Hourly Sales',
      subtitle: 'Sales by hour of the day and day of the week',
      icon: Icons.schedule_rounded,
      color: AppColors.orangeInk,
    ),
    ReportKindSpec(
      key: 'credits',
      title: 'Credits',
      subtitle: 'Wallet top-ups and credit transactions',
      icon: Icons.south_west_rounded,
      color: AppColors.success,
    ),
    ReportKindSpec(
      key: 'debits',
      title: 'Debits',
      subtitle: 'Purchases and wallet debit transactions',
      icon: Icons.north_east_rounded,
      color: AppColors.hotPinkInk,
    ),
    ReportKindSpec(
      key: 'refunds',
      title: 'Refunds',
      subtitle: 'Order refunds and reversal transactions',
      icon: Icons.undo_rounded,
      color: AppColors.orangeInk,
    ),
    ReportKindSpec(
      key: 'top_ups',
      title: 'Wallet Top-ups',
      subtitle: 'Top-ups by source, payment method and day',
      icon: Icons.add_card_rounded,
      color: AppColors.success,
    ),
    ReportKindSpec(
      key: 'deductions',
      title: 'Accountant Deductions',
      subtitle: 'Manual wallet deductions with the reason and who made them',
      icon: Icons.remove_circle_outline_rounded,
      color: AppColors.hotPinkInk,
    ),
    ReportKindSpec(
      key: 'wallet_balances',
      title: 'Wallet Balances',
      subtitle: 'Current balance of every wallet, overdrawn first',
      icon: Icons.account_balance_wallet_outlined,
      color: AppColors.infoInk,
      snapshot: true,
    ),
    ReportKindSpec(
      key: 'vendor_payable',
      title: 'Vendor Payable',
      subtitle: 'Monthly vendor settlement statement',
      icon: Icons.handshake_outlined,
      color: AppColors.infoInk,
      monthly: true,
    ),
    ReportKindSpec(
      key: 'shop_transactions',
      title: 'Shop-wise Transactions',
      subtitle: 'Monthly shop ledger with payable calculations',
      icon: Icons.storefront_rounded,
      color: AppColors.infoInk,
      monthly: true,
      shop: ReportShopMode.required,
    ),
    ReportKindSpec(
      key: 'accountant_credits',
      title: 'Accountant Credits',
      subtitle: 'Credits manually added by the accountant',
      icon: Icons.person_add_alt_1_rounded,
      color: AppColors.brandViolet,
    ),
    ReportKindSpec(
      key: 'parameter_sales',
      title: 'Parameter Sales',
      subtitle: 'Sales and count for selected menu items in the period',
      icon: Icons.tune_rounded,
      color: AppColors.brandPurple,
      pickItems: true,
    ),
    ReportKindSpec(
      key: 'cancelled_orders',
      title: 'Rejected & Cancelled',
      subtitle: 'Rejected and cancelled orders and charges, with reasons',
      icon: Icons.cancel_outlined,
      color: AppColors.hotPinkInk,
    ),
    ReportKindSpec(
      key: 'laundry_charges',
      title: 'Laundry Charges',
      subtitle: 'Laundry charges paid, pending and cancelled',
      icon: Icons.local_laundry_service_rounded,
      color: AppColors.infoInk,
    ),
    ReportKindSpec(
      key: 'payment_requests',
      title: 'Payment Requests',
      subtitle: 'Requests issued, paid, pending and overdue by purpose',
      icon: Icons.request_quote_rounded,
      color: AppColors.orangeInk,
      shop: ReportShopMode.none,
      requiredGrant: 'fees.payment_requests.read',
    ),
    ReportKindSpec(
      key: 'online_payments',
      title: 'Online Payments',
      subtitle: 'Razorpay payments captured, settled and pending',
      icon: Icons.credit_score_rounded,
      color: AppColors.brandPurple,
      shop: ReportShopMode.none,
      requiredGrant: 'fees.online_payments.read',
    ),
    ReportKindSpec(
      key: 'student_spending',
      title: 'Student Spending',
      subtitle: 'Wallet spending by department and batch',
      icon: Icons.school_rounded,
      color: AppColors.brandViolet,
    ),
    ReportKindSpec(
      key: 'student_eod_wallet',
      title: 'Student EOD Wallet',
      subtitle: 'Day-wise end-of-day wallet balance for every student',
      icon: Icons.account_balance_wallet_rounded,
      color: AppColors.brandPurple,
      maxDays: 31,
    ),
  ];
}

enum ReportShopMode { none, optional, required }

/// What one report is asked for.
class ReportRequest {
  const ReportRequest({
    required this.kind,
    this.from,
    this.to,
    this.month,
    this.shopKey,
    this.itemIds = const [],
  });

  final String kind;
  final DateTime? from;
  final DateTime? to;

  /// Any day inside the month, for monthly kinds.
  final DateTime? month;
  final String? shopKey;
  final List<String> itemIds;

  Map<String, String> toQuery() => {
    if (month != null) 'month': _month(month!),
    if (month == null && from != null) 'from': reportDay(from!),
    if (month == null && to != null) 'to': reportDay(to!),
    if (shopKey != null && shopKey!.isNotEmpty) 'shop': shopKey!,
    if (itemIds.isNotEmpty) 'items': itemIds.join(','),
  };

  static String _month(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}';
}

/// `2026-09-05`.
String reportDay(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

class ReportShop {
  const ReportShop({
    required this.shopKey,
    required this.name,
    this.category = '',
  });

  final String shopKey;
  final String name;
  final String category;
}

class ReportMenuItem {
  const ReportMenuItem({
    required this.id,
    required this.name,
    required this.shopKey,
    required this.shopName,
    this.price = 0,
  });

  final String id;
  final String name;
  final String shopKey;
  final String shopName;
  final double price;
}

class ReportOptions {
  const ReportOptions({
    this.shops = const [],
    this.menuItems = const [],
    this.today,
  });

  final List<ReportShop> shops;
  final List<ReportMenuItem> menuItems;

  /// The campus's calendar day (the server's, not the device's).
  final DateTime? today;

  factory ReportOptions.fromJson(Map<String, dynamic> json) => ReportOptions(
    shops: [
      for (final shop in _maps(json['shops']))
        ReportShop(
          shopKey: _text(shop['shopKey']),
          name: _text(shop['name'], fallback: _text(shop['shopKey'])),
          category: _text(shop['category']),
        ),
    ],
    menuItems: [
      for (final item in _maps(json['menuItems']))
        ReportMenuItem(
          id: _text(item['id']),
          name: _text(item['name'], fallback: 'Item'),
          shopKey: _text(item['shopKey']),
          shopName: _text(item['shopName'], fallback: _text(item['shopKey'])),
          price: _number(item['price']) ?? 0,
        ),
    ],
    today: DateTime.tryParse(_text(json['today'])),
  );
}

class ReportColumn {
  const ReportColumn({
    required this.key,
    required this.label,
    this.format = 'text',
  });

  final String key;
  final String label;

  /// text | money | number | datetime | date
  final String format;

  bool get isNumeric => format == 'money' || format == 'number';
}

class ReportTable {
  const ReportTable({
    required this.title,
    required this.columns,
    this.rows = const [],
    this.totals,
  });

  final String title;
  final List<ReportColumn> columns;
  final List<Map<String, dynamic>> rows;
  final Map<String, dynamic>? totals;
}

class ReportStat {
  const ReportStat({
    required this.label,
    required this.value,
    this.format = 'number',
  });

  final String label;
  final double value;
  final String format;
}

/// A generated report exactly as the server computed it. PDF and CSV are both
/// rendered from this, so the two files always agree.
class FinanceReport {
  const FinanceReport({
    required this.kind,
    required this.title,
    this.description = '',
    this.from = '',
    this.to = '',
    this.periodLabel = '',
    this.shopName,
    this.institutionName,
    this.generatedAt = '',
    this.available = true,
    this.notes = const [],
    this.summary = const [],
    this.tables = const [],
  });

  final String kind;
  final String title;
  final String description;
  final String from;
  final String to;
  final String periodLabel;
  final String? shopName;
  final String? institutionName;
  final String generatedAt;

  /// False when the platform keeps no record of this kind at all.
  final bool available;
  final List<String> notes;
  final List<ReportStat> summary;
  final List<ReportTable> tables;

  int get rowCount => tables.fold(0, (sum, table) => sum + table.rows.length);

  bool get isEmpty => rowCount == 0;

  /// Row key the server sets to tint a row, e.g. `negative` for an
  /// overdrawn wallet. It is not a column, so the CSV never shows it.
  static const toneKey = '_tone';

  /// `credits_2026-09-01_to_2026-09-29` — safe on every file system.
  String get fileStem {
    final period = from.isEmpty
        ? ''
        : from == to || to.isEmpty
        ? '_$from'
        : '_${from}_to_$to';
    final shop = shopName == null || shopName!.isEmpty
        ? ''
        : '_${shopName!.toLowerCase()}';
    return '$kind$shop$period'
        .replaceAll(RegExp(r'[^A-Za-z0-9_\-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
  }

  factory FinanceReport.fromJson(Map<String, dynamic> json) {
    final shop = json['shop'];
    return FinanceReport(
      kind: _text(json['kind']),
      title: _text(json['title'], fallback: 'Report'),
      description: _text(json['description']),
      from: _text(json['from']),
      to: _text(json['to']),
      periodLabel: _text(json['periodLabel']),
      shopName: shop is Map ? _text(shop['name']) : null,
      institutionName: json['institutionName'] == null
          ? null
          : _text(json['institutionName']),
      generatedAt: _text(json['generatedAt']),
      available: json['available'] != false,
      notes: [
        for (final note in (json['notes'] as List? ?? const []))
          if (_text(note).isNotEmpty) _text(note),
      ],
      summary: [
        for (final stat in _maps(json['summary']))
          ReportStat(
            label: _text(stat['label']),
            value: _number(stat['value']) ?? 0,
            format: _text(stat['format'], fallback: 'number'),
          ),
      ],
      tables: [
        for (final table in _maps(json['tables']))
          ReportTable(
            title: _text(table['title']),
            columns: [
              for (final column in _maps(table['columns']))
                ReportColumn(
                  key: _text(column['key']),
                  label: _text(column['label'], fallback: _text(column['key'])),
                  format: _text(column['format'], fallback: 'text'),
                ),
            ],
            rows: [
              for (final row in (table['rows'] as List? ?? const []))
                if (row is Map) Map<String, dynamic>.from(row),
            ],
            totals: table['totals'] is Map
                ? Map<String, dynamic>.from(table['totals'] as Map)
                : null,
          ),
      ],
    );
  }
}

/// Most addresses one report email may go to (the backend's limit).
const maxReportRecipients = 10;

final _emailPattern = RegExp(
  r'^[A-Za-z0-9!#$%&*+/=?^_`{|}~-]+(\.[A-Za-z0-9!#$%&*+/=?^_`{|}~-]+)*'
  r'@([A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?\.)+[A-Za-z]{2,}$',
);

/// A plain address such as `accounts@college.edu.in`.
bool isValidReportEmail(String value) {
  final address = value.trim();
  return address.length <= 254 && _emailPattern.hasMatch(address);
}

/// Splits typed text on commas, semicolons, spaces and new lines.
List<String> splitReportEmails(String text) => [
  for (final part in text.split(RegExp(r'[\s,;]+')))
    if (part.trim().isNotEmpty) part.trim(),
];

/// A file sent with a report email, as the app rendered it.
class ReportAttachment {
  const ReportAttachment({
    required this.fileName,
    required this.contentType,
    required this.bytes,
  });

  final String fileName;
  final String contentType;
  final List<int> bytes;
}

/// What the server did with a report email.
class ReportEmailResult {
  const ReportEmailResult({
    this.sent = const [],
    this.failed = const [],
    this.delivered = true,
  });

  final List<String> sent;
  final List<String> failed;

  /// False on a development server that writes mail to its log instead.
  final bool delivered;

  factory ReportEmailResult.fromJson(Map<String, dynamic> json) =>
      ReportEmailResult(
        sent: [
          for (final a in (json['sent'] as List? ?? const [])) a.toString(),
        ],
        failed: [
          for (final a in (json['failed'] as List? ?? const [])) a.toString(),
        ],
        delivered: json['delivered'] != false,
      );
}

Iterable<Map<String, dynamic>> _maps(Object? value) => value is List
    ? value.whereType<Map>().map(Map<String, dynamic>.from)
    : const [];

String _text(Object? value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

double? _number(Object? value) => switch (value) {
  num() => value.toDouble(),
  String() => double.tryParse(value),
  _ => null,
};
