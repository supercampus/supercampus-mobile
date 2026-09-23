import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';

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
            _dragHandle(),
            const SizedBox(height: 20),
            const Icon(Icons.lock_outline, color: AppColors.primary, size: 32),
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
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            // Hint word field (only on first step)
            if (!_isConfirming) ...[
              TextField(
                controller: _hintController,
                decoration: const InputDecoration(
                  labelText: 'Hint word (optional)',
                  hintText: 'e.g. favourite color',
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
                style: const TextStyle(color: Colors.red, fontSize: 13),
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
// Change PIN sheet — shows method selector then PIN entry
// ─────────────────────────────────────────────────────────────────────────────

enum _ChangePinStep { selectMethod, enterNewPin, confirmNewPin }

class ChangePinSheet extends StatefulWidget {
  const ChangePinSheet({super.key, required this.hasHint});
  final bool hasHint;

  @override
  State<ChangePinSheet> createState() => _ChangePinSheetState();
}

class _ChangePinSheetState extends State<ChangePinSheet> {
  _ChangePinStep _step = _ChangePinStep.selectMethod;
  String? _method;
  final _verifyController = TextEditingController(); // for hint/password input
  var _verifyPin = ''; // for current_pin method
  var _newPin = '';
  var _confirmPin = '';
  String? _newPinFirst;
  String? _error;
  var _obscurePassword = true;

  @override
  void dispose() {
    _verifyController.dispose();
    super.dispose();
  }



  Future<void> _enterVerifyDigit(String digit) async {
    if (_verifyPin.length >= 4) return;
    setState(() {
      _verifyPin += digit;
      _error = null;
    });
    if (_verifyPin.length == 4) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
      setState(() => _step = _ChangePinStep.enterNewPin);
    }
  }

  void _deleteVerifyDigit() {
    if (_verifyPin.isEmpty) return;
    setState(() {
      _verifyPin = _verifyPin.substring(0, _verifyPin.length - 1);
      _error = null;
    });
  }

  Future<void> _enterNewDigit(String digit) async {
    if (_step == _ChangePinStep.enterNewPin) {
      if (_newPin.length >= 4) return;
      setState(() {
        _newPin += digit;
        _error = null;
      });
      if (_newPin.length == 4) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        if (!mounted) return;
        setState(() {
          _newPinFirst = _newPin;
          _step = _ChangePinStep.confirmNewPin;
          _newPin = '';
        });
      }
    } else {
      if (_confirmPin.length >= 4) return;
      setState(() {
        _confirmPin += digit;
        _error = null;
      });
      if (_confirmPin.length == 4) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        if (!mounted) return;
        if (_confirmPin != _newPinFirst) {
          setState(() {
            _confirmPin = '';
            _error = 'PINs do not match. Try again.';
          });
          return;
        }
        // Build result and pop
        Navigator.of(context).pop(
          _ChangePinResult(
            method: _method!,
            newPinHash: pinSha256(_confirmPin),
            currentPinHash: _method == 'current_pin'
                ? pinSha256(_verifyPin)
                : null,
            hint: _method == 'hint' ? _verifyController.text.trim() : null,
            password:
                _method == 'password' ? _verifyController.text : null,
          ),
        );
      }
    }
  }

  void _deleteNewDigit() {
    if (_step == _ChangePinStep.confirmNewPin) {
      if (_confirmPin.isEmpty) return;
      setState(() {
        _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
        _error = null;
      });
    } else {
      if (_newPin.isEmpty) return;
      setState(() {
        _newPin = _newPin.substring(0, _newPin.length - 1);
        _error = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_method == null) {
      return _buildMethodSelector(context);
    }
    if (_method == 'current_pin' && _step == _ChangePinStep.selectMethod) {
      return _buildCurrentPinVerify();
    }
    if ((_method == 'hint' || _method == 'password') &&
        _step == _ChangePinStep.selectMethod) {
      return _buildTextVerify();
    }
    // New PIN entry / confirm
    return _buildNewPin();
  }

  Widget _buildMethodSelector(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _dragHandle(),
            const SizedBox(height: 20),
            const Text(
              'Change wallet PIN',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            const Text(
              'Choose how to verify your identity',
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 20),
            _methodTile(
              icon: Icons.dialpad_outlined,
              label: 'Enter current PIN',
              onTap: () => setState(() {
                _method = 'current_pin';
                _step = _ChangePinStep.selectMethod;
              }),
            ),
            if (widget.hasHint)
              _methodTile(
                icon: Icons.lightbulb_outline,
                label: 'Use hint word',
                onTap: () => setState(() {
                  _method = 'hint';
                  _step = _ChangePinStep.selectMethod;
                }),
              ),
            _methodTile(
              icon: Icons.vpn_key_outlined,
              label: 'Account password',
              onTap: () => setState(() {
                _method = 'password';
                _step = _ChangePinStep.selectMethod;
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _methodTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppColors.primary),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  Widget _buildCurrentPinVerify() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dragHandle(),
            const SizedBox(height: 20),
            const Text(
              'Enter current PIN',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            _PinDots(filledCount: _verifyPin.length),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
            ],
            const SizedBox(height: 14),
            _Numpad(onDigit: _enterVerifyDigit, onDelete: _deleteVerifyDigit),
          ],
        ),
      ),
    );
  }

  Widget _buildTextVerify() {
    final isHint = _method == 'hint';
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          12,
          24,
          MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _dragHandle(),
            const SizedBox(height: 20),
            Text(
              isHint ? 'Enter your hint word' : 'Enter account password',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _verifyController,
              autofocus: true,
              obscureText: !isHint && _obscurePassword,
              decoration: InputDecoration(
                labelText: isHint ? 'Hint word' : 'Password',
                border: const OutlineInputBorder(),
                suffixIcon: isHint
                    ? null
                    : IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
              ),
              onSubmitted: (_) => _continueTextVerify(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _continueTextVerify,
                child: const Text('Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _continueTextVerify() {
    if (_verifyController.text.trim().isEmpty) {
      setState(() => _error = 'Please enter a value');
      return;
    }
    setState(() {
      _step = _ChangePinStep.enterNewPin;
      _error = null;
    });
  }

  Widget _buildNewPin() {
    final isConfirm = _step == _ChangePinStep.confirmNewPin;
    final currentPin = isConfirm ? _confirmPin : _newPin;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dragHandle(),
            const SizedBox(height: 20),
            Text(
              isConfirm ? 'Confirm new PIN' : 'Enter new PIN',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            _PinDots(filledCount: currentPin.length),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
            ],
            const SizedBox(height: 14),
            _Numpad(onDigit: _enterNewDigit, onDelete: _deleteNewDigit),
          ],
        ),
      ),
    );
  }
}

