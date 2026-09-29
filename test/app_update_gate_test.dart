import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/core/theme/app_theme.dart';
import 'package:supercampus_mobile/src/features/admin_system/data/admin_system_models.dart';
import 'package:supercampus_mobile/src/features/admin_system/data/app_version_repository.dart';
import 'package:supercampus_mobile/src/features/admin_system/presentation/app_update_gate.dart';

class _FakeSource implements AppVersionSource {
  _FakeSource(this.policy, {this.fail = false});

  AppVersionPolicy policy;
  final bool fail;
  final platforms = <String>[];

  @override
  Future<AppVersionPolicy> fetch(String platform) async {
    platforms.add(platform);
    if (fail) throw Exception('offline');
    return policy;
  }
}

AppVersionPolicy _policy({
  String latest = '1.0.9',
  String minimum = '1.0.0',
  bool force = false,
  String store =
      'https://play.google.com/store/apps/details?id=ai.supercampus.mobile',
}) => AppVersionPolicy(
  platform: 'android',
  latestVersion: latest,
  minimumVersion: minimum,
  storeUrl: store,
  forceUpdate: force,
);

Future<List<Uri>> _pumpGate(
  WidgetTester tester, {
  required AppVersionSource source,
  String current = '1.0.9',
  bool isWeb = false,
}) async {
  final opened = <Uri>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: AppUpdateGate(
        source: source,
        currentVersion: current,
        platform: 'android',
        isWeb: isWeb,
        openStore: (uri) async {
          opened.add(uri);
          return true;
        },
        child: const Scaffold(body: Text('App home')),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return opened;
}

void main() {
  test('versions compare numerically', () {
    expect(compareAppVersions('1.0.10', '1.0.9'), greaterThan(0));
    expect(compareAppVersions('1.0.9+34', '1.0.9'), 0);
    expect(compareAppVersions('1.1', '1.1.0'), 0);
    expect(compareAppVersions('1.0.8', '1.0.9'), lessThan(0));
    expect(compareAppVersions('latest', '1.0.9'), isNull);
  });

  test('evaluation follows minimum, latest and force', () {
    expect(evaluateAppUpdate('1.0.9', _policy()), AppUpdateRequirement.none);
    expect(
      evaluateAppUpdate('1.0.8', _policy()),
      AppUpdateRequirement.recommended,
    );
    expect(
      evaluateAppUpdate('1.0.8', _policy(force: true)),
      AppUpdateRequirement.required,
    );
    expect(
      evaluateAppUpdate('0.9.0', _policy()),
      AppUpdateRequirement.required,
    );
    // An unreadable policy never blocks.
    expect(
      evaluateAppUpdate('1.0.9', _policy(latest: 'x', minimum: 'y')),
      AppUpdateRequirement.none,
    );
  });

  testWidgets('below the minimum blocks with a link to the store', (
    tester,
  ) async {
    final opened = await _pumpGate(
      tester,
      source: _FakeSource(_policy(latest: '1.2.0', minimum: '1.1.0')),
    );
    expect(find.byKey(const Key('app-update-required')), findsOneWidget);
    expect(find.text('App home'), findsNothing);
    expect(find.textContaining('Update to 1.2.0'), findsOneWidget);

    await tester.tap(find.byKey(const Key('app-update-open-store')));
    await tester.pumpAndSettle();
    expect(opened.single.host, 'play.google.com');
  });

  testWidgets('force update blocks even above the minimum', (tester) async {
    await _pumpGate(
      tester,
      source: _FakeSource(_policy(latest: '1.1.0', force: true)),
    );
    expect(find.byKey(const Key('app-update-required')), findsOneWidget);
    expect(find.text('App home'), findsNothing);
  });

  testWidgets('below the latest prompts once and can be skipped', (
    tester,
  ) async {
    final source = _FakeSource(_policy(latest: '1.1.0'));
    await _pumpGate(tester, source: source);
    expect(find.byKey(const Key('app-update-prompt')), findsOneWidget);
    expect(find.text('App home'), findsOneWidget);

    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('app-update-prompt')), findsNothing);
    expect(find.text('App home'), findsOneWidget);

    // Resuming checks again but does not nag about the same version.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(source.platforms, ['android', 'android']);
    expect(find.byKey(const Key('app-update-prompt')), findsNothing);
  });

  testWidgets('a policy raised while running blocks on resume', (tester) async {
    final source = _FakeSource(_policy());
    await _pumpGate(tester, source: source);
    expect(find.text('App home'), findsOneWidget);

    source.policy = _policy(latest: '1.1.0', minimum: '1.1.0');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('app-update-required')), findsOneWidget);
  });

  testWidgets('web builds are never checked or blocked', (tester) async {
    final source = _FakeSource(_policy(latest: '9.0.0', minimum: '9.0.0'));
    await _pumpGate(tester, source: source, isWeb: true);
    expect(source.platforms, isEmpty);
    expect(find.text('App home'), findsOneWidget);
    expect(find.byKey(const Key('app-update-required')), findsNothing);
  });

  testWidgets('an unreachable policy fails open', (tester) async {
    await _pumpGate(
      tester,
      source: _FakeSource(_policy(minimum: '9.0.0'), fail: true),
    );
    expect(find.text('App home'), findsOneWidget);
  });

  testWidgets('current users are not prompted by the seeded policy', (
    tester,
  ) async {
    await _pumpGate(tester, source: _FakeSource(_policy()), current: '1.0.9');
    expect(find.text('App home'), findsOneWidget);
    expect(find.byKey(const Key('app-update-prompt')), findsNothing);
  });
}
