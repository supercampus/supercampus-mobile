import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/core/widgets/app_design_viewport.dart';

void main() {
  testWidgets('does not divide by zero before the Android surface is ready', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(Size.zero);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: AppDesignViewport(child: Text('SuperCampus ready')),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('SuperCampus ready'), findsOneWidget);
  });

  testWidgets('normalizes a narrow Android-style viewport to the web canvas', (
    tester,
  ) async {
    MediaQueryData? observed;

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(360, 800),
          padding: EdgeInsets.only(top: 24),
          textScaler: TextScaler.linear(1.6),
        ),
        child: AppDesignViewport(
          child: Builder(
            builder: (context) {
              observed = MediaQuery.of(context);
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    );

    expect(observed, isNotNull);
    expect(observed!.size.width, AppDesignViewport.designWidth);
    expect(observed!.size.height, closeTo(955.56, 0.01));
    expect(observed!.padding.top, closeTo(28.67, 0.01));
    expect(observed!.textScaler.scale(20), 20);
    expect(tester.takeException(), isNull);
  });

  testWidgets('does not enlarge an already wide design viewport', (
    tester,
  ) async {
    MediaQueryData? observed;

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(430, 900),
          textScaler: TextScaler.linear(1.4),
        ),
        child: AppDesignViewport(
          child: Builder(
            builder: (context) {
              observed = MediaQuery.of(context);
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    );

    expect(observed!.size, const Size(430, 900));
    expect(observed!.textScaler.scale(20), 20);
  });
}
