import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/features/modules/presentation/widgets/home_top_bar.dart';

void main() {
  testWidgets('home header shows first name, alerts and settings', (
    tester,
  ) async {
    var alerts = 0;
    var settings = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeTopBar(
            displayName: 'Kaarnesh S',
            onAlertsTap: () => alerts++,
            onSettingsTap: () => settings++,
            hasAlerts: true,
          ),
        ),
      ),
    );

    expect(find.text('Kaarnesh'), findsOneWidget);
    expect(find.byKey(const ValueKey('home-alerts')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-settings')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('home-alerts')));
    await tester.tap(find.byKey(const ValueKey('home-settings')));
    expect(alerts, 1);
    expect(settings, 1);
  });
}
