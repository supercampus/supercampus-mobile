import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/core/access/effective_permissions.dart';
import 'package:supercampus_mobile/src/core/theme/app_theme.dart';
import 'package:supercampus_mobile/src/features/academics/data/student_assessments_repository.dart';
import 'package:supercampus_mobile/src/features/authentication/data/auth_repository.dart';
import 'package:supercampus_mobile/src/features/canteen/data/canteen_models.dart';
import 'package:supercampus_mobile/src/features/examination/data/student_report_data.dart';
import 'package:supercampus_mobile/src/features/examination/presentation/screens/student_reports_analytics_screen.dart';
import 'package:supercampus_mobile/src/features/library/data/library_lending_repository.dart';
import 'package:supercampus_mobile/src/screens/tuition_fee/tuition_fee_repository.dart';

const _session = UserSession(
  email: 'asha@college.test',
  displayName: 'Asha Menon',
  role: UserRole.student,
  idNumber: '22CS041',
  departmentOrWard: 'Computer Science',
);

final _now = DateTime(2026, 9, 20, 10, 30);

Map<String, dynamic> _summary({
  required int attended,
  required int total,
  List<Map<String, dynamic>> subjects = const [],
}) => {
  'totalClasses': total,
  'attendedClasses': attended,
  'presentClasses': attended - 2,
  'absences': total - attended,
  'onDutyClasses': 2,
  'leaveClasses': 0,
  'percentage': total == 0 ? 0 : attended / total * 100,
  'bySubject': subjects,
  'records': [
    for (var i = 0; i < 16; i++)
      {
        'heldOn': '2026-09-${(i + 1).toString().padLeft(2, '0')}',
        'periodLabel': 'P${i % 6 + 1}',
        'subjectName': 'Data Structures',
        'status': i % 5 == 0 ? 'absent' : (i % 7 == 0 ? 'od' : 'present'),
      },
  ],
};

Map<String, dynamic> _subject(
  String code,
  String name,
  int attended,
  int total,
) => {
  'subjectCode': code,
  'subjectName': name,
  'totalClasses': total,
  'attendedClasses': attended,
};

CanteenStore _canteenStore() => CanteenStore(
  user: const CanteenUser(
    name: 'Asha Menon',
    email: 'asha@college.test',
    rollNumber: '22CS041',
    department: 'CS',
  ),
  walletBalances: const {'classic': 120, 'bites': 80},
  shops: const [
    CanteenShop(
      id: '1',
      shopKey: 'classic',
      name: 'Main Canteen',
      category: 'food',
    ),
    CanteenShop(
      id: '2',
      shopKey: 'bites',
      name: 'Bites Corner',
      category: 'food',
    ),
  ],
  menu: const [],
  orders: [
    CanteenOrder(
      id: 'o1',
      lines: const [],
      total: 60,
      status: CanteenOrderStatus.completed,
      fulfilmentMode: FulfilmentMode.pickup,
      createdAt: DateTime(2026, 9, 3),
    ),
    CanteenOrder(
      id: 'o2',
      lines: const [],
      total: 40,
      status: CanteenOrderStatus.completed,
      fulfilmentMode: FulfilmentMode.pickup,
      createdAt: DateTime(2026, 8, 30),
    ),
  ],
  walletTransactions: [
    WalletTransaction(
      id: 't1',
      shopKey: 'classic',
      type: WalletTransactionType.debit,
      amount: 60,
      description: 'Order',
      createdAt: DateTime(2026, 9, 3),
    ),
    WalletTransaction(
      id: 't2',
      shopKey: 'classic',
      type: WalletTransactionType.credit,
      amount: 500,
      description: 'Top up',
      createdAt: DateTime(2026, 9, 2),
    ),
    WalletTransaction(
      id: 't3',
      shopKey: 'bites',
      type: WalletTransactionType.debit,
      amount: 40,
      description: 'Order',
      createdAt: DateTime(2026, 8, 30),
    ),
  ],
);

StudentReportSources _sources({
  int attended = 45,
  int total = 50,
  List<Map<String, dynamic>> subjects = const [],
  ReportLoader<List<StudentAssessment>>? marks,
  ReportLoader<LibraryReport>? library,
}) => StudentReportSources(
  attendance: () async => AttendanceReport.fromSummary(
    _summary(attended: attended, total: total, subjects: subjects),
  ),
  marks:
      marks ??
      () async => [
        StudentAssessment(
          id: 'a1',
          kind: StudentAssessmentKind.internal,
          title: 'Internal 1',
          subjectCode: 'CS301',
          marksObtained: 42,
          maximumMarks: 50,
          assessedOn: DateTime(2026, 8, 12),
        ),
        const StudentAssessment(
          id: 'a2',
          kind: StudentAssessmentKind.semester,
          title: 'Semester 4 — Operating Systems',
          subjectCode: 'CS302',
          semester: 4,
          marksObtained: 71,
          maximumMarks: 100,
        ),
      ],
  fees: () async => FeeReport.fromRecords(const [
    StudentFeeRecord(
      id: 'f1',
      type: 'fee_assignment',
      data: {'amountPerStudent': 50000},
    ),
    StudentFeeRecord(
      id: 'p1',
      type: 'payments',
      data: {'amount': 30000, 'paymentDate': '2026-07-14', 'status': 'success'},
    ),
  ]),
  library: library ?? () async => LibraryReport.fromLoans([
    LibraryLoan(
      id: 'l1',
      bookId: 'b1',
      bookTitle: 'Introduction to Algorithms',
      author: 'CLRS',
      studentName: 'Asha',
      rollNumber: '22CS041',
      status: 'approved',
      requestedAt: DateTime(2026, 9, 1),
      dueAt: DateTime(2026, 9, 15),
      renewalCount: 0,
      overdueDays: 5,
      fineAmount: 25,
    ),
  ]),
  canteen: () async => CanteenReport.fromStore(_canteenStore(), _now),
  gatepass: () async => const GatepassReport(
    recentPasses: 3,
    approved: 2,
    pending: 1,
    rejected: 0,
  ),
  hostel: () async => const HostelReport(
    hostelName: 'Nila Hostel',
    blockName: 'Block B',
    roomNumber: '204',
  ),
);

