import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/core/widgets/launch_brand_intro.dart';

void main() {
  testWidgets('shows 1-second animated hero logo reveal with Brittany SuperCampus branding', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: LaunchBrandIntro())),
    );

    // Initial frame shows the hero logo and branding on pure white
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('SuperCampus'), findsOneWidget);

    final brandText = tester.widget<Text>(find.text('SuperCampus'));
    expect(brandText.style?.fontFamily, 'Brittany');

    // The legacy tagline is removed
    expect(find.text('the one stop for campus application'), findsNothing);

    // Pump to mid-animation (500ms)
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(Image), findsOneWidget);

    // Complete the 1-second animation
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);
  });
}
