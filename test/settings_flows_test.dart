import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/core/access/effective_permissions.dart';
import 'package:supercampus_mobile/src/core/theme/app_theme.dart';
import 'package:supercampus_mobile/src/features/authentication/data/auth_repository.dart';
import 'package:supercampus_mobile/src/features/canteen/data/canteen_repository.dart';
import 'package:supercampus_mobile/src/features/canteen/data/wallet_pin_repository.dart';
import 'package:supercampus_mobile/src/features/canteen/presentation/transaction_pin_sheet.dart';
import 'package:supercampus_mobile/src/features/modules/presentation/widgets/home_sheets.dart';
import 'package:supercampus_mobile/src/features/settings/data/account_repository.dart';
import 'package:supercampus_mobile/src/features/settings/data/settings_api.dart';
import 'package:supercampus_mobile/src/features/settings/data/support_repository.dart';
import 'package:supercampus_mobile/src/features/settings/presentation/change_password_page.dart';
import 'package:supercampus_mobile/src/features/settings/presentation/help_center_page.dart';
import 'package:supercampus_mobile/src/features/settings/presentation/profile_details_page.dart';

// ── Fakes ───────────────────────────────────────────────────────────────────

class FakeWalletPinRepository implements WalletPinRepository {
  FakeWalletPinRepository({
    required this.status,
    this.changeError,
    this.setError,
  });

  WalletPinStatus status;
  Exception? changeError;
  Exception? setError;
  final changeCalls = <Map<String, Object?>>[];
  final setCalls = <Map<String, Object?>>[];

  @override
  Future<WalletPinStatus> loadPinStatus() async => status;

  @override
  Future<void> setWalletPin(String pinHash, {String? hint}) async {
    setCalls.add({'pinHash': pinHash, 'hint': hint});
    if (setError case final error?) throw error;
  }

  @override
  Future<bool> changeWalletPin({
    required String newPinHash,
    required WalletPinVerification method,
    String? currentPinHash,
    String? hint,
    String? password,
    String? newHint,
  }) async {
    changeCalls.add({
      'newPinHash': newPinHash,
      'method': method,
      'currentPinHash': currentPinHash,
      'hint': hint,
      'password': password,
      'newHint': newHint,
    });
    if (changeError case final error?) throw error;
    return status.hasPinHint;
  }
}

class FakeAccountRepository implements AccountRepository {
  FakeAccountRepository({this.changeError, this.extras = ProfileExtras.empty});

  Exception? changeError;
  ProfileExtras extras;
  final changeCalls = <(String, String)>[];
  final resetEmails = <String>[];

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    changeCalls.add((currentPassword, newPassword));
    if (changeError case final error?) throw error;
  }

  @override
  Future<void> sendPasswordReset(String email) async => resetEmails.add(email);

  @override
  Future<ProfileExtras> loadProfileExtras() async => extras;
}

class FakeSupportRepository implements SupportRepository {
  FakeSupportRepository({this.failCategories = false});

  final bool failCategories;
  final tickets = <SupportTicket>[];
  final created = <Map<String, Object?>>[];

  @override
  Future<List<SupportCategory>> categories() async {
    if (failCategories) throw const SettingsApiException('offline');
    return const [
      SupportCategory(
        key: 'fees',
        label: 'Fees & payments',
        handledBy: 'Accounts office',
      ),
      SupportCategory(key: 'library', label: 'Library', handledBy: 'Librarian'),
    ];
  }

  @override
  Future<SupportTicket> createTicket({
    required String category,
    required String subject,
    required String message,
    Map<String, dynamic>? context,
  }) async {
    created.add({'category': category, 'subject': subject, 'message': message});
    final ticket = SupportTicket(
      id: 't${tickets.length + 1}',
      category: category,
      categoryLabel: 'Fees & payments',
      subject: subject,
      message: message,
      status: SupportTicketStatus.open,
      handledBy: 'Accounts office',
      createdAt: DateTime(2026, 9, 27, 10),
    );
    tickets.insert(0, ticket);
    return ticket;
  }

