import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/core/theme/app_theme.dart';
import 'package:supercampus_mobile/src/features/modules/presentation/widgets/dashboard_nav_bar.dart';

void main() {
  late List<String> selected;
  late int homes;

  setUp(() {
    DashboardNavBar.resetTapMemory();
    selected = [];
    homes = 0;
  });

  Future<void> pumpBar(WidgetTester tester, {String selectedId = ''}) {
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          bottomNavigationBar: DashboardNavBar(
            selectedId: selectedId,
            onSelect: selected.add,
            onHome: () => homes++,
          ),
        ),
      ),
    );
  }

  Finder tab(String tooltip) => find.byTooltip(tooltip);

  testWidgets('a single tap on Wall selects Wall', (tester) async {
    await pumpBar(tester);
    await tester.tap(tab('Wall - Announcements & Circulars'));
    await tester.pump();
    expect(selected, ['wall']);
    expect(homes, 0);
  });

  testWidgets('a double tap on Wall returns home', (tester) async {
    await pumpBar(tester);
    await tester.tap(tab('Wall - Announcements & Circulars'));
    await tester.pump(const Duration(milliseconds: 120));
    await tester.tap(tab('Wall - Announcements & Circulars'));
    await tester.pump();
    expect(homes, 1);
    expect(selected, ['wall'], reason: 'the first tap still navigates; the second goes home');
  });

  testWidgets('a double tap on Reports returns home', (tester) async {
    await pumpBar(tester, selectedId: 'analysis');
    await tester.tap(tab('Reports & Analysis'));
    await tester.pump(const Duration(milliseconds: 120));
    await tester.tap(tab('Reports & Analysis'));
    await tester.pump();
    expect(homes, 1);
  });

  testWidgets('the double tap is recognised across a new nav bar instance', (tester) async {
    // First tap on the home screen's bar…
    await pumpBar(tester);
    await tester.tap(tab('Wall - Announcements & Circulars'));
    await tester.pump(const Duration(milliseconds: 100));
    // …second tap lands on the Wall page's own bar (a different widget).
    await pumpBar(tester, selectedId: 'wall');
    await tester.tap(tab('Wall - Announcements & Circulars'));
    await tester.pump();
    expect(homes, 1);
  });

  testWidgets('slow taps are two single taps, not a double tap', (tester) async {
    await pumpBar(tester);
    await tester.tap(tab('Wall - Announcements & Circulars'));
    await tester.pump();
    // Real time must pass: the window is measured with DateTime.now().
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 600)));
    await tester.tap(tab('Wall - Announcements & Circulars'));
    await tester.pump();
    expect(homes, 0);
    expect(selected, ['wall', 'wall']);
  });

  testWidgets('double taps on Academics or Gatepass do not go home', (tester) async {
    await pumpBar(tester);
    await tester.tap(tab('Academics'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(tab('Academics'));
    await tester.pump();
    expect(homes, 0);
    expect(selected, ['acads', 'acads']);
  });
}
