import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/core/widgets/skeleton_loading.dart';

void main() {
  testWidgets('SkeletonBox preserves the exact requested space', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(child: SkeletonBox(width: 148, height: 44)),
      ),
    );

    expect(tester.getSize(find.byType(SkeletonBox)), const Size(148, 44));
  });

  testWidgets('SkeletonBox remains static when animations are disabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          home: Center(child: SkeletonBox(width: 120, height: 36)),
        ),
      ),
    );

    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(SkeletonBox)), const Size(120, 36));
  });
}
