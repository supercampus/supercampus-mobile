import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../data/canteen_repository.dart';
import '../data/wallet_pin_repository.dart';

/// Computes SHA-256 hex of a 4-digit PIN string.
String pinSha256(String pin) =>
    sha256.convert(utf8.encode(pin)).toString();

// ─────────────────────────────────────────────────────────────────────────────
// Verify mode — shown when the user has a PIN and wants to pay
// ─────────────────────────────────────────────────────────────────────────────

class TransactionPinSheet extends StatefulWidget {
  const TransactionPinSheet({
    super.key,
    required this.amount,
    required this.summary,
  });

  final double amount;
  final String summary;

  @override
  State<TransactionPinSheet> createState() => _TransactionPinSheetState();
}

class _TransactionPinSheetState extends State<TransactionPinSheet> {
  var _pin = '';
  String? _error;

  Future<void> _enterDigit(String digit) async {
    if (_pin.length >= 4) return;
    setState(() {
      _pin += digit;
      _error = null;
    });
    if (_pin.length == 4) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      if (mounted) Navigator.of(context).pop(pinSha256(_pin));
    }
  }

  void _deleteDigit() {
    if (_pin.isEmpty) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _PinScaffold(
      title: 'Enter transaction PIN',
      subtitle: widget.summary,
      amountLabel: formatCurrency(widget.amount),
      pin: _pin,
      error: _error,
      onEnterDigit: _enterDigit,
      onDelete: _deleteDigit,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Setup mode — first time PIN creation
// Returns the SHA-256 hash of the confirmed PIN (String) or null if cancelled.
// ─────────────────────────────────────────────────────────────────────────────

class SetupPinSheet extends StatefulWidget {
  const SetupPinSheet({super.key});

  @override
  State<SetupPinSheet> createState() => _SetupPinSheetState();
}

class _SetupPinSheetState extends State<SetupPinSheet> {
  var _pin = '';
  var _confirmPin = '';
  String? _firstPin; // saved when confirming
  var _isConfirming = false;
  String? _error;
  final _hintController = TextEditingController();

  @override
  void dispose() {
    _hintController.dispose();
    super.dispose();
  }

  Future<void> _enterDigit(String digit) async {
    if (_isConfirming) {
      if (_confirmPin.length >= 4) return;
      setState(() {
        _confirmPin += digit;
        _error = null;
      });
      if (_confirmPin.length == 4) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        if (!mounted) return;
        if (_confirmPin == _firstPin) {
          // PINs match — pop with hash + hint
          Navigator.of(context).pop(
            _PinSetupResult(
              pinHash: pinSha256(_confirmPin),
              hint: _hintController.text.trim().isEmpty
                  ? null
                  : _hintController.text.trim(),
            ),
          );
        } else {
          setState(() {
            _confirmPin = '';
            _error = 'PINs do not match. Try again.';
          });
        }
      }
    } else {
      if (_pin.length >= 4) return;
      setState(() {
        _pin += digit;
        _error = null;
      });
      if (_pin.length == 4) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        if (!mounted) return;
        setState(() {
          _firstPin = _pin;
          _isConfirming = true;
          _pin = '';
        });
      }
    }
  }

  void _deleteDigit() {
    if (_isConfirming) {
      if (_confirmPin.isEmpty) return;
      setState(() {
        _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
        _error = null;
      });
    } else {
      if (_pin.isEmpty) return;
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
        _error = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentPin = _isConfirming ? _confirmPin : _pin;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dragHandle(context),
            const SizedBox(height: 20),
            Icon(Icons.lock_outline, color: context.palette.brandInk, size: 32),
            const SizedBox(height: 12),
            Text(
              _isConfirming ? 'Confirm your PIN' : 'Create your PIN',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              _isConfirming
                  ? 'Re-enter the same 4-digit PIN'
                  : 'Choose a 4-digit PIN for wallet payments',
              style: TextStyle(color: context.palette.inkSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            // Recovery word (sent as the backend's `hint`). It is a secret
            // answer that can later replace the PIN when changing it, so it
            // gets no suggestions, autocorrect or example text.
            if (!_isConfirming) ...[
              TextField(
                controller: _hintController,
                autocorrect: false,
                enableSuggestions: false,
                textCapitalization: TextCapitalization.none,
                keyboardType: TextInputType.text,
                decoration: const InputDecoration(
                  labelText: 'Recovery word (optional)',
                  helperText: 'A secret word to help you change your PIN later',
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                maxLength: 30,
                buildCounter: (_, {required currentLength, required isFocused, maxLength}) =>
                    null,
              ),
              const SizedBox(height: 16),
            ],
            _PinDots(filledCount: currentPin.length),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: context.adaptive(light: Colors.red, dark: const Color(0xFFF87171)), fontSize: 13),
              ),
            ],
            const SizedBox(height: 14),
            _Numpad(onDigit: _enterDigit, onDelete: _deleteDigit),
          ],
        ),
      ),
    );
  }
}

