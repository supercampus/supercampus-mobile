import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

class QuantityControl extends StatelessWidget {
  const QuantityControl({
    super.key,
    required this.quantity,
    required this.onAdd,
    required this.onRemove,
    this.compact = false,
  });

  final int quantity;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final buttonSize = compact ? 34.0 : 40.0;
    if (quantity == 0) {
      return SizedBox.square(
        dimension: buttonSize,
        child: IconButton.filled(
          tooltip: 'Add item',
          onPressed: onAdd,
          style: IconButton.styleFrom(backgroundColor: AppColors.primary),
          icon: const Icon(Icons.add),
        ),
      );
    }

    return Container(
      height: buttonSize,
      decoration: BoxDecoration(
        color: const Color(0xFFE7F3EC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFBBD9C6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Remove one',
            constraints: BoxConstraints.tightFor(
              width: buttonSize,
              height: buttonSize,
            ),
            padding: EdgeInsets.zero,
            onPressed: onRemove,
            icon: const Icon(Icons.remove, size: 18),
          ),
          SizedBox(
            width: 24,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Add one',
            constraints: BoxConstraints.tightFor(
              width: buttonSize,
              height: buttonSize,
            ),
            padding: EdgeInsets.zero,
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 18),
          ),
        ],
      ),
    );
  }
}
