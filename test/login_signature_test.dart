import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/features/authentication/presentation/login_signature.dart';

String _word(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(
    find.descendant(
      of: find.byType(LoginSignature),
      matching: find.byType(CustomPaint),
    ),
  );
  // ignore: avoid_dynamic_calls
  return (paint.painter as dynamic).word as String;
}

void main() {
  testWidgets('writes a word, un-writes it at 2x, then writes the next', (
    tester,
  ) async {
    const words = ['SuperCampus', 'Learning'];
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: LoginSignature(words: words, animate: true)),
      ),
    );
    expect(_word(tester), 'SuperCampus');

    Future<void> run(Duration d) async {
      for (var ms = 0; ms < d.inMilliseconds; ms += 20) {
        await tester.pump(const Duration(milliseconds: 20));
      }
    }

    final write = LoginSignature.writeDuration('SuperCampus');
    await run(write + LoginSignature.hold + const Duration(milliseconds: 100));
    // Mid un-write, still the first word.
    expect(_word(tester), 'SuperCampus');
    // Un-writing takes half as long as writing.
    await run(write ~/ 2 + LoginSignature.gap + const Duration(milliseconds: 100));
    expect(_word(tester), 'Learning');

    // Unmounting mid-stroke is clean.
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('reduced motion shows the signature still', (tester) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          home: Scaffold(body: LoginSignature(animate: true)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(_word(tester), 'SuperCampus');
    expect(find.bySemanticsLabel('SuperCampus'), findsOneWidget);
  });
}