class _PinSetupResult {
  const _PinSetupResult({required this.pinHash, this.hint});
  final String pinHash;
  final String? hint;
}

// ─────────────────────────────────────────────────────────────────────────────
// Transaction PIN manager — set a first PIN, or change it. Everything is
// submitted from inside the sheet, so a server refusal ("That PIN is
// incorrect.") shows inline and the user can retry without starting over.
// ─────────────────────────────────────────────────────────────────────────────

enum _PinFlowStep {
  loading,
  loadFailed,
  intro,
  method,
  verify,
  newPin,
  confirmPin,
  review,
  done,
}

enum _RecoveryChoice { keep, set, remove }

class WalletPinSheet extends StatefulWidget {
  const WalletPinSheet({super.key, required this.repository});

  final WalletPinRepository repository;

  @override
  State<WalletPinSheet> createState() => _WalletPinSheetState();
}

class _WalletPinSheetState extends State<WalletPinSheet> {
  _PinFlowStep _step = _PinFlowStep.loading;
  WalletPinStatus? _status;
  WalletPinVerification? _method;

  /// Digits typed on the pad for the current step.
  String _entry = '';
  String? _verifyPinHash;
  String? _firstNewPin;
  String? _newPinHash;
  final _verifyText = TextEditingController();
  final _recoveryText = TextEditingController();
  var _obscureVerify = true;
  var _recoveryChoice = _RecoveryChoice.keep;
  var _submitting = false;
  var _conflict = false;
  String? _error;
  String? _recoveryError;
  String _doneMessage = '';

