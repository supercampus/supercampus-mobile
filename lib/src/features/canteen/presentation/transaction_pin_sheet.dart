import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';

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

  Future<void> _enterDigit(String digit) async {
    if (_pin.length >= 4) return;
    setState(() => _pin += digit);
    if (_pin.length == 4) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (mounted) Navigator.of(context).pop(true);
    }
  }

  void _deleteDigit() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline, color: AppColors.primary),
                SizedBox(width: 10),
                Text(
                  'Enter transaction PIN',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 18),
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
                    widget.summary,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    formatCurrency(widget.amount),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                return Container(
                  width: 48,
                  height: 48,
                  margin: const EdgeInsets.symmetric(horizontal: 7),
                  decoration: BoxDecoration(
                    color: index < _pin.length
                        ? AppColors.primary
                        : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: index < _pin.length
                          ? AppColors.primary
                          : AppColors.border,
                      width: 2,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 18),
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
                            onTap: () => _enterDigit(digit),
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
                  child: _PinKey(label: '0', onTap: () => _enterDigit('0')),
                ),
                Expanded(
                  child: IconButton(
                    tooltip: 'Delete digit',
                    onPressed: _deleteDigit,
                    icon: const Icon(Icons.backspace_outlined),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Demo mode · Enter any four digits',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
        ),
      ),
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
