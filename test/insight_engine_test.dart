import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/core/access/effective_permissions.dart';
import 'package:supercampus_mobile/src/core/access/module_catalog.dart';
import 'package:supercampus_mobile/src/features/insights/data/insight.dart';
import 'package:supercampus_mobile/src/features/insights/data/insight_engine.dart';
import 'package:supercampus_mobile/src/features/insights/data/sources/attendance_headroom_source.dart';
import 'package:supercampus_mobile/src/features/insights/data/sources/wallet_balance_source.dart';

void main() {
  test('effective permissions accept backend wildcard grants and scopes', () {
    final permissions = EffectivePermissions.fromJson({
      'grants': ['gatepass.*', 'library.visit_pass.read'],
      'scopes': {
        'gatepass.outpass.read': 'all',
        'library.visit_pass.read': 'assigned',
      },
    });

    expect(permissions.canSeeModule(ModuleCatalog.gatepass), isTrue);
    expect(
      permissions.can(ModuleCatalog.gatepass, 'outpass', ModuleActions.approve),
      isTrue,
    );
    expect(
      permissions.scopeFor('gatepass.outpass.read'),
      PermissionScope.institution,
    );
    expect(
      permissions.scopeFor('library.visit_pass.read'),
      PermissionScope.section,
    );
  });

  const attendanceSource = AttendanceHeadroomSource();
  const walletSource = WalletBalanceSource();

  final student = EffectivePermissions.fromJson({
    'modules': {
      'attendance': {
        'scope': 'own',
        'features': {
          'swipe': ['read'],
        },
      },
      'canteen': {
        'scope': 'own',
        'features': {
          'wallet': ['read'],
        },
      },
    },
  });

  InsightContext contextWith({
    int attended = 82,
    int total = 100,
    double balance = 240,
    int hour = 10,
  }) => InsightContext(
    now: DateTime(2026, 8, 6, hour),
    attendance: AttendanceSnapshot(attended: attended, total: total),
    walletBalance: balance,
  );

  group('attendance headroom', () {
    test('reports how many classes can still be missed', () {
      final insight = attendanceSource.evaluate(contextWith())!;

      // 82/100 at a 75% threshold leaves room for 9 more absences:
      // 82 / (100 + 9) = 75.2%, while 82 / 110 = 74.5%.
      expect(insight.headline, 'You can miss 9 more classes');
      expect(insight.tone, InsightTone.positive);
    });

    test('singularises the last spare class', () {
      final insight = attendanceSource.evaluate(
        contextWith(attended: 76, total: 100),
      )!;

      expect(insight.headline, 'You can miss 1 more class');
      expect(insight.tone, InsightTone.caution);
    });

    test('switches to a recovery count once below the threshold', () {
      final insight = attendanceSource.evaluate(
        contextWith(attended: 70, total: 100),
      )!;

      // Needs 20 straight: 90/120 = 75%.
      expect(insight.headline, 'Attend 20 in a row to clear 75%');
      expect(insight.tone, InsightTone.urgent);
      expect(insight.relevance, 1.0);
    });

    test('is skipped when there are no classes yet', () {
      expect(attendanceSource.evaluate(contextWith(total: 0)), isNull);
    });
  });

  group('wallet balance', () {
    test('ranks a low balance higher near lunchtime', () {
      final morning = walletSource.evaluate(contextWith(balance: 90, hour: 9))!;
      final lunch = walletSource.evaluate(contextWith(balance: 90, hour: 12))!;

      expect(lunch.relevance, greaterThan(morning.relevance));
      expect(lunch.headline, 'Low balance — top up before lunch');
    });

    test('stays quiet when the balance is comfortable', () {
      final insight = walletSource.evaluate(contextWith(balance: 400))!;

      expect(insight.tone, InsightTone.neutral);
      expect(insight.relevance, lessThan(0.2));
    });
  });

  group('engine', () {
    test('orders by relevance', () {
      final engine = InsightEngine(
        sources: const [attendanceSource, walletSource],
      );

      // Attendance below the threshold is maximally urgent, so it must beat a
      // healthy wallet.
      final ranked = engine.rank(
        contextWith(attended: 70, total: 100, balance: 400),
        student,
      );

      expect(ranked.first.sourceId, 'attendance_headroom');
      expect(ranked.length, 2);
    });

    test('fatigue demotes a card that keeps being shown', () {
      final engine = InsightEngine(
        sources: const [attendanceSource, walletSource],
        fatiguePenalty: 0.5,
      );
      final context = contextWith(attended: 70, total: 100, balance: 400);

      final first = engine.rank(context, student).first;
      expect(first.sourceId, 'attendance_headroom');

      engine.markShown(first);
      engine.markShown(first);

      expect(engine.rank(context, student).first.sourceId, 'wallet_balance');
    });

    test('skips sources the user has no grant for', () {
      final engine = InsightEngine(
        sources: const [attendanceSource, walletSource],
      );
      final walletOnly = EffectivePermissions.fromJson({
        'modules': {
          'canteen': {
            'features': {
              'wallet': ['read'],
            },
          },
        },
      });

      final ranked = engine.rank(contextWith(), walletOnly);

      expect(ranked.map((i) => i.sourceId), ['wallet_balance']);
    });
  });
}