class _ChangePinResult {
  const _ChangePinResult({
    required this.method,
    required this.newPinHash,
    this.currentPinHash,
    this.hint,
    this.password,
  });
  final String method;
  final String newPinHash;
  final String? currentPinHash;
  final String? hint;
  final String? password;
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
    backgroundColor: Colors.white,
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
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
    ),
    builder: (_) => const SetupPinSheet(),
  );
  if (result == null) return null;
  return (pinHash: result.pinHash, hint: result.hint);
}

/// Show the change-PIN sheet. Returns a [_ChangePinResult]-like record, or null.
Future<({
  String method,
  String newPinHash,
  String? currentPinHash,
  String? hint,
  String? password,
})?> showChangePinSheet(
  BuildContext context, {
  required bool hasHint,
}) async {
  final result = await showModalBottomSheet<_ChangePinResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
    ),
    builder: (_) => ChangePinSheet(hasHint: hasHint),
  );
  if (result == null) return null;
  return (
    method: result.method,
    newPinHash: result.newPinHash,
    currentPinHash: result.currentPinHash,
    hint: result.hint,
    password: result.password,
  );
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
            _dragHandle(),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline, color: AppColors.primary),
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
                  color: AppColors.canvas,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
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
                style: const TextStyle(color: Colors.red, fontSize: 13),
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
            color: index < filledCount ? AppColors.primary : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: index < filledCount ? AppColors.primary : AppColors.border,
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
          style: const TextStyle(
            color: AppColors.ink,
            fontSize: 26,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

Widget _dragHandle() => Container(
      width: 42,
      height: 4,
      decoration: BoxDecoration(
        color: AppColors.border,
        borderRadius: BorderRadius.circular(2),
      ),
    );