  bool get _isSetup => !(_status?.hasPin ?? false);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _verifyText.dispose();
    _recoveryText.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _step = _PinFlowStep.loading;
      _error = null;
    });
    try {
      final status = await widget.repository.loadPinStatus();
      if (!mounted) return;
      _resetFlow();
      setState(() {
        _status = status;
        _conflict = false;
        _recoveryChoice = status.hasPin
            ? _RecoveryChoice.keep
            : _RecoveryChoice.set;
        _step = status.hasPin ? _PinFlowStep.method : _PinFlowStep.intro;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is CanteenException
            ? error.message
            : 'Your PIN settings could not be loaded.';
        _step = _PinFlowStep.loadFailed;
      });
    }
  }

  void _resetFlow() {
    _method = null;
    _entry = '';
    _verifyPinHash = null;
    _firstNewPin = null;
    _newPinHash = null;
    _verifyText.clear();
    _recoveryText.clear();
    _recoveryError = null;
  }

  void _chooseMethod(WalletPinVerification method) {
    setState(() {
      _method = method;
      _entry = '';
      _verifyText.clear();
      _error = null;
      _step = _PinFlowStep.verify;
    });
  }

  void _back() {
    setState(() {
      _error = null;
      _entry = '';
      switch (_step) {
        case _PinFlowStep.verify:
          _verifyPinHash = null;
          _verifyText.clear();
          _step = _PinFlowStep.method;
        case _PinFlowStep.newPin:
          _firstNewPin = null;
          _step = _isSetup ? _PinFlowStep.intro : _PinFlowStep.verify;
          if (!_isSetup) {
            _verifyPinHash = null;
            _verifyText.clear();
          }
        case _PinFlowStep.confirmPin:
        case _PinFlowStep.review:
          _firstNewPin = null;
          _newPinHash = null;
          _step = _PinFlowStep.newPin;
        default:
          break;
      }
    });
  }

  Future<void> _digit(String digit) async {
    if (_submitting || _entry.length >= 4) return;
    setState(() {
      _entry += digit;
      _error = null;
    });
    if (_entry.length < 4) return;
    // Let the fourth dot fill before the step changes.
    await Future<void>.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;
    final value = _entry;
    if (_step == _PinFlowStep.verify) {
      await _checkProof(currentPinHash: pinSha256(value));
      return;
    }
    setState(() {
      _entry = '';
      switch (_step) {
        case _PinFlowStep.newPin:
          _firstNewPin = value;
          _step = _PinFlowStep.confirmPin;
        case _PinFlowStep.confirmPin:
          if (value != _firstNewPin) {
            // Start both new-PIN steps again rather than guessing which
            // entry was wrong.
            _firstNewPin = null;
            _error = "Those PINs didn't match. Enter your new PIN again.";
            _step = _PinFlowStep.newPin;
          } else {
            _firstNewPin = null;
            _newPinHash = pinSha256(value);
            _step = _PinFlowStep.review;
          }
        default:
          break;
      }
    });
  }

  void _deleteDigit() {
    if (_entry.isEmpty) return;
    setState(() {
      _entry = _entry.substring(0, _entry.length - 1);
      _error = null;
    });
  }

  void _continueTextVerify() {
    final value = _method == WalletPinVerification.password
        ? _verifyText.text
        : _verifyText.text.trim();
    if (value.isEmpty) {
      setState(
        () => _error = _method == WalletPinVerification.password
            ? 'Enter your account password.'
            : 'Enter your recovery word.',
      );
      return;
    }
    _checkProof(
      hint: _method == WalletPinVerification.recoveryWord ? value : null,
      password: _method == WalletPinVerification.password ? value : null,
    );
  }

  /// Asks the server whether the current PIN, recovery word or password is
  /// right before moving on, so a wrong one is caught on this step. The change
  /// itself checks it again.
  Future<void> _checkProof({
    String? currentPinHash,
    String? hint,
    String? password,
  }) async {
    final method = _method;
    if (method == null || _submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.repository.verifyWalletOwner(
        method: method,
        currentPinHash: currentPinHash,
        hint: hint,
        password: password,
      );
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _entry = '';
        _verifyPinHash = currentPinHash;
        _afterVerified();
      });
    } on CanteenException catch (error) {
      if (!mounted) return;
      final noRecoveryWord =
          error.message.toLowerCase().contains('no recovery word');
      setState(() {
        _submitting = false;
        _entry = '';
        _error = error.message;
        _verifyPinHash = null;
        if (method != WalletPinVerification.password) _verifyText.clear();
        if (noRecoveryWord) {
          _status = WalletPinStatus(hasPin: true, hasPinHint: false);
          _step = _PinFlowStep.method;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _entry = '';
        _error = 'Something went wrong. Check your connection and try again.';
      });
    }
  }

  /// When the user is re-verifying after a refusal, the new PIN is already
  /// chosen.
  void _afterVerified() {
    _step = _newPinHash == null ? _PinFlowStep.newPin : _PinFlowStep.review;
  }

  String? _newHint() {
    if (_isSetup) {
      final text = _recoveryText.text.trim();
      return text.isEmpty ? null : text;
    }
    return switch (_recoveryChoice) {
      _RecoveryChoice.keep => null,
      _RecoveryChoice.remove => '',
      _RecoveryChoice.set => _recoveryText.text.trim(),
    };
  }

  Future<void> _submit() async {
    final newPinHash = _newPinHash;
    if (newPinHash == null || _submitting) return;
    if (!_isSetup &&
        _recoveryChoice == _RecoveryChoice.set &&
        _recoveryText.text.trim().isEmpty) {
      setState(
        () => _recoveryError = _status?.hasPinHint == true
            ? 'Enter a new recovery word, or keep the current one.'
            : 'Enter a recovery word, or choose None.',
      );
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
      _recoveryError = null;
    });
    final newHint = _newHint();
    try {
      if (_isSetup) {
        await widget.repository.setWalletPin(newPinHash, hint: newHint);
        _finish(
          'Your transaction PIN is set.',
          hasPinHint: newHint != null && newHint.isNotEmpty,
        );
      } else {
        final method = _method!;
        final hasPinHint = await widget.repository.changeWalletPin(
          newPinHash: newPinHash,
          method: method,
          currentPinHash: method == WalletPinVerification.currentPin
              ? _verifyPinHash
              : null,
          hint: method == WalletPinVerification.recoveryWord
              ? _verifyText.text.trim()
              : null,
          password: method == WalletPinVerification.password
              ? _verifyText.text
              : null,
          newHint: newHint,
        );
        _finish('Your transaction PIN has been changed.', hasPinHint: hasPinHint);
      }
    } on WalletPinAlreadySetException catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _conflict = true;
        _error = error.message;
      });
    } on CanteenException catch (error) {
      if (!mounted) return;
      _routeRefusal(error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'Something went wrong. Check your connection and try again.';
      });
    }
  }

  /// Sends the user back to the step the server refused, keeping everything
  /// else they entered.
  void _routeRefusal(String message) {
    final text = message.toLowerCase();
    setState(() {
      _submitting = false;
      _error = message;
      if (text.contains('different pin')) {
        _newPinHash = null;
        _entry = '';
        _step = _PinFlowStep.newPin;
      } else if (!_isSetup && text.contains('no recovery word')) {
        _status = WalletPinStatus(hasPin: true, hasPinHint: false);
        _verifyText.clear();
        _step = _PinFlowStep.method;
      } else if (!_isSetup &&
          (text.contains('incorrect') ||
              text.contains("doesn't match") ||
              text.contains('does not match'))) {
        _verifyPinHash = null;
        _verifyText.clear();
        _entry = '';
        _step = _PinFlowStep.verify;
      }
      // Anything else (network, server) stays on the review step for retry.
    });
  }

  void _finish(String message, {required bool hasPinHint}) {
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _status = WalletPinStatus(hasPin: true, hasPinHint: hasPinHint);
      _doneMessage = message;
      _step = _PinFlowStep.done;
    });
  }

  @override
  Widget build(BuildContext context) {
    final showBack = switch (_step) {
      _PinFlowStep.verify ||
      _PinFlowStep.newPin ||
      _PinFlowStep.confirmPin ||
      _PinFlowStep.review => true,
      _ => false,
    };
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: _dragHandle(context)),
              SizedBox(
                height: 44,
                child: Row(
                  children: [
                    if (showBack)
                      IconButton(
                        key: const ValueKey('wallet-pin-back'),
                        tooltip: 'Back',
                        onPressed: _submitting ? null : _back,
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).maybePop(
                        _step == _PinFlowStep.done,
                      ),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: KeyedSubtree(
                  key: ValueKey(_step),
                  child: _buildStep(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep(BuildContext context) => switch (_step) {
    _PinFlowStep.loading => const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Center(child: CircularProgressIndicator()),
    ),
    _PinFlowStep.loadFailed => _message(
      context,
      icon: Icons.cloud_off_rounded,
      title: 'Couldn’t load your PIN settings',
      body: _error ?? 'Try again in a moment.',
      action: 'Try again',
      onAction: _load,
    ),
    _PinFlowStep.intro => _message(
      context,
      icon: Icons.lock_outline_rounded,
      title: 'Set up a transaction PIN',
      body:
          'You’ll enter this 4-digit PIN to approve wallet payments for the '
          'canteen, stationery and laundry.',
      action: 'Set PIN',
      onAction: () => setState(() {
        _error = null;
        _step = _PinFlowStep.newPin;
      }),
    ),
    _PinFlowStep.method => _buildMethod(context),
    _PinFlowStep.verify =>
      _method == WalletPinVerification.currentPin
          ? _pad(
              context,
              title: 'Enter current PIN',
              subtitle: 'The 4-digit PIN you use to pay.',
            )
          : _buildTextVerify(context),
    _PinFlowStep.newPin => _pad(
      context,
      title: _isSetup ? 'Create your PIN' : 'Enter new PIN',
      subtitle: 'Choose 4 digits that are hard to guess.',
    ),
    _PinFlowStep.confirmPin => _pad(
      context,
      title: 'Confirm new PIN',
      subtitle: 'Enter the same 4 digits again.',
    ),
    _PinFlowStep.review => _buildReview(context),
    _PinFlowStep.done => _message(
      context,
      icon: Icons.check_circle_rounded,
      iconColor: context.palette.success,
      title: 'All set',
      body: _doneMessage,
      action: 'Done',
      onAction: () => Navigator.of(context).pop(true),
    ),
  };

  Widget _title(BuildContext context, String title, [String? subtitle]) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: context.palette.ink,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(color: context.palette.inkSecondary, fontSize: 14),
            ),
          ],
        ],
      );

  Widget _errorLine(BuildContext context) {
    final error = _error;
    if (error == null) return const SizedBox(height: 22);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Semantics(
        liveRegion: true,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 17,
              color: context.palette.danger,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                error,
                key: const ValueKey('wallet-pin-error'),
                textAlign: TextAlign.center,
                style: TextStyle(color: context.palette.danger, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _message(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String body,
    required String action,
    required VoidCallback onAction,
    Color? iconColor,
  }) => Column(
    children: [
      const SizedBox(height: 8),
      Icon(icon, size: 44, color: iconColor ?? context.palette.brandInk),
      const SizedBox(height: 14),
      Text(
        title,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: context.palette.ink,
          fontSize: 21,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        body,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: context.palette.inkSecondary,
          fontSize: 14.5,
          height: 1.4,
        ),
      ),
      const SizedBox(height: 24),
      _primaryButton(context, action, onAction),
      const SizedBox(height: 8),
    ],
  );

  Widget _primaryButton(
    BuildContext context,
    String label,
    VoidCallback? onPressed, {
    bool busy = false,
  }) => SizedBox(
    width: double.infinity,
    height: 50,
    child: FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: context.palette.brand,
        foregroundColor: context.palette.onBrand,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      onPressed: busy ? null : onPressed,
      child: busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.2),
            )
          : Text(label),
    ),
  );

  Widget _buildMethod(BuildContext context) {
    final palette = context.palette;
    Widget tile(
      IconData icon,
      String label,
      String detail,
      WalletPinVerification method,
    ) => ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      leading: Icon(icon, color: palette.brandInk),
      title: Text(label, style: TextStyle(color: palette.ink)),
      subtitle: Text(detail, style: TextStyle(color: palette.inkSecondary)),
      trailing: Icon(Icons.chevron_right_rounded, color: palette.inkTertiary),
      onTap: () => _chooseMethod(method),
    );
    final hasHint = _status?.hasPinHint == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _title(context, 'Change transaction PIN', 'First, confirm it’s you.'),
        if (_error != null) _errorLine(context),
        const SizedBox(height: 16),
        Material(
          color: palette.surfaceSunken,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              tile(
                Icons.dialpad_rounded,
                'Enter current PIN',
                'The PIN you pay with',
                WalletPinVerification.currentPin,
              ),
              if (hasHint) ...[
                Divider(height: 1, indent: 54, color: palette.divider),
                tile(
                  Icons.key_rounded,
                  'Use recovery word',
                  'The secret word you chose',
                  WalletPinVerification.recoveryWord,
                ),
              ],
              Divider(height: 1, indent: 54, color: palette.divider),
              tile(
                Icons.password_rounded,
                'Use account password',
                'The password you sign in with',
                WalletPinVerification.password,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildTextVerify(BuildContext context) {
    final isPassword = _method == WalletPinVerification.password;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _title(
          context,
          isPassword ? 'Enter your account password' : 'Enter your recovery word',
          isPassword
              ? 'The password you use to sign in to SuperCampus.'
              : 'The secret word you chose when you set your PIN.',
        ),
        const SizedBox(height: 18),
        TextField(
          key: const ValueKey('wallet-pin-verify-field'),
          controller: _verifyText,
          autofocus: true,
          obscureText: isPassword && _obscureVerify,
          autocorrect: false,
          enableSuggestions: false,
          textCapitalization: TextCapitalization.none,
          keyboardType: isPassword
              ? TextInputType.visiblePassword
              : TextInputType.text,
          autofillHints: isPassword ? const [AutofillHints.password] : null,
          maxLength: isPassword ? null : 30,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _continueTextVerify(),
          decoration: InputDecoration(
            labelText: isPassword ? 'Password' : 'Recovery word',
            counterText: '',
            suffixIcon: isPassword
                ? IconButton(
                    tooltip: _obscureVerify ? 'Show password' : 'Hide password',
                    icon: Icon(
                      _obscureVerify
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () =>
                        setState(() => _obscureVerify = !_obscureVerify),
                  )
                : null,
          ),
        ),
        _errorLine(context),
        const SizedBox(height: 12),
        _primaryButton(
          context,
          'Continue',
          _continueTextVerify,
          busy: _submitting,
        ),
      ],
    );
  }

  Widget _pad(
    BuildContext context, {
    required String title,
    required String subtitle,
  }) => Column(
    children: [
      Text(
        title,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: context.palette.ink,
          fontSize: 22,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        subtitle,
        textAlign: TextAlign.center,
        style: TextStyle(color: context.palette.inkSecondary, fontSize: 14),
      ),
      const SizedBox(height: 18),
      _PinDots(filledCount: _entry.length),
      if (_submitting)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 8),
              Text(
                'Checking…',
                style: TextStyle(
                  color: context.palette.inkSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        )
      else
        _errorLine(context),
      const SizedBox(height: 8),
      _Numpad(onDigit: _digit, onDelete: _deleteDigit),
    ],
  );

  Widget _buildReview(BuildContext context) {
    final palette = context.palette;
    final hasHint = _status?.hasPinHint == true;
    final showField = _isSetup || _recoveryChoice == _RecoveryChoice.set;
    ChoiceChip chip(String label, _RecoveryChoice choice) => ChoiceChip(
      label: Text(label),
      selected: _recoveryChoice == choice,
      onSelected: _submitting
          ? null
          : (_) => setState(() {
              _recoveryChoice = choice;
              _recoveryError = null;
            }),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _title(
          context,
          _isSetup ? 'Add a recovery word?' : 'Ready to change your PIN',
          _isSetup
              ? 'Optional. A secret word only you know — you can use it to '
                    'change your PIN if you forget it.'
              : 'Your new PIN is confirmed. You can also update your '
                    'recovery word.',
        ),
        const SizedBox(height: 16),
        if (!_isSetup) ...[
          Text(
            'Recovery word',
            style: TextStyle(
              color: palette.inkSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: hasHint
                ? [
                    chip('Keep current', _RecoveryChoice.keep),
                    chip('Change', _RecoveryChoice.set),
                    chip('Remove', _RecoveryChoice.remove),
                  ]
                : [
                    chip('None', _RecoveryChoice.keep),
                    chip('Add one', _RecoveryChoice.set),
                  ],
          ),
          const SizedBox(height: 12),
        ],
        if (showField)
          TextField(
            key: const ValueKey('wallet-pin-recovery-field'),
            controller: _recoveryText,
            enabled: !_submitting,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.none,
            keyboardType: TextInputType.text,
            maxLength: 30,
            textInputAction: TextInputAction.done,
            onChanged: (_) {
              if (_recoveryError != null) {
                setState(() => _recoveryError = null);
              }
            },
            decoration: InputDecoration(
              labelText: _isSetup ? 'Recovery word (optional)' : 'New recovery word',
              helperText: 'Up to 30 characters. Not case-sensitive.',
              errorText: _recoveryError,
            ),
          ),
        _errorLine(context),
        const SizedBox(height: 12),
        if (_conflict)
          _primaryButton(context, 'Change PIN instead', _load)
        else
          _primaryButton(
            context,
            _isSetup ? 'Set PIN' : 'Change PIN',
            _submit,
            busy: _submitting,
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Public helpers to show the sheets and return typed results
// ─────────────────────────────────────────────────────────────────────────────

/// Show the verify-PIN sheet for a payment. Returns the PIN hash if approved,
/// or null if dismissed.
Future<String?> showVerifyPinSheet(
  BuildContext context, {
  required double amount,
  required String summary,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: context.palette.surfaceRaised,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
    ),
    builder: (_) =>
        TransactionPinSheet(amount: amount, summary: summary),
  );
}

/// Show the first-time PIN setup sheet. Returns the hash + hint, or null.
Future<({String pinHash, String? hint})?> showSetupPinSheet(
  BuildContext context,
) async {
  final result = await showModalBottomSheet<_PinSetupResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: context.palette.surfaceRaised,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
    ),
    builder: (_) => const SetupPinSheet(),
  );
  if (result == null) return null;
  return (pinHash: result.pinHash, hint: result.hint);
}

/// Opens the transaction-PIN manager: it loads whether a PIN (and a recovery
/// word) exists, then offers Set PIN or Change PIN. Resolves to true when a
/// PIN was set or changed.
Future<bool> showWalletPinSheet(
  BuildContext context, {
  required WalletPinRepository repository,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: context.palette.surfaceRaised,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => WalletPinSheet(repository: repository),
  );
  return result ?? false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared widgets
// ─────────────────────────────────────────────────────────────────────────────

class _PinScaffold extends StatelessWidget {
  const _PinScaffold({
    required this.title,
    required this.subtitle,
    this.amountLabel,
    required this.pin,
    this.error,
    required this.onEnterDigit,
    required this.onDelete,
  });

  final String title;
  final String subtitle;
  final String? amountLabel;
  final String pin;
  final String? error;
  final Future<void> Function(String) onEnterDigit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dragHandle(context),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline, color: context.palette.brandInk),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (amountLabel != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.palette.canvas,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: context.palette.border),
                ),
                child: Column(
                  children: [
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      amountLabel!,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            _PinDots(filledCount: pin.length),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(
                error!,
                style: TextStyle(color: context.adaptive(light: Colors.red, dark: const Color(0xFFF87171)), fontSize: 13),
              ),
            ],
            const SizedBox(height: 14),
            _Numpad(onDigit: onEnterDigit, onDelete: onDelete),
          ],
        ),
      ),
    );
  }
}

