@Tags(['golden'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/app.dart';
import 'package:supercampus_mobile/src/features/insights/presentation/insight_dashboard.dart';

/// Renders the student home at phone size so the layout can be eyeballed —
/// `flutter test --update-goldens test/student_home_golden_test.dart` writes
/// the PNGs under `test/goldens/`.
///
/// Tagged so `flutter test` skips it by default: goldens are rasterised, and
/// a different host font stack or Skia build will shift pixels without
/// anything being wrong. Run it deliberately, look at the image.
void main() {
  setUpAll(_loadFonts);

  testWidgets('student home', (tester) async {
    await _signIn(tester);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/student_home.png'),
    );
  });

  testWidgets('student home with the nav bar collapsed', (tester) async {
    await _signIn(tester);

    // Reading down the page closes the nav bar to the scan button.
    await tester.drag(find.byType(InsightDashboard), const Offset(0, -180));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/student_home_collapsed.png'),
    );
  });
}

Future<void> _signIn(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(const SupercampusApp());

  await tester.enterText(
    find.byType(TextFormField).at(0),
    'student@example.com',
  );
  await tester.enterText(find.byType(TextFormField).at(1), 'password123');
  await tester.ensureVisible(find.text('Enter Student Portal'));
  await tester.tap(find.text('Enter Student Portal'));
  await tester.pumpAndSettle();
}

/// Widget tests draw every glyph as a box unless the real fonts are loaded.
Future<void> _loadFonts() async {
  await _load('Poppins', [
    'assets/fonts/Poppins-Light.ttf',
    'assets/fonts/Poppins-Regular.ttf',
    'assets/fonts/Poppins-Medium.ttf',
  ]);

  final icons = File(
    '${_flutterRoot()}/bin/cache/artifacts/material_fonts/'
    'materialicons-regular.otf',
  );
  if (icons.existsSync()) {
    await _loadBytes('MaterialIcons', [icons.readAsBytesSync()]);
  }
}

Future<void> _load(String family, List<String> paths) => _loadBytes(family, [
  for (final p in paths)
    if (File(p).existsSync()) File(p).readAsBytesSync(),
]);

Future<void> _loadBytes(String family, List<List<int>> fonts) async {
  if (fonts.isEmpty) return;
  final loader = FontLoader(family);
  for (final bytes in fonts) {
    loader.addFont(
      Future.value(
        ByteData.view(Uint8List.fromList(bytes).buffer),
      ),
    );
  }
  await loader.load();
}

String _flutterRoot() {
  final fromEnv = Platform.environment['FLUTTER_ROOT'];
  if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;

  // `flutter test` runs the Dart VM out of the SDK, so the executable path
  // points back at the toolchain that owns the icon font.
  final dart = File(Platform.resolvedExecutable).parent.path;
  return Directory('$dart/../../..').resolveSymbolicLinksSync();
}
