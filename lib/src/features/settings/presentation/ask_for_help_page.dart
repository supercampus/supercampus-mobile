import 'package:flutter/material.dart';

import '../../../core/app_version.dart';
import '../../../core/theme/app_theme.dart';
import '../data/settings_api.dart';
import '../data/support_repository.dart';
import 'settings_ui.dart';

/// Send a help request to the office that handles the chosen topic. Pops
/// with the created [SupportTicket] after the user closes the success state.
class AskForHelpPage extends StatefulWidget {
  const AskForHelpPage({
    super.key,
    required this.repository,
    this.initialCategory,
  });

  final SupportRepository repository;
  final String? initialCategory;

  @override
  State<AskForHelpPage> createState() => _AskForHelpPageState();
}

class _AskForHelpPageState extends State<AskForHelpPage> {
  static const _subjectMin = 3;
  static const _subjectMax = 120;
  static const _messageMin = 10;
  static const _messageMax = 2000;

  List<SupportCategory>? _categories;
  late String? _category = widget.initialCategory;
  final _subject = TextEditingController();
  final _message = TextEditingController();
  String? _subjectError;
  String? _messageError;
  String? _topicError;
  String? _error;
  var _submitting = false;
  SupportTicket? _sent;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    List<SupportCategory> categories;
    try {
      categories = await widget.repository.categories();
    } catch (_) {
      // The contract's routing table is a faithful stand-in; the server
      // still decides the real recipient when the request is sent.
      categories = fallbackSupportCategories;
    }
    if (!mounted) return;
    setState(() {
      _categories = categories;
      if (_category != null && !categories.any((c) => c.key == _category)) {
        _category = null;
      }
    });
  }

  SupportCategory? get _selected {
    final key = _category;
    if (key == null) return null;
    for (final category in _categories ?? const <SupportCategory>[]) {
      if (category.key == key) return category;
    }
    return null;
  }

  bool _validate() {
    final subject = _subject.text.trim();
    final message = _message.text.trim();
    setState(() {
      _topicError = _category == null ? 'Choose a topic.' : null;
      _subjectError = subject.length < _subjectMin
          ? 'Add a short subject (at least $_subjectMin characters).'
          : subject.length > _subjectMax
          ? 'Keep the subject under $_subjectMax characters.'
          : null;
      _messageError = message.length < _messageMin
          ? 'Tell us a little more (at least $_messageMin characters).'
          : message.length > _messageMax
          ? 'Keep the message under $_messageMax characters.'
          : null;
    });
    return _topicError == null && _subjectError == null && _messageError == null;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (_submitting || !_validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final ticket = await widget.repository.createTicket(
        category: _category!,
        subject: _subject.text.trim(),
        message: _message.text.trim(),
        context: const {
          'source': 'app',
          'appVersion': '$appVersionName+$appBuildNumber',
        },
      );
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _sent = ticket;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = error is SettingsApiException
            ? error.message
            : 'Your request could not be sent. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sent = _sent;
    if (sent != null) return _buildSent(context, sent);
    final palette = context.palette;
    final categories = _categories;
    final selected = _selected;

    return SettingsPageScaffold(
      title: 'Ask for help',
      bottom: SettingsPrimaryButton(
        key: const ValueKey('help-submit'),
        label: 'Send request',
        busy: _submitting,
        onPressed: categories == null ? null : _submit,
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 18),
          child: Text(
            'Your request goes straight to the office that handles it. '
            'You’ll get an alert when they reply.',
            style: TextStyle(color: palette.inkSecondary, fontSize: 14),
          ),
        ),
        if (categories == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          if (_topicError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InlineMessage(message: _topicError!),
            ),
          SettingsSection(
            header: 'Topic',
            dividerIndent: 16,
            children: [
              for (final category in categories)
                SettingsRow(
                  key: ValueKey('help-topic-${category.key}'),
                  title: category.label,
                  showChevron: false,
                  trailing: category.key == _category
                      ? Icon(Icons.check_rounded, color: palette.brandInk)
                      : const SizedBox(width: 24),
                  onTap: _submitting
                      ? null
                      : () => setState(() {
                          _category = category.key;
                          _topicError = null;
                        }),
                ),
            ],
          ),
        ],
        if (selected != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 18),
            child: Row(
              children: [
                Icon(Icons.send_rounded, size: 16, color: palette.brandInk),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Goes to: ${selected.handledBy}',
                    key: const ValueKey('help-goes-to'),
                    style: TextStyle(
                      color: palette.ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        SettingsSection(
          header: 'Your request',
          dividerIndent: 16,
          children: [
            SettingsTextField(
              fieldKey: const ValueKey('help-subject'),
              controller: _subject,
              label: 'Subject',
              hint: 'e.g. Receipt missing for my May payment',
              enabled: !_submitting,
              maxLength: _subjectMax,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              errorText: _subjectError,
              onChanged: (_) {
                if (_subjectError != null) setState(() => _subjectError = null);
              },
            ),
            SettingsTextField(
              fieldKey: const ValueKey('help-message'),
              controller: _message,
              label: 'Message',
              hint: 'What happened, and what do you need?',
              enabled: !_submitting,
              maxLength: _messageMax,
              minLines: 4,
              maxLines: 8,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              errorText: _messageError,
              onChanged: (_) {
                if (_messageError != null) setState(() => _messageError = null);
              },
            ),
          ],
        ),
        if (_error != null) InlineMessage(message: _error!),
      ],
    );
  }

  Widget _buildSent(BuildContext context, SupportTicket ticket) {
    final palette = context.palette;
    final handledBy = ticket.handledBy ?? _selected?.handledBy;
    return SettingsPageScaffold(
      title: 'Ask for help',
      bottom: SettingsPrimaryButton(
        label: 'Done',
        onPressed: () => Navigator.of(context).pop(ticket),
      ),
      children: [
        const SizedBox(height: 40),
        Icon(Icons.check_circle_rounded, size: 56, color: palette.success),
        const SizedBox(height: 14),
        Text(
          'Request sent',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: palette.ink,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          [
            if (handledBy != null) 'It has gone to $handledBy.',
            'You’ll get an alert when it’s updated, and you can follow it '
                'under My requests.',
          ].join(' '),
          textAlign: TextAlign.center,
          style: TextStyle(color: palette.inkSecondary, fontSize: 15, height: 1.4),
        ),
      ],
    );
  }
}
