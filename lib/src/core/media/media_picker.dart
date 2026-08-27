import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'media_repository.dart';

/// Picks one image and uploads it, returning the stored asset.
///
/// The whole exchange lives here so every screen that attaches a photo shares
/// one behaviour: the same picker, the same size limit, the same failure
/// message. Returns null when the person backs out, which is not an error and
/// is not reported as one.
Future<MediaAsset?> pickAndUploadPhoto(
  BuildContext context, {
  required MediaRepository repository,
}) async {
  final PlatformFile? file;
  try {
    file = await FilePicker.pickFile(type: FileType.image);
  } on Exception {
    if (context.mounted) {
      _report(context, 'The photo library is not available on this device.');
    }
    return null;
  }
  if (file == null) return null;

  try {
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      if (context.mounted) _report(context, 'That file could not be read.');
      return null;
    }
    return await repository.upload(bytes: bytes, fileName: file.name);
  } on MediaException catch (error) {
    if (context.mounted) _report(context, error.message);
    return null;
  } catch (_) {
    if (context.mounted) {
      _report(context, 'The upload could not be completed. Try again.');
    }
    return null;
  }
}

void _report(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(
    context,
  )?.showSnackBar(SnackBar(content: Text(message)));
}

/// A photo well: the current image, or a prompt to add one.
///
/// It owns the upload, so a caller only has to say where to put the asset it
/// comes back with.
class PhotoField extends StatefulWidget {
  const PhotoField({
    super.key,
    required this.repository,
    required this.imageUrl,
    required this.onUploaded,
    this.label = 'Add photo',
    this.size = 96,
    this.circular = false,
  });

  final MediaRepository repository;
  final String? imageUrl;
  final ValueChanged<MediaAsset> onUploaded;
  final String label;
  final double size;
  final bool circular;

  @override
  State<PhotoField> createState() => _PhotoFieldState();
}

class _PhotoFieldState extends State<PhotoField> {
  bool _busy = false;

  Future<void> _pick() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final asset = await pickAndUploadPhoto(
        context,
        repository: widget.repository,
      );
      if (asset != null) widget.onUploaded(asset);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(widget.circular ? widget.size : 16);
    final url = widget.imageUrl;
    final hasImage = url != null && url.isNotEmpty;

    return Semantics(
      button: true,
      label: widget.label,
      child: InkWell(
        onTap: _busy ? null : _pick,
        borderRadius: radius,
        child: Ink(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: radius,
            border: Border.all(color: scheme.outlineVariant),
            image: hasImage
                ? DecorationImage(image: NetworkImage(url), fit: BoxFit.cover)
                : null,
          ),
          child: _busy
              ? const Center(
                  child: SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : hasImage
              ? null
              : Center(
                  child: Icon(
                    Icons.add_a_photo_outlined,
                    size: widget.size * 0.3,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
        ),
      ),
    );
  }
}
