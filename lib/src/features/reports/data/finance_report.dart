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
    this.shop = ReportShopMode.optional,
    this.pickItems = false,
    this.maxDays = 731,
    this.recorded = true,
  });

  final String key;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  /// Settles by calendar month instead of a free date range.
  final bool monthly;
  final ReportShopMode shop;

  /// Asks which menu items to include (Parameter Sales).
  final bool pickItems;

  /// Longest date range the backend accepts for this kind.
  final int maxDays;

  /// False where the platform keeps no record of this at all, so the report
  /// is always empty. The grid says so up front.
  final bool recorded;

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
      key: 'auto_debit',
      title: 'Auto Debit History',
      subtitle:
          'Meal compliance debited student list with item and amount details',
      icon: Icons.restaurant_rounded,
      color: AppColors.muted,
      shop: ReportShopMode.none,
      recorded: false,
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
      key: 'complimentary',
      title: 'Complimentary Consumption',
      subtitle:
          'Free items served to visitors, clients, guests, staff or others',
      icon: Icons.card_giftcard_rounded,
      color: AppColors.muted,
      shop: ReportShopMode.none,
      recorded: false,
    ),
    ReportKindSpec(
      key: 'student_eod_wallet',
      title: 'Student EOD Wallet',
      subtitle: 'Day-wise end-of-day wallet balance for every student',
      icon: Icons.account_balance_wallet_rounded,
      color: AppColors.brandPurple,
      maxDays: 31,
    ),
    ReportKindSpec(
      key: 'self_registered',
      title: 'Self-Registered Students',
      subtitle: 'Students who created accounts through the old mobile API',
      icon: Icons.phone_iphone_rounded,
      color: AppColors.muted,
      shop: ReportShopMode.none,
      recorded: false,
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
