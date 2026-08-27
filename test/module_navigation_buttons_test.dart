import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/core/widgets/module_navigation_buttons.dart';

void main() {
  testWidgets('module navigation exposes separate back and home actions', (
    tester,
  ) async {
    var backPressed = false;
    var homePressed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            leading: ModuleBackButton(onPressed: () => backPressed = true),
            actions: [ModuleHomeButton(onPressed: () => homePressed = true)],
          ),
        ),
      ),
    );

    expect(find.byTooltip('Back'), findsOneWidget);
    expect(find.byTooltip('Home'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.tap(find.byTooltip('Home'));

    expect(backPressed, isTrue);
    expect(homePressed, isTrue);
  });
}
