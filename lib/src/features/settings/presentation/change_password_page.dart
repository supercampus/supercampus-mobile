import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/account_repository.dart';
import '../data/settings_api.dart';
import 'settings_ui.dart';

/// Matches the server's `MINIMUM_PASSWORD_LENGTH`.
const minimumPasswordLength = 8;

enum PasswordStrength { weak, fair, strong }

/// A gentle hint, not a rule: the server only enforces the minimum length.
PasswordStrength passwordStrength(String value) {
  if (value.length < minimumPasswordLength) return PasswordStrength.weak;
  var classes = 0;
  if (RegExp('[a-z]').hasMatch(value)) classes++;
  if (RegExp('[A-Z]').hasMatch(value)) classes++;
  if (RegExp(r'\d').hasMatch(value)) classes++;
  if (RegExp(r'[^A-Za-z0-9]').hasMatch(value)) classes++;
  if (value.length >= 12 && classes >= 3) return PasswordStrength.strong;
  if (classes >= 2) return PasswordStrength.fair;
  return PasswordStrength.weak;
}

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({
    super.key,
    required this.repository,
    required this.email,
  });

  final AccountRepository repository;

  /// The signed-in email, for "Forgot your current password?".
  final String email;

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  final _nextFocus = FocusNode();
  final _confirmFocus = FocusNode();
  var _showCurrent = false;
  var _showNext = false;
  var _submitted = false;
  var _saving = false;
  var _sendingReset = false;
  String? _serverError;
  String? _resetMessage;
  var _resetFailed = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    _nextFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  String? get _currentError =>
      _submitted && _current.text.isEmpty ? 'Enter your current password.' : null;

  String? get _nextError {
    final value = _next.text;
    if (!_submitted && value.isEmpty) return null;
    if (value.length < minimumPasswordLength) {
      return 'Use at least $minimumPasswordLength characters.';
    }
    if (_current.text.isNotEmpty && value == _current.text) {
      return 'Choose a password different from your current one.';
    }
    return null;
  }

  String? get _confirmError {
    final value = _confirm.text;
    if (!_submitted && value.isEmpty) return null;
    if (value != _next.text) return 'Passwords don’t match.';
    return null;
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _submitted = true;
      _serverError = null;
    });
    if (_currentError != null || _nextError != null || _confirmError != null) {
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.repository.changePassword(
        currentPassword: _current.text,
        newPassword: _next.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your password has been changed.')),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _serverError = error is SettingsApiException
            ? error.message
            : 'Your password could not be changed. Try again.';
      });
    }
  }

  Future<void> _forgot() async {
    setState(() {
      _sendingReset = true;
      _resetMessage = null;
    });
    try {
      await widget.repository.sendPasswordReset(widget.email);
      if (!mounted) return;
      setState(() {
        _sendingReset = false;
        _resetFailed = false;
        _resetMessage =
            'We’ve sent a reset link to ${widget.email}. Open it to choose a '
            'new password.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _sendingReset = false;
        _resetFailed = true;
        _resetMessage = error is SettingsApiException
            ? error.message
            : 'The reset link could not be sent. Try again.';
      });
    }
  }

  void _changed(String _) => setState(() => _serverError = null);

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final strength = passwordStrength(_next.text);
    final (strengthLabel, strengthColor, strengthValue) = switch (strength) {
      PasswordStrength.weak => ('Weak', palette.danger, 0.25),
      PasswordStrength.fair => ('Fair', palette.warning, 0.6),
      PasswordStrength.strong => ('Strong', palette.success, 1.0),
    };

    return SettingsPageScaffold(
      title: 'Change password',
      bottom: SettingsPrimaryButton(
        key: const ValueKey('change-password-submit'),
        label: 'Change password',
        busy: _saving,
        onPressed: _save,
      ),
      children: [
        AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SettingsSection(
                dividerIndent: 16,
                children: [
                  SettingsTextField(
                    fieldKey: const ValueKey('current-password'),
                    controller: _current,
                    label: 'Current password',
                    obscure: !_showCurrent,
                    onToggleObscure: () =>
                        setState(() => _showCurrent = !_showCurrent),
                    autofillHints: const [AutofillHints.password],
                    keyboardType: TextInputType.visiblePassword,
                    autocorrect: false,
                    enableSuggestions: false,
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) => _nextFocus.requestFocus(),
                    onChanged: _changed,
                    errorText: _currentError,
                    enabled: !_saving,
                  ),
                ],
              ),
              SettingsSection(
                dividerIndent: 16,
                footer:
                    'Use at least $minimumPasswordLength characters. A longer '
                    'mix of words, numbers and symbols is harder to guess.',
                children: [
                  SettingsTextField(
                    fieldKey: const ValueKey('new-password'),
                    controller: _next,
                    focusNode: _nextFocus,
                    label: 'New password',
                    obscure: !_showNext,
                    onToggleObscure: () =>
                        setState(() => _showNext = !_showNext),
                    autofillHints: const [AutofillHints.newPassword],
                    keyboardType: TextInputType.visiblePassword,
                    autocorrect: false,
                    enableSuggestions: false,
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) => _confirmFocus.requestFocus(),
                    onChanged: _changed,
                    errorText: _nextError,
                    enabled: !_saving,
                  ),
                  SettingsTextField(
                    fieldKey: const ValueKey('confirm-password'),
                    controller: _confirm,
                    focusNode: _confirmFocus,
                    label: 'Confirm new password',
                    obscure: !_showNext,
                    autofillHints: const [AutofillHints.newPassword],
                    keyboardType: TextInputType.visiblePassword,
                    autocorrect: false,
                    enableSuggestions: false,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _save(),
                    onChanged: _changed,
                    errorText: _confirmError,
                    enabled: !_saving,
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_next.text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 18),
            child: Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: strengthValue,
                      minHeight: 5,
                      color: strengthColor,
                      backgroundColor: palette.surfaceMuted,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Strength: $strengthLabel',
                  style: TextStyle(color: palette.inkSecondary, fontSize: 12.5),
                ),
              ],
            ),
          ),
        if (_serverError != null) ...[
          InlineMessage(
            key: const ValueKey('change-password-error'),
            message: _serverError!,
          ),
          const SizedBox(height: 16),
        ],
        Center(
          child: TextButton(
            onPressed: _sendingReset || _saving ? null : _forgot,
            child: Text(
              _sendingReset
                  ? 'Sending reset link…'
                  : 'Forgot your current password?',
            ),
          ),
        ),
        if (_resetMessage != null)
          InlineMessage(
            message: _resetMessage!,
            tone: _resetFailed
                ? InlineMessageTone.error
                : InlineMessageTone.success,
          ),
      ],
    );
  }
}