  @override
  Future<List<SupportTicket>> myTickets() async => List.of(tickets);

  @override
  Future<List<SupportTicket>> inbox({SupportTicketStatus? status}) async =>
      const [];

  @override
  Future<SupportTicket> updateTicket(
    String id, {
    required SupportTicketStatus status,
    String? note,
  }) => throw UnimplementedError();
}

// ── Helpers ─────────────────────────────────────────────────────────────────

const student = UserSession(
  email: 'abinaya@mec.local',
  displayName: 'Abinaya S',
  role: UserRole.student,
  idNumber: 'MEC25AD01',
  departmentOrWard: 'AIDS',
);

void useTallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget app(Widget child) =>
    MaterialApp(theme: AppTheme.light, darkTheme: AppTheme.dark, home: child);

Future<void> openPinSheet(
  WidgetTester tester,
  WalletPinRepository repository,
) async {
  await tester.pumpWidget(
    app(
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () =>
                  showWalletPinSheet(context, repository: repository),
              child: const Text('Open PIN'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open PIN'));
  await tester.pumpAndSettle();
}

Future<void> enterPin(WidgetTester tester, String pin) async {
  for (final digit in pin.split('')) {
    await tester.tap(
      find.descendant(
        of: find.byType(WalletPinSheet),
        matching: find.widgetWithText(TextButton, digit),
      ),
    );
    await tester.pump();
  }
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pumpAndSettle();
}

const inventedProfileData = [
  'Robert Johnson',
  '+91 98765 43210',
  'O positive',
  'robert.johnson@example.com',
  'Bonafide Certificate',
  'Bonafide certificate',
  'Semester 5 Marksheet',
  'Campus coverage active',
  'SC2600142',
  'Computer Science',
  'B.Tech Computer Science',
  '8.42',
  'Library pass created',
];

// ── Tests ───────────────────────────────────────────────────────────────────

void main() {
  group('Transaction PIN', () {
    testWidgets('a refused change shows the server message inline and the '
        'sheet stays open on the verify step', (tester) async {
      useTallScreen(tester);
      final repository = FakeWalletPinRepository(
        status: const WalletPinStatus(hasPin: true, hasPinHint: true),
        changeError: const CanteenException('That PIN is incorrect.'),
      );
      await openPinSheet(tester, repository);

      expect(find.text('Change transaction PIN'), findsOneWidget);
      await tester.tap(find.text('Enter current PIN'));
      await tester.pumpAndSettle();
      await enterPin(tester, '1111');
      expect(find.text('Enter new PIN'), findsOneWidget);
      await enterPin(tester, '2468');
      expect(find.text('Confirm new PIN'), findsOneWidget);
      await enterPin(tester, '2468');

      await tester.tap(find.widgetWithText(FilledButton, 'Change PIN'));
      await tester.pumpAndSettle();

      expect(repository.changeCalls, hasLength(1));
      expect(
        repository.changeCalls.single['method'],
        WalletPinVerification.currentPin,
      );
      expect(repository.changeCalls.single['currentPinHash'], pinSha256('1111'));
      expect(repository.changeCalls.single['newPinHash'], pinSha256('2468'));
      expect(find.byType(WalletPinSheet), findsOneWidget);
      expect(find.text('That PIN is incorrect.'), findsOneWidget);
      expect(find.text('Enter current PIN'), findsOneWidget);
      expect(find.text('Transaction PIN updated'), findsNothing);

      // Retry: re-verify only; the confirmed new PIN is kept.
      repository.changeError = null;
      await enterPin(tester, '1234');
      await tester.tap(find.widgetWithText(FilledButton, 'Change PIN'));
      await tester.pumpAndSettle();
      expect(repository.changeCalls.last['currentPinHash'], pinSha256('1234'));
      expect(find.text('Your transaction PIN has been changed.'), findsOneWidget);
    });

    testWidgets('a mismatched confirmation restarts both new-PIN steps', (
      tester,
    ) async {
      useTallScreen(tester);
      final repository = FakeWalletPinRepository(
        status: const WalletPinStatus(hasPin: true, hasPinHint: false),
      );
      await openPinSheet(tester, repository);
      await tester.tap(find.text('Enter current PIN'));
      await tester.pumpAndSettle();
      await enterPin(tester, '1111');
      await enterPin(tester, '2468');
      await enterPin(tester, '1357');
      expect(find.text('Enter new PIN'), findsOneWidget);
      expect(
        find.text("Those PINs didn't match. Enter your new PIN again."),
        findsOneWidget,
      );
      // Back returns towards method selection.
      await tester.tap(find.byKey(const ValueKey('wallet-pin-back')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('wallet-pin-back')));
      await tester.pumpAndSettle();
      expect(find.text('Change transaction PIN'), findsOneWidget);
    });

    testWidgets('recovery word is offered only when one is stored', (
      tester,
    ) async {
      useTallScreen(tester);
      await openPinSheet(
        tester,
        FakeWalletPinRepository(
          status: const WalletPinStatus(hasPin: true, hasPinHint: false),
        ),
      );
      expect(find.text('Use recovery word'), findsNothing);
      expect(find.text('Use account password'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await openPinSheet(
        tester,
        FakeWalletPinRepository(
          status: const WalletPinStatus(hasPin: true, hasPinHint: true),
        ),
      );
      expect(find.text('Use recovery word'), findsOneWidget);
    });

    testWidgets('with no PIN the sheet sets one, with a recovery word', (
      tester,
    ) async {
      useTallScreen(tester);
      final repository = FakeWalletPinRepository(
        status: const WalletPinStatus(hasPin: false, hasPinHint: false),
      );
      await openPinSheet(tester, repository);

      expect(find.text('Set up a transaction PIN'), findsOneWidget);
      expect(find.text('Change transaction PIN'), findsNothing);
      await tester.tap(find.widgetWithText(FilledButton, 'Set PIN'));
      await tester.pumpAndSettle();
      await enterPin(tester, '4321');
      await enterPin(tester, '4321');
      await tester.enterText(
        find.byKey(const ValueKey('wallet-pin-recovery-field')),
        'mango',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Set PIN'));
      await tester.pumpAndSettle();

      expect(repository.setCalls.single['pinHash'], pinSha256('4321'));
      expect(repository.setCalls.single['hint'], 'mango');
      expect(find.text('Your transaction PIN is set.'), findsOneWidget);
    });

    testWidgets('setting a PIN that already exists explains and offers change', (
      tester,
    ) async {
      useTallScreen(tester);
      final repository = FakeWalletPinRepository(
        status: const WalletPinStatus(hasPin: false, hasPinHint: false),
        setError: const WalletPinAlreadySetException(
          'A wallet PIN is already set. Use Change PIN in Settings.',
        ),
      );
      await openPinSheet(tester, repository);
      await tester.tap(find.widgetWithText(FilledButton, 'Set PIN'));
      await tester.pumpAndSettle();
      await enterPin(tester, '4321');
      await enterPin(tester, '4321');
      await tester.tap(find.widgetWithText(FilledButton, 'Set PIN'));
      await tester.pumpAndSettle();

      expect(
        find.text('A wallet PIN is already set. Use Change PIN in Settings.'),
        findsOneWidget,
      );
      repository.status = const WalletPinStatus(hasPin: true, hasPinHint: false);
      await tester.tap(find.text('Change PIN instead'));
      await tester.pumpAndSettle();
      expect(find.text('Change transaction PIN'), findsOneWidget);
    });
  });

  group('Change password', () {
    testWidgets('validates inline and shows the server error', (tester) async {
      useTallScreen(tester);
      final repository = FakeAccountRepository(
        changeError: const SettingsApiException(
          'Your current password is incorrect.',
        ),
      );
      await tester.pumpWidget(
        app(ChangePasswordPage(repository: repository, email: student.email)),
      );

      await tester.tap(find.byKey(const ValueKey('change-password-submit')));
      await tester.pumpAndSettle();
      expect(find.text('Enter your current password.'), findsOneWidget);
      expect(find.text('Use at least 8 characters.'), findsOneWidget);
      expect(repository.changeCalls, isEmpty);

      await tester.enterText(
        find.byKey(const ValueKey('current-password')),
        'campus2026',
      );
      await tester.enterText(
        find.byKey(const ValueKey('new-password')),
        'campus2026',
      );
      await tester.pump();
      expect(
        find.text('Choose a password different from your current one.'),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const ValueKey('new-password')),
        'Longer-Pass-99',
      );
      await tester.enterText(
        find.byKey(const ValueKey('confirm-password')),
        'Longer-Pass-98',
      );
      await tester.pump();
      expect(find.text('Passwords don’t match.'), findsOneWidget);
      expect(find.textContaining('Strength:'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('confirm-password')),
        'Longer-Pass-99',
      );
      await tester.tap(find.byKey(const ValueKey('change-password-submit')));
      await tester.pumpAndSettle();

      expect(repository.changeCalls.single, ('campus2026', 'Longer-Pass-99'));
      expect(find.text('Your current password is incorrect.'), findsOneWidget);
      expect(find.byType(ChangePasswordPage), findsOneWidget);
    });

    testWidgets('password fields disable suggestions and use autofill hints', (
      tester,
    ) async {
      await tester.pumpWidget(
        app(
          ChangePasswordPage(
            repository: FakeAccountRepository(),
            email: student.email,
          ),
        ),
      );
      final current = tester.widget<TextField>(
        find.byKey(const ValueKey('current-password')),
      );
      final next = tester.widget<TextField>(
        find.byKey(const ValueKey('new-password')),
      );
      expect(current.autofillHints, [AutofillHints.password]);
      expect(next.autofillHints, [AutofillHints.newPassword]);
      expect(current.obscureText, isTrue);
      expect(current.autocorrect, isFalse);
      expect(current.enableSuggestions, isFalse);
    });

    testWidgets('forgot password sends a reset link to the signed-in email', (
      tester,
    ) async {
      useTallScreen(tester);
      final repository = FakeAccountRepository();
      await tester.pumpWidget(
        app(ChangePasswordPage(repository: repository, email: student.email)),
      );
      await tester.tap(find.text('Forgot your current password?'));
      await tester.pumpAndSettle();
      expect(repository.resetEmails, [student.email]);
      expect(find.textContaining('reset link to ${student.email}'), findsOneWidget);
    });
  });

  group('Help & support', () {
    testWidgets('the form shows who a topic goes to, submits, and the request '
        'appears under My requests', (tester) async {
      useTallScreen(tester);
      final repository = FakeSupportRepository();
      await tester.pumpWidget(
        app(HelpCenterPage(repository: repository, session: student)),
      );
      await tester.pumpAndSettle();
      expect(find.text('You haven’t sent any requests yet.'), findsOneWidget);

      await tester.tap(find.text('Ask for help'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('help-submit')));
      await tester.pumpAndSettle();
      expect(find.text('Choose a topic.'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('help-topic-fees')));
      await tester.pump();
      expect(find.text('Goes to: Accounts office'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('help-subject')),
        'Receipt missing',
      );
      await tester.enterText(
        find.byKey(const ValueKey('help-message')),
        'My May payment has no receipt in Tuition Fee.',
      );
      await tester.tap(find.byKey(const ValueKey('help-submit')));
      await tester.pumpAndSettle();

      expect(repository.created.single, {
        'category': 'fees',
        'subject': 'Receipt missing',
        'message': 'My May payment has no receipt in Tuition Fee.',
      });
      expect(find.text('Request sent'), findsOneWidget);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(find.text('My requests'), findsOneWidget);
      expect(find.text('Receipt missing'), findsOneWidget);
      expect(find.text('Open'), findsOneWidget);
    });

    testWidgets('falls back to the routing table when topics fail to load', (
      tester,
    ) async {
      useTallScreen(tester);
      await tester.pumpWidget(
        app(
          HelpCenterPage(
            repository: FakeSupportRepository(failCategories: true),
            session: student,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ask for help'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('help-topic-hostel')));
      await tester.pump();
      expect(find.text('Goes to: Hostel warden'), findsOneWidget);
    });

    testWidgets('FAQ search filters answers and has no fake tickets', (
      tester,
    ) async {
      useTallScreen(tester);
      await tester.pumpWidget(
        app(HelpCenterPage(repository: FakeSupportRepository(), session: student)),
      );
      await tester.pumpAndSettle();
      expect(find.text('QR pass not appearing'), findsNothing);
      expect(find.text('Wallet top-up query'), findsNothing);

      await tester.enterText(find.byKey(const ValueKey('faq-search')), 'PIN');
      await tester.pumpAndSettle();
      expect(find.text('What is the transaction PIN?'), findsOneWidget);
      expect(find.text('How do I borrow a book?'), findsNothing);
    });

    test('only request-handling roles are offered the inbox', () {
      expect(receivesHelpRequests(student), isFalse);
      expect(
        receivesHelpRequests(
          const UserSession(
            email: 'accounts@mec.local',
            displayName: 'Accounts',
            role: UserRole.staff,
            roleId: 'accountant',
          ),
        ),
        isTrue,
      );
    });
  });

  group('Profile', () {
    testWidgets('profile details show real data and nothing invented', (
      tester,
    ) async {
      useTallScreen(tester);
      await tester.pumpWidget(
        app(
          ProfileDetailsPage(
            session: student,
            accountRepository: FakeAccountRepository(
              extras: const ProfileExtras(
                institution: 'Madras Engineering College',
                programme: 'B.Tech AI & DS',
                academicYear: '2',
                residency: 'hosteller',
                hostel: 'Kaveri',
                room: '204',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Abinaya S'), findsOneWidget);
      expect(find.text('abinaya@mec.local'), findsOneWidget);
      expect(find.text('MEC25AD01'), findsOneWidget);
      expect(find.text('B.Tech AI & DS'), findsOneWidget);
      expect(find.text('Kaveri'), findsOneWidget);
      expect(find.textContaining('Madras Engineering College'), findsOneWidget);
      expect(find.textContaining(institutionKeepsRecordsNote), findsOneWidget);
      for (final fake in inventedProfileData) {
        expect(find.textContaining(fake), findsNothing, reason: fake);
      }

      await tester.tap(find.text('Digital ID card'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('digital-id-photo')), findsOneWidget);
      for (final fake in inventedProfileData) {
        expect(find.textContaining(fake), findsNothing, reason: fake);
      }
    });

    testWidgets('a day scholar with no extras shows only what is known', (
      tester,
    ) async {
      useTallScreen(tester);
      const staff = UserSession(
        email: 'staff@mec.local',
        displayName: 'Priya R',
        role: UserRole.staff,
      );
      await tester.pumpWidget(app(const ProfileDetailsPage(session: staff)));
      await tester.pumpAndSettle();
      expect(find.text('Not assigned'), findsOneWidget);
      expect(find.text('Residency'), findsNothing);
      expect(find.text('Programme'), findsNothing);
      for (final fake in inventedProfileData) {
        expect(find.textContaining(fake), findsNothing, reason: fake);
      }
    });

    testWidgets('the profile sheet no longer carries sample records', (
      tester,
    ) async {
      useTallScreen(tester);
      await tester.pumpWidget(
        app(
          Scaffold(
            body: ProfileSheet(
              session: student,
              permissions: const EffectivePermissions.empty(),
              onOpenModule: (_) {},
              onSignOut: () {},
              onThemeModeChanged: (_) {},
            ),
          ),
        ),
      );
      for (final fake in inventedProfileData) {
        expect(find.textContaining(fake), findsNothing, reason: fake);
      }
      for (final title in [
        'Emergency Contacts',
        'Medical Information',
        'Parent Details',
        'Documents & Certificates',
      ]) {
        expect(find.text(title), findsNothing);
      }
      await tester.tap(find.text('Digital ID card'));
      await tester.pumpAndSettle();
      for (final fake in inventedProfileData) {
        expect(find.textContaining(fake), findsNothing, reason: fake);
      }
    });
  });
}
