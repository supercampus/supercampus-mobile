import 'package:flutter/material.dart';

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
    final isZero = quantity == 0;
    final double height = compact ? 34.0 : 40.0;
    final double width =
        isZero ? (compact ? 44.0 : 46.0) : (compact ? 96.0 : 108.0);
    final double iconButtonSize = compact ? 32.0 : 36.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOutCubic,
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isZero ? const Color(0xFF2563EB) : const Color(0xFFE7F3EC),
        borderRadius: BorderRadius.circular(isZero ? (height / 2) : 8.0),
        border: Border.all(
          color: isZero ? Colors.transparent : const Color(0xFFBBD9C6),
          width: 1.2,
        ),
        boxShadow: isZero
            ? [
                BoxShadow(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(isZero ? (height / 2) : 8.0),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.72, end: 1.0).animate(animation),
                child: child,
              ),
            );
          },
          child: isZero
              ? Material(
                  key: const ValueKey('add_button'),
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onAdd,
                    child: SizedBox(
                      width: width,
                      height: height,
                      child: const Center(
                        child: Icon(
                          Icons.add,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                )
              : Material(
                  key: const ValueKey('stepper_row'),
                  color: Colors.transparent,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        tooltip: 'Remove one',
                        constraints: BoxConstraints.tightFor(
                          width: iconButtonSize,
                          height: height,
                        ),
                        padding: EdgeInsets.zero,
                        onPressed: onRemove,
                        icon: const Icon(
                          Icons.remove,
                          size: 18,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        transitionBuilder: (child, animation) {
                          return SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.4),
                              end: Offset.zero,
                            ).animate(animation),
                            child: FadeTransition(
                              opacity: animation,
                              child: child,
                            ),
                          );
                        },
                        child: Text(
                          '$quantity',
                          key: ValueKey('qty_$quantity'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF2563EB),
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Add one',
                        constraints: BoxConstraints.tightFor(
                          width: iconButtonSize,
                          height: height,
                        ),
                        padding: EdgeInsets.zero,
                        onPressed: onAdd,
                        icon: const Icon(
                          Icons.add,
                          size: 18,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
