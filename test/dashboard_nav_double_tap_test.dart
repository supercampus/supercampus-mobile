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

  for (final (tooltip, id) in [('Academics', 'acads'), ('Gatepass', 'gatepass')]) {
    testWidgets('a double tap on $tooltip returns home', (tester) async {
      await pumpBar(tester, selectedId: id);
      await tester.tap(tab(tooltip));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(tab(tooltip));
      await tester.pump();
      expect(homes, 1);
      expect(selected, [id]);
    });
  }

  testWidgets('a second tap landing on the home bar does not reopen the module', (tester) async {
    // First tap on the open module's bar closes it (host behaviour)…
    await pumpBar(tester, selectedId: 'gatepass');
    await tester.tap(tab('Gatepass'));
    await tester.pump(const Duration(milliseconds: 100));
    // …so the second lands on the home screen's bar, which has no onHome.
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          bottomNavigationBar: DashboardNavBar(selectedId: '', onSelect: selected.add),
        ),
      ),
    );
    await tester.tap(tab('Gatepass'));
    await tester.pump();
    expect(selected, ['gatepass'], reason: 'only the first tap selects');
  });

  testWidgets('taps on two different tabs are not a double tap', (tester) async {
    await pumpBar(tester);
    await tester.tap(tab('Academics'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(tab('Gatepass'));
    await tester.pump();
    expect(homes, 0);
    expect(selected, ['acads', 'gatepass']);
  });
}
