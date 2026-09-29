import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/core/access/effective_permissions.dart';
import 'package:supercampus_mobile/src/core/notifications/push_notification_service.dart';
import 'package:supercampus_mobile/src/features/notifications/data/notification_repository.dart';
import 'package:supercampus_mobile/src/features/push_broadcasts/data/push_broadcast_repository.dart';
import 'package:supercampus_mobile/src/features/push_broadcasts/presentation/push_broadcast_screen.dart';

/// Stats exactly as `GET .../notifications/broadcasts/audience-stats` returns
/// them on a server without FCM credentials.
Map<String, dynamic> statsJson({bool configured = false}) => {
  'totalUsers': 246,
  'pushEnabledUsers': 12,
  'noPushTokenUsers': 234,
  'totalTokens': 14,
  'tokensByPlatform': {'android': 11, 'ios': 3, 'web': 0},
  'roles': [
    {
      'key': 'captain',
      'name': 'Vendor Shop Captain',
      'users': 7,
      'pushEnabledUsers': 1,
    },
    {'key': 'student', 'name': 'Student', 'users': 200, 'pushEnabledUsers': 11},
    {
      'key': 'parent',
      'name': 'Parent / Guardian',
      'users': 0,
      'pushEnabledUsers': 0,
    },
  ],
  'push': {
    'configured': configured,
    'provider': 'fcm',
    'message': configured
        ? 'Push delivery through Firebase Cloud Messaging is on.'
        : 'Push delivery is not configured on this server (FCM_ENABLED is off).',
  },
  'canSend': true,
};

const _students = [
  BroadcastRecipient(
    id: 's1',
    name: 'Priya Kumar',
    email: 'priya@mec.local',
    roles: ['student'],
    department: 'AIDS',
    year: '1',
    roll: 'MEC26AI001',
    pushEnabled: true,
  ),
  BroadcastRecipient(
    id: 's2',
    name: 'Arjun Das',
    email: 'arjun@mec.local',
    roles: ['student'],
    department: 'CSE',
    year: '2',
    roll: 'MEC26CS014',
  ),
  BroadcastRecipient(
    id: 's3',
    name: 'Meena Iyer',
    email: 'meena@mec.local',
    roles: ['student'],
    department: 'CSE',
    year: '1',
    roll: 'MEC26CS020',
  ),
  BroadcastRecipient(
    id: 'f1',
    name: 'Dr. Ravi',
    email: 'ravi@mec.local',
    roles: ['staff'],
  ),
];

class FakePushBroadcastRepository implements PushBroadcastRepository {
  FakePushBroadcastRepository({this.configured = false});

  final bool configured;
  final sent = <BroadcastDraft>[];
  final previews = <Map<String, List<String>>>[];
  int historyLoads = 0;

  @override
  Future<BroadcastAudienceStats> audienceStats() async =>
      BroadcastAudienceStats.fromJson(statsJson(configured: configured));

  @override
  Future<BroadcastDirectory> recipients() async => const BroadcastDirectory(
    users: _students,
    departments: ['AIDS', 'CSE'],
    years: ['1', '2'],
  );

  @override
  Future<BroadcastReach> preview({
    required List<String> roles,
    required List<String> userIds,
  }) async {
    previews.add({'roles': roles, 'userIds': userIds});
    return BroadcastReach(
      recipients: (roles.contains('captain') ? 7 : 0) + userIds.length,
      pushRecipients: 1,
      devices: 2,
      devicesByPlatform: const DevicePlatformCounts(android: 2),
      pushConfigured: configured,
    );
  }

  @override
  Future<BroadcastSendResult> send(BroadcastDraft draft) async {
    sent.add(draft);
    return BroadcastSendResult(
      id: 'b-new',
      inAppDelivered: 8,
      pushStatus: configured ? 'queued' : 'not_configured',
      pushMessage: '',
      reach: const BroadcastReach(
        recipients: 8,
        pushRecipients: 1,
        devices: 2,
        devicesByPlatform: DevicePlatformCounts(android: 2),
      ),
    );
  }

