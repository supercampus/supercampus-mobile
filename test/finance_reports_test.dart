import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:supercampus_mobile/src/core/access/effective_permissions.dart';
import 'package:supercampus_mobile/src/core/theme/app_theme.dart';
import 'package:supercampus_mobile/src/features/admin_portal/presentation/admin_dashboard_screen.dart';
import 'package:supercampus_mobile/src/features/authentication/data/auth_repository.dart';
import 'package:supercampus_mobile/src/features/reports/data/finance_report.dart';
import 'package:supercampus_mobile/src/features/reports/data/finance_report_repository.dart';
import 'package:supercampus_mobile/src/features/reports/presentation/finance_reports_screen.dart';
import 'package:supercampus_mobile/src/features/reports/services/finance_report_exporter.dart';

/// A credits report exactly as `GET /api/v1/operations/reports/credits`
/// returns it.
Map<String, dynamic> creditsJson() => {
  'kind': 'credits',
  'title': 'Credits',
  'description': 'Wallet top-ups and credit transactions',
  'from': '2026-09-01',
  'to': '2026-09-29',
  'periodLabel': '1 Sep 2026 to 29 Sep 2026',
  'shop': null,
  'institutionName': 'Madras Engineering College',
  'generatedAt': '2026-09-29T13:39:31',
  'available': true,
  'notes': <String>[],
  'summary': [
    {'label': 'Credits', 'value': 2, 'format': 'number'},
    {'label': 'Total credited', 'value': 600.5, 'format': 'money'},
  ],
  'tables': [
    {
      'title': 'Credit transactions',
      'columns': [
        {'key': 'date', 'label': 'Date & time', 'format': 'datetime'},
        {'key': 'name', 'label': 'Name', 'format': 'text'},
        {'key': 'roll', 'label': 'Roll no.', 'format': 'text'},
        {'key': 'type', 'label': 'Type', 'format': 'text'},
        {'key': 'amount', 'label': 'Amount', 'format': 'money'},
      ],
      'rows': [
        {
          'date': '2026-09-28T00:43:01',
          'name': 'Nandhini Subramanian',
          'roll': 'MEC26AI007',
          'type': 'Manual top-up',
          'amount': 500,
        },
        {
          'date': '2026-09-28T05:04:45',
          'name': 'Kumar, "Priya"',
          'roll': 'MEC26AI001',
          'type': 'Online top-up',
          'amount': 100.5,
        },
      ],
      'totals': {'date': 'Total', 'amount': 600.5},
    },
  ],
};

FinanceReport unavailableReport() => FinanceReport.fromJson({
  'kind': 'complimentary',
  'title': 'Complimentary Consumption',
  'from': '2026-09-29',
  'to': '2026-09-29',
  'periodLabel': '29 Sep 2026',
  'generatedAt': '2026-09-29T13:39:31',
  'available': false,
  'notes': ['Complimentary servings are not recorded on this platform.'],
  'summary': <Object>[],
  'tables': [
    {
      'title': 'Complimentary servings',
      'columns': [
        {'key': 'item', 'label': 'Item', 'format': 'text'},
      ],
      'rows': <Object>[],
      'totals': null,
    },
  ],
});

class FakeReportRepository implements FinanceReportRepository {
  final requests = <ReportRequest>[];
  int optionCalls = 0;

  @override
  Future<ReportOptions> options() async {
    optionCalls++;
    return ReportOptions(
      today: DateTime(2026, 9, 29),
      shops: const [
        ReportShop(
          shopKey: 'mec-canteen',
          name: 'Canteen',
          category: 'canteen',
        ),
        ReportShop(
          shopKey: 'stationery',
          name: 'Stationery Store',
          category: 'stationery',
        ),
      ],
      menuItems: const [
        ReportMenuItem(
          id: '48d079a3-e4e9-4d68-84c3-58af0a2086f5',
          name: 'Bath brush',
          shopKey: 'stationery',
          shopName: 'Stationery Store',
          price: 65,
        ),
        ReportMenuItem(
          id: 'aede0481-7046-4c5a-b398-0a739a7e9ff4',
          name: 'Masala dosa',
          shopKey: 'mec-canteen',
          shopName: 'Canteen',
          price: 40,
        ),
      ],
    );
  }

  @override
  Future<FinanceReport> generate(ReportRequest request) async {
    requests.add(request);
    return FinanceReport.fromJson({...creditsJson(), 'kind': request.kind});
  }
}

class SavedFile {
  SavedFile(this.fileName, this.bytes, this.extension);
  final String fileName;
  final Uint8List bytes;
  final String extension;
}