Future<void> _pump(
  WidgetTester tester, {
  required StudentReportSources sources,
  EffectivePermissions? permissions,
  ThemeData? theme,
  Size size = const Size(375, 812),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? AppTheme.light,
      home: Scaffold(
        body: StudentReportsAnalyticsScreen(
          session: _session,
          sources: sources,
          permissions: permissions,
          clock: () => _now,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) =>
    tester.scrollUntilVisible(
      finder,
      300,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('student-report-list')),
            matching: find.byType(Scrollable),
          )
          .first,
    );

void main() {
  group('attendance maths', () {
    test('matches a brute-force search for every small case', () {
      for (var total = 1; total <= 60; total++) {
        for (var attended = 0; attended <= total; attended++) {
          var miss = 0;
          while ((attended) / (total + miss + 1) >= 0.75) {
            miss++;
          }
          var need = 0;
          while ((attended + need) / (total + need) < 0.75) {
            need++;
          }
          final above = attended / total >= 0.75;
          expect(
            classesYouCanMiss(attended, total),
            above ? miss : 0,
            reason: '$attended/$total can miss',
          );
          expect(
            classesNeededToRecover(attended, total),
            need,
            reason: '$attended/$total needs',
          );
        }
      }
    });

    test('standing distinguishes safe, close and below', () {
      expect(attendanceStanding(45, 50), AttendanceStanding.safe);
      expect(attendanceStanding(38, 50), AttendanceStanding.close);
      expect(attendanceStanding(30, 50), AttendanceStanding.below);
      expect(attendanceStanding(0, 0), AttendanceStanding.none);
    });

    test(
      'fee outstanding is assigned + fine − waiver − paid, never negative',
      () {
        final report = FeeReport.fromRecords(const [
          StudentFeeRecord(
            id: 'a',
            type: 'student_fee_accounts',
            data: {
              'totalAssigned': 1000,
              'paid': 1500,
              'fine': 0,
              'discountWaiver': 0,
            },
          ),
        ]);
        expect(report.outstanding, 0);
        expect(report.isSettled, isTrue);
      },
    );
  });

  testWidgets('below 75% says how many classes to attend, with a text status', (
    tester,
  ) async {
    await _pump(tester, sources: _sources(attended: 30, total: 50));
    expect(find.text('Below 75%'), findsOneWidget);
    // (0.75·50 − 30) / 0.25 = 30
    expect(
      find.text('Attend the next 30 classes to reach 75%'),
      findsOneWidget,
    );
    expect(find.text('60%'), findsOneWidget);
  });

  testWidgets('above 75% says how many classes can be missed', (tester) async {
    await _pump(tester, sources: _sources(attended: 45, total: 50));
    expect(find.text('Safe'), findsOneWidget);
    // floor(45 / 0.75 − 50) = 10
    expect(find.text('You can miss 10 more classes'), findsOneWidget);
    expect(find.text('45 of 50 classes attended'), findsOneWidget);
  });

  testWidgets('just above 75% is flagged as close', (tester) async {
    await _pump(tester, sources: _sources(attended: 38, total: 50));
    expect(find.text('Close to 75%'), findsOneWidget);
    expect(find.text('You can miss 0 more classes'), findsNothing);
    expect(find.text("Don't miss your next class"), findsOneWidget);
  });

  testWidgets('subjects are listed riskiest first with what each needs', (
    tester,
  ) async {
    await _pump(
      tester,
      sources: _sources(
        subjects: [
          _subject('CS301', 'Algorithms', 18, 20),
          _subject('MA201', 'Discrete Maths', 12, 20),
          _subject('CS302', 'Operating Systems', 15, 20),
        ],
      ),
    );
    final maths = find.byKey(const ValueKey('subject-MA201-Discrete Maths'));
    final os = find.byKey(const ValueKey('subject-CS302-Operating Systems'));
    final algo = find.byKey(const ValueKey('subject-CS301-Algorithms'));
    await _scrollTo(tester, algo);
    expect(tester.getTopLeft(maths).dy, lessThan(tester.getTopLeft(os).dy));
    expect(tester.getTopLeft(os).dy, lessThan(tester.getTopLeft(algo).dy));
    // 12/20: (15 − 12) / 0.25 = 12 more classes
    expect(find.text('12/20 classes · needs 12 classes'), findsOneWidget);
    expect(find.text("15/20 classes · don't miss the next"), findsOneWidget);
  });

  testWidgets('canteen shows each shop wallet separately, never a sum', (
    tester,
  ) async {
    await _pump(tester, sources: _sources());
    await _scrollTo(tester, find.byKey(const Key('report-canteen')));
    expect(find.text('Main Canteen'), findsOneWidget);
    expect(find.text('Bites Corner'), findsOneWidget);
    expect(find.text('₹120.00'), findsOneWidget);
    expect(find.text('₹80.00'), findsOneWidget);
    expect(find.text('₹200.00'), findsNothing);
    // Only September's debit and order count toward this month.
    expect(find.text('This month: ₹60 spent · 1 order'), findsOneWidget);
  });

  testWidgets('a failing section shows its own error and retries alone', (
    tester,
  ) async {
    var calls = 0;
    await _pump(
      tester,
      sources: _sources(
        marks: () async {
          calls++;
          if (calls == 1) throw const StudentAssessmentsException('down');
          return const [];
        },
      ),
    );
    expect(find.text('You can miss 10 more classes'), findsOneWidget);
    await _scrollTo(tester, find.text("Couldn't load marks."));
    expect(find.text("Couldn't load marks."), findsOneWidget);
    await _scrollTo(tester, find.byKey(const Key('report-fees')));
    expect(find.byKey(const Key('fees-outstanding')), findsOneWidget);
    expect(find.text('₹20,000'), findsOneWidget);

    await tester.ensureVisible(find.text('Retry'));
    await tester.pump();
    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(calls, 2);
    expect(find.text("Couldn't load marks."), findsNothing);
    expect(find.text('No marks published yet.'), findsOneWidget);
  });

  testWidgets('a section the server refuses (403) is hidden, not an error', (
    tester,
  ) async {
    await _pump(
      tester,
      sources: _sources(
        // The API's 403 message, as LibraryLendingRepository surfaces it.
        library: () async => throw StateError(
          'This session cannot access the requested tenant or resource',
        ),
      ),
    );
    await _scrollTo(tester, find.byKey(const Key('report-export')));
    expect(find.byKey(const Key('report-library')), findsNothing);
    expect(find.text("Couldn't load library loans."), findsNothing);
    // Other sections are unaffected.
    expect(find.byKey(const Key('report-fees')), findsOneWidget);
  });

  testWidgets('a real failure still shows an error with Retry', (tester) async {
    await _pump(
      tester,
      sources: _sources(
        library: () async => throw StateError('Library request failed (500).'),
      ),
    );
    await _scrollTo(tester, find.text("Couldn't load library loans."));
    expect(find.text("Couldn't load library loans."), findsOneWidget);
  });

  testWidgets('sections for modules the user cannot see are not shown', (
    tester,
  ) async {
    await _pump(
      tester,
      sources: _sources(),
      permissions: const EffectivePermissions(
        grants: {'attendance.records.read', 'library.catalog.read'},
      ),
    );
    expect(find.byKey(const Key('report-attendance')), findsOneWidget);
    await _scrollTo(tester, find.byKey(const Key('report-export')));
    expect(find.byKey(const Key('report-library')), findsOneWidget);
    expect(find.byKey(const Key('report-marks')), findsNothing);
    expect(find.byKey(const Key('report-fees')), findsNothing);
    expect(find.byKey(const Key('report-services')), findsNothing);
    expect(find.byKey(const Key('report-canteen')), findsNothing);
  });

  testWidgets('a build without a backend says sections are not available', (
    tester,
  ) async {
    await _pump(tester, sources: const StudentReportSources.unavailable());
    expect(
      find.text('Attendance is not available in this build.'),
      findsOneWidget,
    );
    expect(find.text('Safe'), findsNothing);
  });

  for (final (label, size) in [
    ('phone', const Size(375, 812)),
    ('narrow phone', const Size(320, 640)),
    ('tablet', const Size(1024, 768)),
  ]) {
    testWidgets(
      'dark theme renders the full report on a $label without overflow',
      (tester) async {
        await _pump(
          tester,
          theme: AppTheme.dark,
          size: size,
          sources: _sources(
            attended: 30,
            subjects: [
              _subject(
                'CS301',
                'Design and Analysis of Algorithms Laboratory',
                18,
                20,
              ),
              _subject('MA201', 'Discrete Maths', 12, 20),
            ],
          ),
        );
        await _scrollTo(tester, find.byKey(const Key('report-export')));
        expect(tester.takeException(), isNull);
        expect(find.text('Nila Hostel · Block B · Room 204'), findsOneWidget);
        final card = tester.widget<Text>(find.text('Campus services'));
        expect(card.style?.color, AppPalette.dark.ink);
      },
    );
  }
}