  @override
  Future<List<BroadcastRecord>> history() async {
    historyLoads++;
    return [
      BroadcastRecord.fromJson({
        'id': 'b1',
        'title': 'Exam timetable published',
        'body': 'Check the examinations page.',
        'audienceSummary': 'Student',
        'createdAt': '2026-09-28T09:30:00Z',
        'sentBy': {'name': 'Arun Iyer', 'email': 'admin@mec.local'},
        'recipients': 200,
        'read': 41,
        'push': {
          'status': 'not_configured',
          'devices': 11,
          'sent': 0,
          'failed': 0,
          'pending': 0,
        },
      }),
    ];
  }
}

Future<void> pumpScreen(
  WidgetTester tester,
  FakePushBroadcastRepository repository, {
  BroadcastImagePicker? pickImage,
}) async {
  tester.view.physicalSize = const Size(900, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: PushBroadcastScreen(repository: repository, pickImage: pickImage),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('PushBroadcastScreen', () {
    testWidgets('shows reach, the push warning and the broadcast history', (
      tester,
    ) async {
      await pumpScreen(tester, FakePushBroadcastRepository());

      expect(find.text('Push Notifications'), findsOneWidget);
      expect(find.byKey(const Key('push-not-configured')), findsOneWidget);
      expect(find.text('246'), findsOneWidget);
      expect(find.text('Push enabled'), findsOneWidget);
      expect(find.text('Android 11 · iOS 3'), findsOneWidget);
      expect(find.text('Exam timetable published'), findsOneWidget);
      expect(find.textContaining('Arun Iyer ·'), findsOneWidget);
      expect(find.text('In app: 200 · Read: 41'), findsOneWidget);
      expect(
        find.text('Push not sent — not configured on the server'),
        findsOneWidget,
      );
    });

    testWidgets('refuses to send without an audience', (tester) async {
      final repository = FakePushBroadcastRepository();
      await pumpScreen(tester, repository);

      await tester.enterText(find.byKey(const Key('broadcast-title')), 'Hi');
      await tester.enterText(find.byKey(const Key('broadcast-body')), 'Body');
      await tester.tap(find.byKey(const Key('broadcast-send')));
      await tester.pump();

      expect(find.text('Choose at least one role or person.'), findsOneWidget);
      expect(repository.previews, isEmpty);
      expect(repository.sent, isEmpty);
    });

    testWidgets(
      'composes with an image, confirms the recipient count and sends',
      (tester) async {
        final repository = FakePushBroadcastRepository();
        await pumpScreen(
          tester,
          repository,
          pickImage: (_) async => 'https://cdn.test/rain.png',
        );

        await tester.enterText(
          find.byKey(const Key('broadcast-title')),
          'Campus closed tomorrow',
        );
        await tester.enterText(
          find.byKey(const Key('broadcast-body')),
          'Heavy rain: classes are suspended.',
        );
        await tester.tap(find.byKey(const Key('broadcast-image-add')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('broadcast-image-preview')),
          findsOneWidget,
        );
        // The shade preview reflects the draft.
        expect(find.text('SuperCampus · now'), findsOneWidget);
        expect(find.text('Campus closed tomorrow'), findsNWidgets(2));

        // Roles without members are not offered.
        expect(find.byKey(const Key('broadcast-role-parent')), findsNothing);
        await tester.tap(find.byKey(const Key('broadcast-role-captain')));
        await tester.pump();

        await tester.tap(find.byKey(const Key('broadcast-send')));
        await tester.pumpAndSettle();

        expect(find.text('Send to 7 people?'), findsOneWidget);
        expect(find.textContaining('No push will be sent'), findsOneWidget);
        expect(find.text('Includes an image'), findsOneWidget);

        await tester.tap(find.byKey(const Key('broadcast-confirm-send')));
        await tester.pumpAndSettle();

        expect(repository.sent, hasLength(1));
        final draft = repository.sent.single;
        expect(draft.title, 'Campus closed tomorrow');
        expect(draft.roles, ['captain']);
        expect(draft.userIds, isEmpty);
        expect(draft.toJson()['imageUrl'], 'https://cdn.test/rain.png');
        expect(
          find.textContaining('Push was not sent: it is not configured'),
          findsOneWidget,
        );
        // The form is cleared and the history reloaded.
        expect(repository.historyLoads, 2);
        expect(find.byKey(const Key('broadcast-image-preview')), findsNothing);
      },
    );

    testWidgets('cancelling the confirmation sends nothing', (tester) async {
      final repository = FakePushBroadcastRepository(configured: true);
      await pumpScreen(tester, repository);
      await tester.enterText(find.byKey(const Key('broadcast-title')), 'T');
      await tester.enterText(find.byKey(const Key('broadcast-body')), 'B');
      await tester.tap(find.byKey(const Key('broadcast-role-captain')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('broadcast-send')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Push to 2 devices'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(repository.sent, isEmpty);
    });

    testWidgets('hand-picked students join the audience', (tester) async {
      final repository = FakePushBroadcastRepository();
      await pumpScreen(tester, repository);

      await tester.tap(find.byKey(const Key('broadcast-choose-people')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('recipient-s2')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('recipient-picker-done')));
      await tester.pumpAndSettle();

      expect(find.text('1 selected'), findsOneWidget);
      expect(find.text('Arjun Das'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('broadcast-title')), 'T');
      await tester.enterText(find.byKey(const Key('broadcast-body')), 'B');
      await tester.tap(find.byKey(const Key('broadcast-send')));
      await tester.pumpAndSettle();
      expect(find.text('Send to 1 person?'), findsOneWidget);
      expect(repository.previews.single['userIds'], ['s2']);
    });
  });

  group('BroadcastRecipientPicker', () {
    Future<Set<String>?> openPicker(
      WidgetTester tester, {
      Set<String> initial = const {},
    }) async {
      Set<String>? result;
      tester.view.physicalSize = const Size(900, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await Navigator.of(context).push<Set<String>>(
                  MaterialPageRoute(
                    builder: (_) => BroadcastRecipientPicker(
                      directory: const BroadcastDirectory(users: _students),
                      initialSelection: initial,
                    ),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('filters students by department and year, then selects all', (
      tester,
    ) async {
      await openPicker(tester);

      // Students by default: the faculty member is hidden.
      expect(find.text('Dr. Ravi'), findsNothing);
      expect(find.text('3 shown · 0 selected'), findsOneWidget);

      await tester.tap(find.byKey(const Key('recipient-department')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CSE').last);
      await tester.pumpAndSettle();
      expect(find.text('2 shown · 0 selected'), findsOneWidget);

      await tester.tap(find.byKey(const Key('recipient-year')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Year 1').last);
      await tester.pumpAndSettle();
      expect(find.text('Meena Iyer'), findsOneWidget);
      expect(find.text('Arjun Das'), findsNothing);

      await tester.tap(find.byKey(const Key('recipient-select-all')));
      await tester.pump();
      expect(find.text('1 shown · 1 selected'), findsOneWidget);
      expect(find.text('Done (1)'), findsOneWidget);
    });

    testWidgets('searches everyone by name, email or roll number', (
      tester,
    ) async {
      await openPicker(tester, initial: {'s1'});

      await tester.tap(find.text('Everyone'));
      await tester.pumpAndSettle();
      expect(find.text('Dr. Ravi'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('recipient-search')),
        'cs020',
      );
      await tester.pump();
      expect(find.text('Meena Iyer'), findsOneWidget);
      expect(find.text('Priya Kumar'), findsNothing);
      expect(find.text('1 shown · 1 selected'), findsOneWidget);

      await tester.tap(find.byKey(const Key('recipient-s3')));
      await tester.pump();
      expect(find.text('Done (2)'), findsOneWidget);
    });
  });

  group('BroadcastAudienceBuilder', () {
    testWidgets('lists roles with members and reports toggles', (tester) async {
      final toggled = <String>[];
      final roles = BroadcastAudienceStats.fromJson(statsJson()).roles;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BroadcastAudienceBuilder(
              roles: roles,
              selectedRoles: const {'student'},
              selectedPeople: const [],
              onToggleRole: toggled.add,
              onChoosePeople: () {},
              onRemovePerson: (_) {},
              onClearPeople: () {},
            ),
          ),
        ),
      );

      expect(find.text('Student · 200'), findsOneWidget);
      expect(find.text('Vendor Shop Captain · 7'), findsOneWidget);
      expect(find.textContaining('Parent'), findsNothing);
      final student = tester.widget<FilterChip>(
        find.byKey(const Key('broadcast-role-student')),
      );
      expect(student.selected, isTrue);

      await tester.tap(find.byKey(const Key('broadcast-role-captain')));
      expect(toggled, ['captain']);
    });
  });

  group('models and permissions', () {
    test('the entry is gated on broadcast grants, not roles', () {
      expect(
        canViewPushBroadcasts(
          const EffectivePermissions(grants: {'notifications.broadcast.read'}),
        ),
        isTrue,
      );
      expect(
        canSendPushBroadcasts(
          const EffectivePermissions(grants: {'notifications.broadcast.read'}),
        ),
        isFalse,
      );
      expect(
        canSendPushBroadcasts(const EffectivePermissions(grants: {'*'})),
        isTrue,
      );
      expect(
        canViewPushBroadcasts(
          const EffectivePermissions(grants: {'canteen.wallet.top_up'}),
        ),
        isFalse,
      );
    });

    test('history explains push delivery in plain words', () {
      BroadcastRecord record(Map<String, dynamic> push) =>
          BroadcastRecord.fromJson({
            'id': 'b',
            'title': 't',
            'body': 'b',
            'createdAt': '2026-09-28T09:30:00Z',
            'push': push,
          });
      expect(
        record({'status': 'queued', 'devices': 3}).pushSummary,
        'Push queued for 3 devices',
      );
      expect(
        record({
          'status': 'queued',
          'devices': 3,
          'sent': 2,
          'failed': 1,
        }).pushSummary,
        'Push sent to 2 of 3 devices · 1 failed',
      );
      expect(
        record({'status': 'no_devices'}).pushSummary,
        'No recipient has push turned on',
      );
    });

    test('a draft only sends an image when there is one', () {
      expect(const BroadcastDraft(title: ' T ', body: ' B ').toJson(), {
        'title': 'T',
        'body': 'B',
        'roles': [],
        'userIds': [],
      });
    });

    test('push and inbox images come from the broadcast data', () {
      expect(
        pushImageUrl(data: {'imageUrl': 'https://cdn.test/a.png'}),
        'https://cdn.test/a.png',
      );
      expect(
        pushImageUrl(
          androidImageUrl: 'https://cdn.test/b.png',
          data: {'imageUrl': 'https://cdn.test/a.png'},
        ),
        'https://cdn.test/b.png',
      );
      expect(pushImageUrl(data: {'imageUrl': 'file:///x.png'}), isNull);

      final notification = AppNotification.fromJson({
        'id': 'n',
        'category': 'broadcast',
        'title': 't',
        'body': 'b',
        'createdAt': '2026-09-28T09:30:00Z',
        'data': {'imageUrl': 'https://cdn.test/a.png'},
      });
      expect(notification.isBroadcast, isTrue);
      expect(notification.imageUrl, 'https://cdn.test/a.png');
    });
  });
}
