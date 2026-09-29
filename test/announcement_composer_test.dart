import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supercampus_mobile/src/core/media/media_repository.dart';
import 'package:supercampus_mobile/src/core/media/media_scope.dart';
import 'package:supercampus_mobile/src/core/widgets/announcement_composer.dart';

/// A picked file as Flutter web hands it over: a name and bytes behind a blob
/// URL, and no local path.
final class _WebPickedFile extends PlatformFile {
  _WebPickedFile(this.name, this.bytes);

  @override
  final String name;
  final Uint8List bytes;

  @override
  Uri get uri => Uri.parse('blob:https://app.supercampus.ai/$name');

  @override
  get xFile => throw UnimplementedError('not used by the composer');

  @override
  Future<int> length() async => bytes.length;

  @override
  Future<Uint8List> readAsBytes() async => bytes;

  @override
  Stream<Uint8List> readAsByteStream() => Stream.value(bytes);
}

class _FakeFilePicker extends FilePickerPlatform {
  _FakeFilePicker(this.file);

  final PlatformFile? file;
  FileType? requestedType;
  List<String>? requestedExtensions;

  @override
  Future<PlatformFile?> pickFile({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    requestedType = type;
    requestedExtensions = allowedExtensions;
    return file;
  }
}

final _pdfBytes = Uint8List.fromList(
  utf8.encode('%PDF-1.4\n1 0 obj<<>>endobj\ntrailer<<>>\n%%EOF\n'),
);

Future<void> _fillRequiredFields(WidgetTester tester) async {
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Announcement type'),
    'Circular',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Title'),
    'Semester exam schedule',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Description'),
    'The timetable is attached.',
  );
  await tester.tap(find.text('Choose announcement date'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

Future<AnnouncementDraft? Function()> _pumpComposer(
  WidgetTester tester, {
  MediaRepository? repository,
  String submitLabel = 'Save announcement',
}) async {
  AnnouncementDraft? saved;
  Widget app = MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: FilledButton(
          onPressed: () async {
            saved = await showAnnouncementComposer(
              context,
              submitLabel: submitLabel,
            );
          },
          child: const Text('Compose'),
        ),
      ),
    ),
  );
  if (repository != null) {
    // Above MaterialApp, as in the real app, so the modal sheet can reach it.
    app = MediaScope(repository: repository, child: app);
  }
  await tester.pumpWidget(app);
  return () => saved;
}

