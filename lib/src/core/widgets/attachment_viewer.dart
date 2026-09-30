import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:printing/printing.dart';

import '../theme/app_theme.dart';

/// What an attachment turned out to be once its bytes arrived.
enum AttachmentKind { pdf, image, other }

/// Decides what [bytes] are from their own signature first, so a file served
/// without an extension or with a generic content type still previews; the
/// name is only a fallback.
@visibleForTesting
AttachmentKind attachmentKindOf(Uint8List bytes, String name) {
  bool starts(List<int> magic) =>
      bytes.length >= magic.length &&
      Iterable<int>.generate(magic.length).every((i) => bytes[i] == magic[i]);
  if (starts(const [0x25, 0x50, 0x44, 0x46])) return AttachmentKind.pdf; // %PDF
  if (starts(const [0x89, 0x50, 0x4E, 0x47]) || // PNG
      starts(const [0xFF, 0xD8, 0xFF]) || // JPEG
      starts(const [0x47, 0x49, 0x46, 0x38]) || // GIF
      (bytes.length > 12 &&
          starts(const [0x52, 0x49, 0x46, 0x46]) &&
          bytes[8] == 0x57 &&
          bytes[9] == 0x45 &&
          bytes[10] == 0x42 &&
          bytes[11] == 0x50)) {
    // WEBP
    return AttachmentKind.image;
  }
  final lower = name.toLowerCase();
  if (lower.endsWith('.pdf')) return AttachmentKind.pdf;
  if (RegExp(r'\.(png|jpe?g|gif|webp)$').hasMatch(lower)) {
    return AttachmentKind.image;
  }
  return AttachmentKind.other;
}

/// A readable file name for [url], preferring the name the announcement gave.
@visibleForTesting
String attachmentFileName(String url, String? name) {
  final given = name?.trim() ?? '';
  if (given.isNotEmpty) return given;
  final segments = Uri.tryParse(url)?.pathSegments ?? const <String>[];
  final last = segments.isEmpty ? '' : Uri.decodeComponent(segments.last);
  return last.isEmpty ? 'attachment' : last;
}

/// Fetches an attachment's bytes. Swappable in tests.
typedef AttachmentLoader = Future<Uint8List> Function(String url);

Future<Uint8List> _download(String url) async {
  final response = await http.get(Uri.parse(url));
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception('HTTP ${response.statusCode}');
  }
  return response.bodyBytes;
}

/// Saves an attachment straight to the device (a browser download on the
/// web) without opening anything.
Future<void> downloadAttachment(
  BuildContext context, {
  required String url,
  String? name,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final fileName = attachmentFileName(url, name);
  messenger.showSnackBar(SnackBar(content: Text('Downloading $fileName…')));
  try {
    final bytes = await _download(url);
    final dot = fileName.lastIndexOf('.');
    final extension = dot > 0 ? fileName.substring(dot + 1) : null;
    final saved = await FilePicker.saveFile(
      dialogTitle: 'Save attachment',
      fileName: fileName,
      type: extension == null ? FileType.any : FileType.custom,
      allowedExtensions: extension == null ? null : [extension],
      bytes: bytes,
    );
    messenger.hideCurrentSnackBar();
    if (saved != null || kIsWeb) {
      messenger.showSnackBar(SnackBar(content: Text('Saved $fileName')));
    }
  } catch (_) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      const SnackBar(content: Text('The attachment could not be downloaded.')),
    );
  }
}

/// Preview and Download for one attachment, side by side.
class AttachmentActions extends StatelessWidget {
  const AttachmentActions({super.key, required this.url, this.name});

  final String url;
  final String? name;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton.icon(
          key: const ValueKey('attachment-preview-button'),
          onPressed: () => openAttachmentPreview(context, url: url, name: name),
          icon: const Icon(Icons.visibility_outlined, size: 18),
          label: const Text('Preview'),
        ),
        IconButton(
          key: const ValueKey('attachment-download-button'),
          tooltip: 'Download',
          onPressed: () => downloadAttachment(context, url: url, name: name),
          icon: const Icon(Icons.download_rounded, size: 20),
        ),
      ],
    );
  }
}

/// Opens an announcement attachment inside the app: images zoom, PDFs render
/// page by page, and Download saves the file. Nothing leaves the app.
Future<void> openAttachmentPreview(
  BuildContext context, {
  required String url,
  String? name,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => AttachmentViewerScreen(url: url, name: name),
    ),
  );
}

class AttachmentViewerScreen extends StatefulWidget {
  const AttachmentViewerScreen({
    super.key,
    required this.url,
    this.name,
    this.load = _download,
  });

  final String url;
  final String? name;
  final AttachmentLoader load;

  @override
  State<AttachmentViewerScreen> createState() => _AttachmentViewerScreenState();
}

class _AttachmentViewerScreenState extends State<AttachmentViewerScreen> {
  late Future<Uint8List> _bytes = widget.load(widget.url);
  bool _saving = false;

