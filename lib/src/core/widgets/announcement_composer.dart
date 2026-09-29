import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../media/media_repository.dart';
import '../media/media_scope.dart';
import '../media/picker_web_options.dart';
import '../theme/app_theme.dart';
import 'announcement_image_cropper.dart';

class AnnouncementDraft {
  const AnnouncementDraft({
    required this.type,
    required this.date,
    required this.title,
    required this.description,
    this.attachmentName,
    this.attachmentUrl,
  });

  final String type;
  final DateTime date;
  final String title;
  final String description;
  final String? attachmentName;
  final String? attachmentUrl;
}

Future<AnnouncementDraft?> showAnnouncementComposer(
  BuildContext context, {
  String heading = 'Create announcement',
  String submitLabel = 'Save announcement',
  String? supportingText,
  bool coverImageOnly = false,
  AnnouncementDraft? initial,
}) {
  return showModalBottomSheet<AnnouncementDraft>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _AnnouncementComposer(
      heading: heading,
      submitLabel: submitLabel,
      supportingText: supportingText,
      coverImageOnly: coverImageOnly,
      initial: initial,
    ),
  );
}

class _AnnouncementComposer extends StatefulWidget {
  const _AnnouncementComposer({
    required this.heading,
    required this.submitLabel,
    this.supportingText,
    this.coverImageOnly = false,
    this.initial,
  });

  final String heading;
  final String submitLabel;
  final String? supportingText;
  final bool coverImageOnly;

  /// Prefills the form when editing an existing announcement.
  final AnnouncementDraft? initial;

  @override
  State<_AnnouncementComposer> createState() => _AnnouncementComposerState();
}

class _AnnouncementComposerState extends State<_AnnouncementComposer> {
  final _formKey = GlobalKey<FormState>();
  final _type = TextEditingController();
  final _title = TextEditingController();
  final _description = TextEditingController();
  DateTime? _date;
  String? _attachmentName;
  String? _attachmentUrl;
  bool _uploading = false;

