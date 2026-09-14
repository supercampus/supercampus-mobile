import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

const double announcementCoverAspectRatio = 16 / 7;

class AnnouncementCropSettings {
  const AnnouncementCropSettings({
    this.focusX = 0,
    this.focusY = 0,
    this.zoom = 1,
  });

  final double focusX;
  final double focusY;
  final double zoom;
}

Rect announcementCoverSourceRect({
  required Size sourceSize,
  required AnnouncementCropSettings settings,
}) {
  final sourceRatio = sourceSize.width / sourceSize.height;
  final zoom = settings.zoom.clamp(1.0, 3.0);
  late double baseWidth;
  late double baseHeight;

  if (sourceRatio > announcementCoverAspectRatio) {
    baseHeight = sourceSize.height;
    baseWidth = baseHeight * announcementCoverAspectRatio;
  } else {
    baseWidth = sourceSize.width;
    baseHeight = baseWidth / announcementCoverAspectRatio;
  }

  final cropWidth = baseWidth / zoom;
  final cropHeight = baseHeight / zoom;
  final availableX = sourceSize.width - cropWidth;
  final availableY = sourceSize.height - cropHeight;
  final normalizedX = (settings.focusX.clamp(-1.0, 1.0) + 1) / 2;
  final normalizedY = (settings.focusY.clamp(-1.0, 1.0) + 1) / 2;

  return Rect.fromLTWH(
    availableX * normalizedX,
    availableY * normalizedY,
    cropWidth,
    cropHeight,
  );
}

Future<Uint8List?> showAnnouncementImageCropper(
  BuildContext context,
  Uint8List originalBytes,
) async {
  final codec = await ui.instantiateImageCodec(originalBytes);
  final frame = await codec.getNextFrame();
  codec.dispose();
  final image = frame.image;

  try {
    if (!context.mounted) return null;
    final settings = await showDialog<AnnouncementCropSettings>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AnnouncementCropDialog(image: image),
    );
    if (settings == null) return null;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const outputSize = Size(1280, 560);
    canvas.drawImageRect(
      image,
      announcementCoverSourceRect(
        sourceSize: Size(image.width.toDouble(), image.height.toDouble()),
        settings: settings,
      ),
      Offset.zero & outputSize,
      Paint()..filterQuality = FilterQuality.high,
    );
    final picture = recorder.endRecording();
    final output = await picture.toImage(
      outputSize.width.toInt(),
      outputSize.height.toInt(),
    );
    picture.dispose();
    final data = await output.toByteData(format: ui.ImageByteFormat.png);
    output.dispose();
    return data?.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}

class _AnnouncementCropDialog extends StatefulWidget {
  const _AnnouncementCropDialog({required this.image});

  final ui.Image image;

  @override
  State<_AnnouncementCropDialog> createState() =>
      _AnnouncementCropDialogState();
}

class _AnnouncementCropDialogState extends State<_AnnouncementCropDialog> {
  double _focusX = 0;
  double _focusY = 0;
  double _zoom = 1;

  AnnouncementCropSettings get _settings => AnnouncementCropSettings(
    focusX: _focusX,
    focusY: _focusY,
    zoom: _zoom,
  );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Crop announcement image'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Drag to choose the visible area. The published card will use exactly this crop.',
            ),
            const SizedBox(height: 14),
            AspectRatio(
              aspectRatio: announcementCoverAspectRatio,
              child: LayoutBuilder(
                builder: (context, constraints) => GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanUpdate: (details) {
                    setState(() {
                      _focusX = (_focusX -
                              (details.delta.dx / constraints.maxWidth) * 2)
                          .clamp(-1.0, 1.0);
                      _focusY = (_focusY -
                              (details.delta.dy / constraints.maxHeight) * 2)
                          .clamp(-1.0, 1.0);
                    });
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: CustomPaint(
                      painter: _AnnouncementCropPainter(
                        image: widget.image,
                        settings: _settings,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.zoom_out_rounded),
                Expanded(
                  child: Slider(
                    value: _zoom,
                    min: 1,
                    max: 3,
                    divisions: 20,
                    label: '${_zoom.toStringAsFixed(1)}×',
                    onChanged: (value) => setState(() => _zoom = value),
                  ),
                ),
                const Icon(Icons.zoom_in_rounded),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(context, _settings),
          icon: const Icon(Icons.crop_rounded),
          label: const Text('Use this crop'),
        ),
      ],
    );
  }
}

class _AnnouncementCropPainter extends CustomPainter {
  const _AnnouncementCropPainter({
    required this.image,
    required this.settings,
  });

  final ui.Image image;
  final AnnouncementCropSettings settings;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImageRect(
      image,
      announcementCoverSourceRect(
        sourceSize: Size(image.width.toDouble(), image.height.toDouble()),
        settings: settings,
      ),
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.high,
    );
  }

  @override
  bool shouldRepaint(_AnnouncementCropPainter oldDelegate) =>
      oldDelegate.image != image ||
      oldDelegate.settings.focusX != settings.focusX ||
      oldDelegate.settings.focusY != settings.focusY ||
      oldDelegate.settings.zoom != settings.zoom;
}

bool isAnnouncementImageAttachment(String? name, String? url) {
  if (url == null || url.trim().isEmpty) return false;
  final value = '${name ?? ''} ${Uri.tryParse(url)?.path ?? url}'.toLowerCase();
  if (const ['.jpg', '.jpeg', '.png', '.webp', '.gif'].any(value.contains)) {
    return true;
  }
  if (const ['.pdf', '.doc', '.docx'].any(value.contains)) return false;
  return value.contains('/image/upload/');
}