Future<void> pumpReports(
  WidgetTester tester,
  FakeReportRepository repository,
  List<SavedFile> saved,
) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: FinanceReportsScreen(
        repository: repository,
        loadFonts: () async => null,
        saveFile:
            ({
              required String fileName,
              required Uint8List bytes,
              required String extension,
            }) async {
              saved.add(SavedFile(fileName, bytes, extension));
              return true;
            },
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('report data', () {
    test('parses the server report and names the file safely', () {
      final report = FinanceReport.fromJson(creditsJson());
      expect(report.title, 'Credits');
      expect(report.rowCount, 2);
      expect(report.tables.single.columns.last.format, 'money');
      expect(report.summary.last.value, 600.5);
      expect(report.fileStem, 'credits_2026-09-01_to_2026-09-29');
    });

    test('requests carry the period, shop and items the backend expects', () {
      final ranged = ReportRequest(
        kind: 'parameter_sales',
        from: DateTime(2026, 9, 1),
        to: DateTime(2026, 9, 29),
        shopKey: 'stationery',
        itemIds: const ['a', 'b'],
      );
      expect(ranged.toQuery(), {
        'from': '2026-09-01',
        'to': '2026-09-29',
        'shop': 'stationery',
        'items': 'a,b',
      });
      final monthly = ReportRequest(
        kind: 'vendor_payable',
        month: DateTime(2026, 9),
      );
      expect(monthly.toQuery(), {'month': '2026-09'});
    });

    test('only the report grants show the entry', () {
      expect(
        canGenerateFinanceReports(EffectivePermissions(grants: {'*'})),
        isTrue,
      );
      expect(
        canGenerateFinanceReports(
          EffectivePermissions(
            grants: {
              'canteen.analytics.read',
              'canteen.wallet.read',
              'canteen.wallet.top_up',
            },
          ),
        ),
        isTrue,
      );
      // A captain sees sales but not every wallet; a student sees their own.
      expect(
        canGenerateFinanceReports(
          EffectivePermissions(grants: {'canteen.analytics.read'}),
        ),
        isFalse,
      );
      expect(
        canGenerateFinanceReports(
          EffectivePermissions(grants: {'canteen.wallet.read'}),
        ),
        isFalse,
      );
    });
  });

  group('CSV', () {
    test('is RFC 4180 with the heading, rows, totals and plain numbers', () {
      final csv = FinanceReportExporter.csv(
        FinanceReport.fromJson(creditsJson()),
      );
      expect(
        csv,
        'Report,Credits\r\n'
        'Institution,Madras Engineering College\r\n'
        'Period,1 Sep 2026 to 29 Sep 2026\r\n'
        'From,2026-09-01\r\n'
        'To,2026-09-29\r\n'
        'Shop,All shops\r\n'
        'Generated,2026-09-29 13:39:31\r\n'
        '\r\n'
        'Summary,Value\r\n'
        'Credits,2\r\n'
        'Total credited,600.50\r\n'
        '\r\n'
        'Credit transactions\r\n'
        'Date & time,Name,Roll no.,Type,Amount\r\n'
        '2026-09-28 00:43:01,Nandhini Subramanian,MEC26AI007,Manual top-up,500.00\r\n'
        '2026-09-28 05:04:45,"Kumar, ""Priya""",MEC26AI001,Online top-up,100.50\r\n'
        'Total,,,,600.50\r\n',
      );
    });

    test('bytes start with a UTF-8 BOM and decode to the same text', () {
      final report = FinanceReport.fromJson(creditsJson());
      final bytes = FinanceReportExporter.csvBytes(report);
      expect(bytes.take(3), [0xEF, 0xBB, 0xBF]);
      expect(utf8.decode(bytes.sublist(3)), FinanceReportExporter.csv(report));
    });

    test('formula-like text is neutralised but negative numbers are kept', () {
      final json = creditsJson();
      final rows = (json['tables'] as List).first['rows'] as List;
      (rows.first as Map)['name'] = '=HYPERLINK("x")';
      (rows.first as Map)['amount'] = -12;
      final csv = FinanceReportExporter.csv(FinanceReport.fromJson(json));
      expect(csv, contains('"\'=HYPERLINK(""x"")"'));
      expect(csv, contains(',-12.00\r\n'));
    });

    test('an unrecorded kind is an empty table with its note', () {
      final csv = FinanceReportExporter.csv(unavailableReport());
      expect(csv, contains('Complimentary servings\r\nItem\r\n'));
      expect(
        csv,
        contains(
          'Note,Complimentary servings are not recorded on this platform.',
        ),
      );
    });
  });

  group('PDF', () {
    test('builds with the rupee-capable font', () async {
      final regular = pw.Font.ttf(
        ByteData.sublistView(
          File('assets/fonts/Poppins-Regular.ttf').readAsBytesSync(),
        ),
      );
      final medium = pw.Font.ttf(
        ByteData.sublistView(
          File('assets/fonts/Poppins-Medium.ttf').readAsBytesSync(),
        ),
      );
      final bytes = await FinanceReportExporter.pdf(
        FinanceReport.fromJson(creditsJson()),
        regular: regular,
        medium: medium,
      );
      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });

    test('builds without fonts, and for an empty report', () async {
      final bytes = await FinanceReportExporter.pdf(unavailableReport());
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      expect(
        FinanceReportExporter.display(1234.5, 'money', rupee: false),
        'Rs. 1,234.50',
      );
    });

    test('refuses a report too long to print', () async {
      final json = creditsJson();
      final table = (json['tables'] as List).first as Map<String, dynamic>;
      final row = (table['rows'] as List).first;
      table['rows'] = List.filled(FinanceReportExporter.maxPdfRows + 1, row);
      expect(
        () => FinanceReportExporter.pdf(FinanceReport.fromJson(json)),
        throwsA(isA<ReportTooLargeForPdf>()),
      );
    });
  });

  group('Reports page', () {
    testWidgets('lists every report kind with its formats', (tester) async {
      await pumpReports(tester, FakeReportRepository(), []);
      expect(
        find.text('Choose what type of report to generate'),
        findsOneWidget,
      );
      for (final kind in ReportKindSpec.all) {
        expect(find.byKey(Key('report-kind-${kind.key}')), findsOneWidget);
        expect(find.text(kind.title), findsOneWidget);
      }
      expect(find.text('PDF'), findsNWidgets(ReportKindSpec.all.length));
      expect(find.text('CSV'), findsNWidgets(ReportKindSpec.all.length));
      // The three the platform has no record of say so up front.
      expect(find.text('Not recorded'), findsNWidgets(3));
    });

    testWidgets('credits: preset period, generate, download CSV and PDF', (
      tester,
    ) async {
      final repository = FakeReportRepository();
      final saved = <SavedFile>[];
      await pumpReports(tester, repository, saved);

      await tester.tap(find.byKey(const Key('report-kind-credits')));
      await tester.pumpAndSettle();
      expect(
        find.text('Wallet top-ups and credit transactions'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('report-preset-last7')));
      await tester.pumpAndSettle();
      expect(find.text('23 Sep 2026 – 29 Sep 2026'), findsOneWidget);

      await tester.tap(find.byKey(const Key('report-generate')));
      await tester.pumpAndSettle();
      final request = repository.requests.single;
      expect(request.kind, 'credits');
      expect(request.toQuery(), {'from': '2026-09-23', 'to': '2026-09-29'});
      expect(find.byKey(const Key('report-result')), findsOneWidget);
      expect(find.text('2 rows'), findsOneWidget);
      expect(find.text('₹600.50'), findsOneWidget);

      await tester.tap(find.byKey(const Key('report-download-csv')));
      await tester.pumpAndSettle();
      expect(saved.single.extension, 'csv');
      expect(saved.single.fileName, 'credits_2026-09-01_to_2026-09-29.csv');
      final csv = utf8.decode(saved.single.bytes.sublist(3));
      expect(
        csv,
        contains('Nandhini Subramanian,MEC26AI007,Manual top-up,500.00'),
      );
      expect(
        find.text('Saved credits_2026-09-01_to_2026-09-29.csv'),
        findsOneWidget,
      );

      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('report-download-pdf')));
        await tester.pump();
        for (var i = 0; i < 50 && saved.length < 2; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
      });
      await tester.pumpAndSettle();
      expect(saved.last.extension, 'pdf');
      expect(saved.last.bytes, isNotEmpty);
      expect(String.fromCharCodes(saved.last.bytes.take(5)), '%PDF-');
    });

    testWidgets('shop-wise: a month and a shop are required', (tester) async {
      final repository = FakeReportRepository();
      await pumpReports(tester, repository, []);
      await tester.tap(find.byKey(const Key('report-kind-shop_transactions')));
      await tester.pumpAndSettle();

      expect(find.text('September 2026'), findsOneWidget);
      final generate = find.byKey(const Key('report-generate'));
      expect(tester.widget<FilledButton>(generate).onPressed, isNull);

      await tester.tap(find.byKey(const Key('report-month-previous')));
      await tester.pumpAndSettle();
      expect(find.text('August 2026'), findsOneWidget);

      await tester.tap(find.byKey(const Key('report-shop')));
      await tester.pumpAndSettle();
      // Required, so there is no "All shops" choice.
      expect(find.byKey(const Key('report-shop-option-all')), findsNothing);
      await tester.tap(find.byKey(const Key('report-shop-option-stationery')));
      await tester.pumpAndSettle();
      expect(find.text('Stationery Store'), findsOneWidget);

      await tester.tap(generate);
      await tester.pumpAndSettle();
      expect(repository.requests.single.toQuery(), {
        'month': '2026-08',
        'shop': 'stationery',
      });
    });

    testWidgets('parameter sales sends the chosen menu items', (tester) async {
      final repository = FakeReportRepository();
      await pumpReports(tester, repository, []);
      await tester.tap(find.byKey(const Key('report-kind-parameter_sales')));
      await tester.pumpAndSettle();
      expect(find.text('All items'), findsOneWidget);

      await tester.tap(find.byKey(const Key('report-items')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          const Key('report-item-48d079a3-e4e9-4d68-84c3-58af0a2086f5'),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('report-items-done')));
      await tester.pumpAndSettle();
      expect(find.text('1 item'), findsOneWidget);

      await tester.tap(find.byKey(const Key('report-generate')));
      await tester.pumpAndSettle();
      expect(repository.requests.single.itemIds, [
        '48d079a3-e4e9-4d68-84c3-58af0a2086f5',
      ]);
      // Options are fetched once, however many pickers use them.
      expect(repository.optionCalls, 1);
    });

    testWidgets('EOD wallet presets stay within its 31-day limit', (
      tester,
    ) async {
      await pumpReports(tester, FakeReportRepository(), []);
      await tester.tap(find.byKey(const Key('report-kind-student_eod_wallet')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('report-preset-thisMonth')));
      await tester.pumpAndSettle();
      final generate = find.byKey(const Key('report-generate'));
      expect(tester.widget<FilledButton>(generate).onPressed, isNotNull);
      // Last month (31 days in August) is still allowed.
      await tester.tap(find.byKey(const Key('report-preset-lastMonth')));
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(generate).onPressed, isNotNull);
    });
  });

  group('home entry', () {
    const accountant = UserSession(
      email: 'abhinaya@mec.local',
      displayName: 'Abhinaya',
      role: UserRole.admin,
      roleId: 'accountant',
      roleIds: ['accountant'],
      portalFamilies: [PortalFamily.admin],
      activePortalFamily: PortalFamily.admin,
    );
    const admin = UserSession(
      email: 'admin@mec.local',
      displayName: 'MEC Admin',
      role: UserRole.admin,
      roleId: 'tenant_admin',
      roleIds: ['tenant_admin'],
    );

    Future<int> pumpHome(
      WidgetTester tester,
      UserSession session,
      Set<String> grants,
    ) async {
      var opened = 0;
      tester.view.physicalSize = const Size(1400, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: AdminDashboardScreen(
            session: session,
            permissions: EffectivePermissions(grants: grants),
            onOpenModule: (_, [_]) {},
            onSignOut: () {},
            onProfileTap: () {},
            onAlertsTap: () {},
            onOpenReports: () => opened++,
          ),
        ),
      );
      await tester.pump();
      if (find.text('Reports').evaluate().isNotEmpty) {
        await tester.tap(find.text('Reports').first);
        await tester.pump();
      }
      return opened;
    }

    testWidgets('the accountant and the admin get a Reports entry', (
      tester,
    ) async {
      expect(
        await pumpHome(tester, accountant, {
          'canteen.analytics.read',
          'canteen.wallet.read',
          'canteen.wallet.top_up',
          'tuition_fee.invoice.read',
        }),
        1,
      );
      expect(find.text('Reports'), findsWidgets);

      expect(await pumpHome(tester, admin, {'*'}), 1);
      expect(
        find.text('Sales, wallet and vendor reports as PDF or CSV'),
        findsOneWidget,
      );
    });

    testWidgets('grants without the ledger get no entry', (tester) async {
      expect(
        await pumpHome(tester, accountant, {
          'canteen.analytics.read',
          'tuition_fee.invoice.read',
        }),
        0,
      );
      expect(find.text('Reports'), findsNothing);
    });
  });
}