void main() {
  late FilePickerPlatform originalPicker;

  setUp(() => originalPicker = FilePickerPlatform.instance);
  tearDown(() => FilePickerPlatform.instance = originalPicker);

  testWidgets('requires and returns the standard announcement fields', (
    tester,
  ) async {
    final saved = await _pumpComposer(tester);

    await tester.tap(find.text('Compose'));
    await tester.pumpAndSettle();

    expect(find.text('Announcement type'), findsOneWidget);
    expect(find.text('Select date'), findsOneWidget);
    expect(find.text('Title'), findsOneWidget);
    expect(find.text('Description'), findsOneWidget);
    expect(find.text('Attachment (PDF / Image)'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Announcement type'),
      'Campus Event',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Title'),
      'Innovation Day',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Description'),
      'Student registrations are now open.',
    );
    await tester.tap(find.text('Choose announcement date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(DateTime.now().day.toString()).last);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save announcement'));
    await tester.tap(find.text('Save announcement'));
    await tester.pumpAndSettle();

    final draft = saved();
    expect(draft?.type, 'Campus Event');
    expect(draft?.title, 'Innovation Day');
    expect(draft?.description, 'Student registrations are now open.');
    expect(draft?.date.day, DateTime.now().day);
  });

  testWidgets('a missing date is reported inside the sheet', (tester) async {
    await _pumpComposer(tester);
    await tester.tap(find.text('Compose'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Announcement type'),
      'Circular',
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'Title'), 'T');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Description'),
      'D',
    );
    await tester.ensureVisible(find.text('Save announcement'));
    await tester.tap(find.text('Save announcement'));
    await tester.pumpAndSettle();

    expect(find.text('Select the announcement date.'), findsOneWidget);
    expect(find.text('Announcement type'), findsOneWidget);
  });

  testWidgets(
    'attaches a PDF picked as bytes only (web) and publishes its URL',
    (tester) async {
      final picker = _FakeFilePicker(
        _WebPickedFile('Exam circular.pdf', _pdfBytes),
      );
      FilePickerPlatform.instance = picker;
      http.MultipartRequest? sent;
      List<int>? sentBytes;
      final repository = MediaRepository(
        baseUrl: 'https://api.supercampus.ai',
        accessToken: 'token',
        client: MockClient.streaming((request, bodyStream) async {
          sent = request as http.MultipartRequest;
          sentBytes = await bodyStream.toBytes();
          return http.StreamedResponse(
            Stream.value(
              utf8.encode(
                jsonEncode({
                  'data': {
                    'secureUrl':
                        'https://api.supercampus.ai/api/media/files/mec/1f0c/Exam-circular.pdf',
                    'publicId': 'db:1f0c',
                    'resourceType': 'raw',
                    'bytes': _pdfBytes.length,
                  },
                }),
              ),
            ),
            201,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      final saved = await _pumpComposer(
        tester,
        repository: repository,
        submitLabel: 'Publish now',
      );
      await tester.tap(find.text('Compose'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Attach file'));
      await tester.pumpAndSettle();

      expect(picker.requestedType, FileType.custom);
      expect(picker.requestedExtensions, containsAll(['pdf', 'jpg', 'png']));
      expect(sent?.url.path, '/api/media/upload');
      expect(sent?.files.single.field, 'file');
      expect(sent?.files.single.filename, 'Exam circular.pdf');
      expect(
        latin1.decode(sentBytes!, allowInvalid: true),
        contains('%PDF-1.4'),
      );
      expect(find.text('Official PDF circular ready to publish'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('announcement-attachment-error')),
        findsNothing,
      );

      await _fillRequiredFields(tester);
      await tester.ensureVisible(find.text('Publish now'));
      await tester.tap(find.text('Publish now'));
      await tester.pumpAndSettle();

      final draft = saved();
      expect(draft?.attachmentName, 'Exam circular.pdf');
      expect(
        draft?.attachmentUrl,
        'https://api.supercampus.ai/api/media/files/mec/1f0c/Exam-circular.pdf',
      );
    },
  );

  testWidgets('a failed upload is shown in the sheet, never dropped silently', (
    tester,
  ) async {
    FilePickerPlatform.instance = _FakeFilePicker(
      _WebPickedFile('circular.pdf', _pdfBytes),
    );
    final repository = MediaRepository(
      baseUrl: 'https://api.supercampus.ai',
      accessToken: 'token',
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'error': 'Media storage is not configured',
            'code': 'service_unavailable',
          }),
          503,
        ),
      ),
    );
    final saved = await _pumpComposer(
      tester,
      repository: repository,
      submitLabel: 'Publish now',
    );
    await tester.tap(find.text('Compose'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Attach file'));
    await tester.pumpAndSettle();

    expect(
      find.text('Attachment not added. Media storage is not configured'),
      findsOneWidget,
    );
    expect(find.text('Official PDF circular ready to publish'), findsNothing);

    await _fillRequiredFields(tester);
    await tester.ensureVisible(find.text('Publish now'));
    await tester.tap(find.text('Publish now'));
    await tester.pumpAndSettle();
    final draft = saved();
    expect(draft?.attachmentUrl, isNull);
  });

  testWidgets('a file that is neither a PDF nor an image is refused', (
    tester,
  ) async {
    FilePickerPlatform.instance = _FakeFilePicker(
      _WebPickedFile('notes.pdf', Uint8List.fromList(utf8.encode('hello'))),
    );
    var uploads = 0;
    final repository = MediaRepository(
      baseUrl: 'https://api.supercampus.ai',
      accessToken: 'token',
      client: MockClient((_) async {
        uploads++;
        return http.Response('{}', 500);
      }),
    );
    await _pumpComposer(tester, repository: repository);
    await tester.tap(find.text('Compose'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Attach file'));
    await tester.pumpAndSettle();

    expect(uploads, 0);
    expect(
      find.text('Attachment not added. Choose a PDF, JPG, PNG or WebP file.'),
      findsOneWidget,
    );
  });

  testWidgets('an image picked as bytes only is cropped and uploaded', (
    tester,
  ) async {
    final png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8DwHwAFBQIAX8jx0gAAAABJRU5ErkJggg==',
    );
    FilePickerPlatform.instance = _FakeFilePicker(_WebPickedFile('IMG.png', png));
    String? uploadedName;
    final repository = MediaRepository(
      baseUrl: 'https://api.supercampus.ai',
      accessToken: 'token',
      client: MockClient.streaming((request, bodyStream) async {
        await bodyStream.drain<void>();
        uploadedName = (request as http.MultipartRequest).files.single.filename;
        return http.StreamedResponse(
          Stream.value(
            utf8.encode(
              jsonEncode({
                'data': {
                  'secureUrl': 'https://res.cloudinary.com/x/image/upload/v1/c.png',
                  'publicId': 'supercampus/mec/media/c',
                  'resourceType': 'image',
                  'bytes': 10,
                },
              }),
            ),
          ),
          201,
        );
      }),
    );
    await _pumpComposer(tester, repository: repository);
    await tester.tap(find.text('Compose'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Attach file'));
    // Decoding runs on the engine, outside the fake test clock.
    // The upload spinner animates behind the dialog, so pump rather than
    // settle while the crop dialog is open.
    for (var i = 0;
        i < 20 && find.text('Crop announcement image').evaluate().isEmpty;
        i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Crop announcement image'), findsOneWidget);

    await tester.tap(find.text('Use this crop'));
    // Encoding the crop is engine work too; the spinner keeps the frame
    // scheduler busy meanwhile, so pump until the upload lands.
    for (var i = 0; i < 20 && uploadedName == null; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();

    expect(uploadedName, startsWith('announcement-cover-'));
    expect(find.text('Cropped to 16:7 and ready to publish'), findsOneWidget);
  });
}
