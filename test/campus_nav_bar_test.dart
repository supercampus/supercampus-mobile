import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/core/theme/app_theme.dart';
import 'package:supercampus_mobile/src/core/widgets/campus_nav_bar.dart';

void main() {
  testWidgets('home and modules use light inactive and bold selected states', (
    tester,
  ) async {
    await tester.pumpWidget(_bar(selectedId: 'home'));

    expect(find.byIcon(Icons.home_rounded), findsOneWidget);
    expect(_label(tester, 'Home').fontWeight, FontWeight.w700);
    expect(_label(tester, 'Modules').fontWeight, FontWeight.w400);

    await tester.pumpWidget(_bar(selectedId: 'modules'));
    await tester.pump();

    expect(find.byIcon(Icons.home_outlined), findsOneWidget);
    expect(_label(tester, 'Home').fontWeight, FontWeight.w400);
    expect(_label(tester, 'Modules').fontWeight, FontWeight.w700);
  });

  testWidgets('scan is a solid brand-coloured key with a crisp glyph, an '
      'accessible label and room for its caption', (tester) async {
    var scans = 0;
    await tester.pumpWidget(_bar(selectedId: 'home', onScan: () => scans++));

    final key = find.byKey(const ValueKey('nav-scan-key'));
    final box = tester.widget<AnimatedContainer>(key);
    final decoration = box.decoration! as BoxDecoration;
    // A flat brand fill — no gradient, no viewfinder brackets.
    expect(decoration.gradient, isNull);
    expect(decoration.color, AppPalette.light.brand);
    expect(
      find.descendant(
        of: key,
        matching: find.byIcon(Icons.qr_code_scanner_rounded),
      ),
      findsOneWidget,
    );
    // A rounded square rather than a pill.
    final radius = (decoration.borderRadius! as BorderRadius).topLeft.x;
    expect(radius, lessThan(tester.getSize(key).height / 2));

    // The key sits inside the bar, clear of its caption.
    final bar = tester.getRect(find.byType(CampusNavBar).first);
    final keyRect = tester.getRect(key);
    final caption = tester.getRect(find.text('Scan'));
    expect(bar.contains(keyRect.topLeft), isTrue);
    expect(bar.contains(keyRect.bottomRight), isTrue);
    expect(keyRect.bottom, lessThanOrEqualTo(caption.top + 0.5));

    expect(find.bySemanticsLabel('Scan QR code'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('nav-scan')));
    expect(scans, 1);
  });

  testWidgets('pressing scan presses the key in, releasing lets it go', (
    tester,
  ) async {
    await tester.pumpWidget(_bar(selectedId: 'home', onScan: () {}));

    double scale() => tester
        .widget<AnimatedScale>(
          find.ancestor(
            of: find.byKey(const ValueKey('nav-scan-key')),
            matching: find.byType(AnimatedScale),
          ),
        )
        .scale;

    expect(scale(), 1);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('nav-scan'))),
    );
    await tester.pump();
    expect(scale(), lessThan(1));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(scale(), 1);
  });

  testWidgets('without a handler the scan key stays in place but dimmed', (
    tester,
  ) async {
    await tester.pumpWidget(_bar(selectedId: 'home', showScan: true));

    final decoration =
        tester
                .widget<AnimatedContainer>(
                  find.byKey(const ValueKey('nav-scan-key')),
                )
                .decoration!
            as BoxDecoration;
    expect(decoration.color!.a, lessThan(1));
    await tester.tap(find.byKey(const ValueKey('nav-scan')));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  for (final dark in [false, true]) {
    for (final count in [2, 3, 4]) {
      testWidgets('$count destinations and scan share the bar evenly '
          '(${dark ? 'dark' : 'light'})', (tester) async {
        final ids = ['home', 'menu', 'settled', 'sales'].take(count).toList();
        await tester.pumpWidget(
          _bar(
            selectedId: ids.last,
            onScan: () {},
            dark: dark,
            items: [
              for (final id in ids)
                CampusNavItem(
                  id: id,
                  label: id[0].toUpperCase() + id.substring(1),
                  icon: const Icon(Icons.circle_outlined),
                  selectedIcon: const Icon(Icons.circle),
                  onTap: () {},
                ),
            ],
          ),
        );

        final bar = tester.getRect(find.byType(CampusNavBar).first);
        final slots = [
          for (final id in ids) tester.getRect(find.byKey(ValueKey('nav-$id'))),
          tester.getRect(find.byKey(const ValueKey('nav-scan'))),
        ];
        // Equal slots, side by side, inside the bar, the scanner last.
        for (var i = 0; i < slots.length; i++) {
          expect(slots[i].width, closeTo(slots.first.width, 0.5));
          expect(slots[i].left, greaterThanOrEqualTo(bar.left));
          expect(slots[i].right, lessThanOrEqualTo(bar.right));
          if (i > 0) {
            expect(slots[i].left, closeTo(slots[i - 1].right, 0.5));
          }
        }
        // The current destination is marked, for sight and for VoiceOver.
        expect(find.byIcon(Icons.circle), findsOneWidget);
        expect(
          tester.getSemantics(find.byKey(ValueKey('nav-${ids.last}'))),
          isSemantics(
            label: ids.last[0].toUpperCase() + ids.last.substring(1),
            isButton: true,
            isSelected: true,
            hasTapAction: true,
          ),
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
}

TextStyle _label(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style!;

Widget _bar({
  required String selectedId,
  VoidCallback? onScan,
  bool? showScan,
  bool dark = false,
  List<CampusNavItem>? items,
}) => MaterialApp(
  theme: dark ? AppTheme.dark : AppTheme.light,
  home: Scaffold(
    body: Align(
      alignment: Alignment.bottomCenter,
      child: CampusNavBar(
        selectedId: selectedId,
        initials: 'AS',
        items: items,
        showScan: showScan,
        onHome: () {},
        onModules: () {},
        onProfile: () {},
        onScan: onScan,
      ),
    ),
  ),
);
