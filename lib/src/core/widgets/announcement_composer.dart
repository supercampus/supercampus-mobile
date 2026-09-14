import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../media/media_repository.dart';
import '../media/media_scope.dart';
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
    ),
  );
}

class _AnnouncementComposer extends StatefulWidget {
  const _AnnouncementComposer({
    required this.heading,
    required this.submitLabel,
    this.supportingText,
    this.coverImageOnly = false,
  });

  final String heading;
  final String submitLabel;
  final String? supportingText;
  final bool coverImageOnly;

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
    if (selected != null && mounted) setState(() => _date = selected);
  }

  Future<void> _attachFile() async {
    final repository = MediaScope.maybeOf(context);
    if (repository == null || _uploading) return;
    PlatformFile? file;
    try {
      file = await FilePicker.pickFile(
        type: widget.coverImageOnly ? FileType.image : FileType.custom,
        allowedExtensions: widget.coverImageOnly
            ? null
            : const ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
      );
    } catch (_) {
      _show('The file picker is not available on this device.');
      return;
    }
    if (file == null) return;
    setState(() => _uploading = true);
    try {
      var bytes = await file.readAsBytes();
      var uploadName = file.name;
      if (_isImageName(file.name)) {
        if (!mounted) return;
        final cropped = await showAnnouncementImageCropper(context, bytes);
        if (cropped == null) return;
        bytes = cropped;
        uploadName =
            'announcement-cover-${DateTime.now().millisecondsSinceEpoch}.png';
      }
      final asset = await repository.upload(bytes: bytes, fileName: uploadName);
      if (!mounted) return;
      setState(() {
        _attachmentName = uploadName;
        _attachmentUrl = asset.secureUrl;
      });
    } on MediaException catch (error) {
      _show(error.message);
    } catch (_) {
      _show('The attachment could not be uploaded. Try again.');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _show(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _submit() {
    final valid = _formKey.currentState?.validate() == true;
    if (!valid) return;
    if (_date == null) {
      _show('Select the announcement date.');
      return;
    }
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
                  hintText: 'Campus event, exam results, fee reminder…',
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _selectDate,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Select date',
                    suffixIcon: Icon(Icons.calendar_month_outlined),
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
                leading: const Icon(Icons.add_photo_alternate_outlined),
                title: Text(_attachmentName ?? 'Announcement image'),
                subtitle: Text(
                  _attachmentName == null
                      ? widget.coverImageOnly
                            ? 'Add and crop a JPG, PNG or WebP cover (optional)'
                            : 'Add a JPG, PNG, WebP or PDF attachment (optional)'
                      : _attachmentIsImage
                      ? 'Cropped to 16:7 and ready to publish'
                      : 'Attachment uploaded and ready to publish',
                ),
                trailing: _uploading
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        tooltip: 'Attach file',
                        onPressed: mediaAvailable ? _attachFile : null,
                        icon: Icon(
                          _attachmentName == null
                              ? Icons.upload_file_outlined
                              : Icons.check_circle_outline,
                        ),
                      ),
              ),
              if (_attachmentIsImage && _attachmentUrl != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: AspectRatio(
                    aspectRatio: 16 / 7,
                    child: Image.network(
                      _attachmentUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const ColoredBox(
                        color: Color(0xFFF0EDF8),
                        child: Center(child: Icon(Icons.broken_image_outlined)),
                      ),
                    ),
                  ),
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