class _PinDots extends StatelessWidget {
  const _PinDots({required this.filledCount});
  final int filledCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        return Container(
          width: 48,
          height: 48,
          margin: const EdgeInsets.symmetric(horizontal: 7),
          decoration: BoxDecoration(
            color: index < filledCount ? context.palette.brandInk : context.palette.surface,
            shape: BoxShape.circle,
            border: Border.all(
              color: index < filledCount ? context.palette.brandInk : context.palette.border,
              width: 2,
            ),
          ),
        );
      }),
    );
  }
}

class _Numpad extends StatelessWidget {
  const _Numpad({required this.onDigit, required this.onDelete});
  final Future<void> Function(String) onDigit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(
              children: row
                  .map(
                    (digit) => Expanded(
                      child: _PinKey(
                        label: digit,
                        onTap: () => onDigit(digit),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        Row(
          children: [
            const Expanded(child: SizedBox(height: 58)),
            Expanded(
              child: _PinKey(label: '0', onTap: () => onDigit('0')),
            ),
            Expanded(
              child: IconButton(
                tooltip: 'Delete digit',
                onPressed: onDelete,
                icon: const Icon(Icons.backspace_outlined),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PinKey extends StatelessWidget {
  const _PinKey({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: TextButton(
        onPressed: onTap,
        child: Text(
          label,
          style: TextStyle(
            color: context.palette.ink,
            fontSize: 26,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

Widget _dragHandle(BuildContext context) => Container(
      width: 42,
      height: 4,
      decoration: BoxDecoration(
        color: context.palette.border,
        borderRadius: BorderRadius.circular(2),
      ),
    );