  /// Why the last attachment attempt failed, shown inside the sheet.
  ///
  /// Not a SnackBar: the root messenger paints under this modal sheet, so a
  /// snackbar here is invisible and the failure looks like nothing happened.
  String? _attachmentError;
  String? _dateError;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null) {
      _type.text = initial.type;
      _title.text = initial.title;
      _description.text = initial.description;
      _date = initial.date;
      _attachmentName = initial.attachmentName;
      _attachmentUrl = initial.attachmentUrl;
    }
  }

  @override
  void dispose() {
    _type.dispose();
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      initialDate: _date ?? now,
    );
    if (selected != null && mounted) {
      setState(() {
        _date = selected;
        _dateError = null;
      });
    }
  }

  Future<void> _attachFile() async {
    final repository = MediaScope.maybeOf(context);
    if (repository == null || _uploading) return;
    setState(() => _attachmentError = null);
    PlatformFile? file;
    try {
      file = await FilePicker.pickFile(
        type: widget.coverImageOnly ? FileType.image : FileType.custom,
        allowedExtensions: widget.coverImageOnly
            ? null
            : const ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
        webOptions: reliableWebPickerOptions,
      );
    } catch (_) {
      _fail('The file picker is not available on this device.');
      return;
    }
    if (file == null) return;
    setState(() => _uploading = true);
    try {
      // Bytes, never `path`: on the web a picked file has no path at all.
      var bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        _fail('That file could not be read. Choose it again.');
        return;
      }
      if (bytes.length > MediaRepository.maxBytes) {
        _fail('Images and PDFs must not exceed 10 MB.');
        return;
      }
      var uploadName = file.name.trim().isEmpty ? 'attachment' : file.name;
      final isPdf = _looksLikePdf(bytes);
      if (!isPdf && (_isImageName(uploadName) || _looksLikeImage(bytes))) {
        if (!mounted) return;
        Uint8List? cropped;
        var decoded = true;
        try {
          cropped = await showAnnouncementImageCropper(context, bytes);
        } catch (_) {
          // An image the engine cannot decode (a HEIC saved as .jpg, say)
          // is still worth publishing: upload it as it is and let the API
          // decide from its content.
          decoded = false;
        }
        if (decoded) {
          if (cropped == null) return;
          bytes = cropped;
          uploadName =
              'announcement-cover-${DateTime.now().millisecondsSinceEpoch}.png';
        }
      } else if (!isPdf) {
        _fail('Choose a PDF, JPG, PNG or WebP file.');
        return;
      }
      final asset = await repository.upload(bytes: bytes, fileName: uploadName);
      if (!mounted) return;
      if (asset.secureUrl.trim().isEmpty) {
        _fail('The upload did not return a file link. Try again.');
        return;
      }
      setState(() {
        _attachmentName = uploadName;
        _attachmentUrl = asset.secureUrl;
        _attachmentError = null;
      });
    } on MediaException catch (error) {
      _fail(error.message);
    } catch (_) {
      _fail('The attachment could not be uploaded. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() => _attachmentError = message);
  }

  static bool _looksLikePdf(List<int> bytes) =>
      bytes.length >= 5 &&
      bytes[0] == 0x25 && // %
      bytes[1] == 0x50 && // P
      bytes[2] == 0x44 && // D
      bytes[3] == 0x46 && // F
      bytes[4] == 0x2D; // -

  static bool _looksLikeImage(List<int> bytes) {
    bool starts(List<int> signature) =>
        bytes.length >= signature.length &&
        List.generate(signature.length, (i) => bytes[i] == signature[i])
            .every((matches) => matches);
    return starts(const [0xFF, 0xD8, 0xFF]) ||
        starts(const [0x89, 0x50, 0x4E, 0x47]) ||
        starts(const [0x47, 0x49, 0x46, 0x38]) ||
        (bytes.length >= 12 &&
            starts(const [0x52, 0x49, 0x46, 0x46]) &&
            bytes[8] == 0x57 &&
            bytes[9] == 0x45 &&
            bytes[10] == 0x42 &&
            bytes[11] == 0x50);
  }

  void _submit() {
    final valid = _formKey.currentState?.validate() == true;
    if (_date == null) {
      setState(() => _dateError = 'Select the announcement date.');
    }
    if (!valid || _date == null) return;
    if (_uploading) return;
    Navigator.pop(
      context,
      AnnouncementDraft(
        type: _type.text.trim(),
        date: _date!,
        title: _title.text.trim(),
        description: _description.text.trim(),
        attachmentName: _attachmentName,
        attachmentUrl: _attachmentUrl,
      ),
    );
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'This field is required.' : null;

  bool get _attachmentIsImage {
    return isAnnouncementImageAttachment(_attachmentName, _attachmentUrl);
  }

  bool get _attachmentIsPdf {
    final name = (_attachmentName ?? '').toLowerCase();
    final url = (_attachmentUrl ?? '').toLowerCase();
    return name.endsWith('.pdf') || url.contains('.pdf');
  }

  bool _isImageName(String name) => const [
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
    '.gif',
  ].any(name.toLowerCase().endsWith);

  @override
  Widget build(BuildContext context) {
    final mediaAvailable = MediaScope.maybeOf(context) != null;
    final isCircular = _type.text.toLowerCase().contains('circular');
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.heading,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              if (widget.supportingText != null) ...[
                const SizedBox(height: 6),
                Text(widget.supportingText!),
              ],
              const SizedBox(height: 18),
              TextFormField(
                controller: _type,
                validator: _required,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Announcement type',
                  hintText: 'Circular, Announcement, Examination, Event…',
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  'Circular',
                  'Announcement',
                  'Examination',
                  'Event',
                  'Academics',
                  'Administrative',
                ].map((tag) {
                  final isSelected =
                      _type.text.toLowerCase() == tag.toLowerCase();
                  return ActionChip(
                    label: Text(
                      tag,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected
                            ? context.palette.onBrand
                            : context.palette.brandInk,
                      ),
                    ),
                    backgroundColor: isSelected
                        ? context.palette.brand
                        : context.palette.brandInk.withValues(alpha: 0.08),
                    onPressed: () {
                      setState(() => _type.text = tag);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _selectDate,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Select date',
                    suffixIcon: const Icon(Icons.calendar_month_outlined),
                    errorText: _dateError,
                  ),
                  child: Text(
                    _date == null
                        ? 'Choose announcement date'
                        : DateFormat('dd MMM yyyy').format(_date!),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _title,
                validator: _required,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _description,
                validator: _required,
                minLines: 3,
                maxLines: 6,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  _attachmentIsPdf
                      ? Icons.picture_as_pdf_outlined
                      : _attachmentIsImage
                      ? Icons.image_outlined
                      : isCircular
                      ? Icons.picture_as_pdf_outlined
                      : Icons.attach_file_rounded,
                  color: _attachmentIsPdf
                      ? context.palette.danger
                      : null,
                ),
                title: Text(
                  _attachmentName ??
                      (isCircular
                          ? 'Circular document (PDF)'
                          : widget.coverImageOnly
                          ? 'Announcement cover image'
                          : 'Attachment (PDF / Image)'),
                ),
                subtitle: Text(
                  _attachmentName == null
                      ? widget.coverImageOnly
                            ? 'Add and crop a JPG, PNG or WebP cover (optional)'
                            : isCircular
                            ? 'Upload a circular PDF or cover image (optional)'
                            : 'Add a JPG, PNG, WebP or PDF attachment (optional)'
                      : _attachmentIsPdf
                      ? 'Official PDF circular attached and ready'
                      : _attachmentIsImage
                      ? 'Cropped to 16:7 and ready to publish'
                      : 'Attachment uploaded and ready to publish',
                ),
                trailing: _uploading
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_attachmentName != null)
                            IconButton(
                              tooltip: 'Remove attachment',
                              icon: const Icon(Icons.close, size: 20),
                              onPressed: () => setState(() {
                                _attachmentName = null;
                                _attachmentUrl = null;
                              }),
                            ),
                          IconButton(
                            tooltip: _attachmentName == null
                                ? (isCircular ? 'Upload circular PDF' : 'Attach file')
                                : 'Change attachment',
                            onPressed: mediaAvailable ? _attachFile : null,
                            icon: Icon(
                              _attachmentName == null
                                  ? (isCircular
                                      ? Icons.upload_file_outlined
                                      : Icons.upload_file_outlined)
                                  : Icons.edit_outlined,
                            ),
                          ),
                        ],
                      ),
              ),
              if (_uploading)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Uploading attachment…',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              if (_attachmentError != null && !_uploading)
                Container(
                  key: const ValueKey('announcement-attachment-error'),
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: context.palette.danger.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        size: 18,
                        color: context.palette.danger,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            'Attachment not added. $_attachmentError',
                            style: TextStyle(
                              fontSize: 13,
                              color: context.palette.danger,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_attachmentIsPdf && _attachmentUrl != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: context.palette.danger.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: context.palette.danger.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: context.palette.danger.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.picture_as_pdf_rounded,
                          color: context.palette.danger,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _attachmentName ?? 'Circular document.pdf',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Official PDF circular ready to publish',
                              style: TextStyle(
                                fontSize: 11,
                                color: context.adaptive(
                                  light: const Color(0xFFB91C1C),
                                  dark: const Color(0xFFFCA5A5),
                                ),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Remove PDF',
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => setState(() {
                          _attachmentName = null;
                          _attachmentUrl = null;
                        }),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (_attachmentIsImage && _attachmentUrl != null) ...[
                Stack(
                  alignment: Alignment.topRight,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: AspectRatio(
                        aspectRatio: 16 / 7,
                        child: Image.network(
                          _attachmentUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => ColoredBox(
                            color: context.adaptive(
                              light: const Color(0xFFF0EDF8),
                              dark: const Color(0xFF1C1D23),
                            ),
                            child: const Center(
                              child: Icon(Icons.broken_image_outlined),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: CircleAvatar(
                        radius: 14,
                        backgroundColor: Colors.black54,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          iconSize: 16,
                          color: Colors.white,
                          tooltip: 'Remove image',
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() {
                            _attachmentName = null;
                            _attachmentUrl = null;
                          }),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _uploading ? null : _submit,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(widget.submitLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
