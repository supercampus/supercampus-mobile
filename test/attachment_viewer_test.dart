import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:supercampus_mobile/src/core/widgets/attachment_viewer.dart';

Uint8List _png() {
  final image = img.Image(width: 4, height: 4);
  img.fill(image, color: img.ColorRgb8(123, 66, 246));
  return Uint8List.fromList(img.encodePng(image));
}

Future<void> _open(
  WidgetTester tester, {
  required AttachmentLoader load,
  String name = 'notice',
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: AttachmentViewerScreen(
        url: 'https://api.supercampus.ai/api/media/files/mec/1/$name',
        name: name,
        load: load,
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  group('what an attachment is', () {
    test('is read from the file itself before its name', () {
      final pdf = Uint8List.fromList('%PDF-1.7\n'.codeUnits);
      expect(attachmentKindOf(pdf, 'download'), AttachmentKind.pdf);
      expect(attachmentKindOf(_png(), 'notice.pdf'), AttachmentKind.image);
      final jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0, 0]);
      expect(attachmentKindOf(jpeg, 'x'), AttachmentKind.image);
    });

    test('falls back to the name, then to other', () {
      final unknown = Uint8List.fromList([1, 2, 3, 4]);
      expect(attachmentKindOf(unknown, 'Circular.PDF'), AttachmentKind.pdf);
      expect(attachmentKindOf(unknown, 'photo.webp'), AttachmentKind.image);
      expect(attachmentKindOf(unknown, 'sheet.xlsx'), AttachmentKind.other);
    });

    test('Cloudinary attachments fall back to the API relay', () {
      const pdf =
          'https://res.cloudinary.com/campus/image/upload/v1/supercampus/mec/media/SCAN.pdf';
      final proxy = attachmentProxyUri(pdf, apiBase: 'https://api.supercampus.ai/');
      expect(proxy.toString(),
          startsWith('https://api.supercampus.ai/api/media/proxy?url='));
      expect(proxy!.queryParameters['url'], pdf);
      expect(
        attachmentProxyUri(
          'https://api.supercampus.ai/api/media/files/mec/1/a.pdf',
        ),
        isNull,
      );
    });

    test('an http link is upgraded on a secure web page only', () {
      expect(
        attachmentFetchUri('http://api.supercampus.ai/a.pdf', web: false)
            .scheme,
        'http',
      );
      expect(
        attachmentFetchUri('http://127.0.0.1:4000/a.pdf', web: true).scheme,
        'http',
      );
    });

    test('the file name prefers the announcement name, else the URL', () {
      expect(attachmentFileName('https://x/a/b/c.pdf', 'Exam.pdf'), 'Exam.pdf');
      expect(attachmentFileName('https://x/a/b/Fee%20notice.pdf', null),
          'Fee notice.pdf');
      expect(attachmentFileName('https://x/', ' '), 'attachment');
    });
  });

  testWidgets('an image previews in the app, zoomable, with Download', (
    tester,
  ) async {
    await _open(tester, name: 'poster.png', load: (_) async => _png());

    expect(find.byKey(const ValueKey('attachment-image')), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.text('poster.png'), findsOneWidget);
    final download = tester.widget<IconButton>(
      find.byKey(const ValueKey('attachment-download')),
    );
    expect(download.onPressed, isNotNull);
  });

  testWidgets('a file with no preview offers Download instead', (
    tester,
  ) async {
    await _open(
      tester,
      name: 'timetable.xlsx',
      load: (_) async => Uint8List.fromList([1, 2, 3, 4]),
    );

    expect(find.text('No preview for this file'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Download'), findsOneWidget);
  });

  testWidgets('a failed load says so and can retry', (tester) async {
    var calls = 0;
    await _open(
      tester,
      name: 'notice.pdf',
      load: (_) async {
        calls++;
        throw Exception('offline');
      },
    );

    expect(find.text("Couldn't load the attachment"), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.pump();
    expect(calls, 2);
  });

  testWidgets('Preview opens the in-app viewer instead of leaving the app', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AttachmentActions(
            url: 'https://api.supercampus.ai/api/media/files/mec/1/a.pdf',
            name: 'Circular.pdf',
          ),
        ),
      ),
    );

    expect(find.text('Preview'), findsOneWidget);
    expect(find.byTooltip('Download'), findsOneWidget);
    await tester.tap(find.text('Preview'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(AttachmentViewerScreen), findsOneWidget);
    expect(find.text('Circular.pdf'), findsOneWidget);
  });
}