  String get _fileName => attachmentFileName(widget.url, widget.name);

  void _retry() {
    // The builder only listens after the next frame; mark a failure as seen
    // now so it isn't reported as unhandled. The builder still shows it.
    final next = widget.load(widget.url)..ignore();
    setState(() {
      _bytes = next;
    });
  }

  Future<void> _save(Uint8List bytes) async {
    if (_saving) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final name = _fileName;
      final dot = name.lastIndexOf('.');
      final extension = dot > 0 ? name.substring(dot + 1) : null;
      final saved = await FilePicker.saveFile(
        dialogTitle: 'Save attachment',
        fileName: name,
        type: extension == null ? FileType.any : FileType.custom,
        allowedExtensions: extension == null ? null : [extension],
        bytes: bytes,
      );
      // Null is a cancel on phones; the web downloads without an answer.
      if (saved != null || kIsWeb) {
        messenger.showSnackBar(SnackBar(content: Text('Saved $name')));
      }
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('The attachment could not be saved.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _bytes,
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        return Scaffold(
          appBar: AppBar(
            titleSpacing: 0,
            title: Text(
              _fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            actions: [
              IconButton(
                key: const ValueKey('attachment-download'),
                tooltip: 'Download',
                onPressed: bytes == null || _saving ? null : () => _save(bytes),
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_rounded),
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: switch (snapshot.connectionState) {
            ConnectionState.done when snapshot.hasError => _Message(
              icon: Icons.cloud_off_rounded,
              title: 'Couldn\'t load the attachment',
              action: FilledButton(
                onPressed: _retry,
                child: const Text('Try again'),
              ),
            ),
            ConnectionState.done when bytes != null => _Preview(
              bytes: bytes,
              name: _fileName,
              onDownload: () => _save(bytes),
            ),
            _ => const Center(child: CircularProgressIndicator()),
          },
        );
      },
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({
    required this.bytes,
    required this.name,
    required this.onDownload,
  });

  final Uint8List bytes;
  final String name;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    switch (attachmentKindOf(bytes, name)) {
      case AttachmentKind.image:
        return InteractiveViewer(
          key: const ValueKey('attachment-image'),
          maxScale: 5,
          child: Center(
            child: Image.memory(
              bytes,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => _Message(
                icon: Icons.broken_image_outlined,
                title: 'This image can\'t be shown',
                action: FilledButton.icon(
                  onPressed: onDownload,
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Download'),
                ),
              ),
            ),
          ),
        );
      case AttachmentKind.pdf:
        return _PdfPages(bytes: bytes, onDownload: onDownload);
      case AttachmentKind.other:
        return _Message(
          icon: Icons.insert_drive_file_outlined,
          title: 'No preview for this file',
          action: FilledButton.icon(
            onPressed: onDownload,
            icon: const Icon(Icons.download_rounded),
            label: const Text('Download'),
          ),
        );
    }
  }
}

/// Renders every PDF page as an image, in order, as they finish.
class _PdfPages extends StatelessWidget {
  const _PdfPages({required this.bytes, required this.onDownload});

  final Uint8List bytes;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    // The list subscribes once, in its initState, so rebuilding this widget
    // does not render the pages again.
    return _PdfPageList(
      stream: Printing.raster(bytes, dpi: 144),
      onDownload: onDownload,
    );
  }
}

class _PdfPageList extends StatefulWidget {
  const _PdfPageList({required this.stream, required this.onDownload});

  final Stream<PdfRaster> stream;
  final VoidCallback onDownload;

  @override
  State<_PdfPageList> createState() => _PdfPageListState();
}

class _PdfPageListState extends State<_PdfPageList> {
  final _pages = <Uint8List>[];
  bool _done = false;
  bool _failed = false;
  StreamSubscription<Uint8List>? _subscription;

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // asyncMap converts one page at a time, so pages land in order.
    _subscription = widget.stream.asyncMap((page) => page.toPng()).listen(
      (png) {
        if (mounted) setState(() => _pages.add(png));
      },
      onError: (_) {
        if (mounted) setState(() => _failed = true);
      },
      onDone: () {
        if (mounted) setState(() => _done = true);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_failed && _pages.isEmpty) {
      return _Message(
        icon: Icons.picture_as_pdf_outlined,
        title: 'This PDF can\'t be previewed here',
        action: FilledButton.icon(
          onPressed: widget.onDownload,
          icon: const Icon(Icons.download_rounded),
          label: const Text('Download'),
        ),
      );
    }
    if (_pages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return InteractiveViewer(
      key: const ValueKey('attachment-pdf'),
      maxScale: 4,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
        itemCount: _pages.length + (_done ? 0 : 1),
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index >= _pages.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              boxShadow: const [
                BoxShadow(color: Color(0x1F000000), blurRadius: 8),
              ],
            ),
            child: Image.memory(_pages[index], fit: BoxFit.fitWidth),
          );
        },
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.title, this.action});

  final IconData icon;
  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: palette.inkSecondary),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: palette.ink,
              ),
            ),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}
