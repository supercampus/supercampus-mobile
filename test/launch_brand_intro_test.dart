import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/core/widgets/launch_brand_intro.dart';

void main() {
  testWidgets('shows the approved logo and lightweight Poppins tagline', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: LaunchBrandIntro())),
    );

    expect(find.byType(Image), findsOneWidget);
    expect(find.text('the one stop for campus application'), findsOneWidget);

    final tagline = tester.widget<Text>(
      find.text('the one stop for campus application'),
    );
    expect(tagline.style?.fontFamily, 'Poppins');
    expect(tagline.style?.fontWeight, FontWeight.w400);
    expect(tagline.style?.fontSize, 9);

    await tester.pump(const Duration(milliseconds: 1900));
    expect(tester.takeException(), isNull);
  });
}
