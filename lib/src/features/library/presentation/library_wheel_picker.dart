import 'package:flutter/material.dart';

/// A reusable wheel-picker styled as a segmented pill box that adapts to
/// the app's light / dark theme automatically.
class LibraryWheelPicker extends StatefulWidget {
  const LibraryWheelPicker({
    super.key,
    required this.itemCount,
    required this.labelBuilder,
    required this.onChanged,
    this.initialIndex = 0,
    this.itemExtent = 40,
    this.height = 160,
    this.width,
  });

  final int itemCount;
  final String Function(int index) labelBuilder;
  final ValueChanged<int> onChanged;
  final int initialIndex;
  final double itemExtent;
  final double height;
  final double? width;

  @override
  State<LibraryWheelPicker> createState() => _LibraryWheelPickerState();
}

class _LibraryWheelPickerState extends State<LibraryWheelPicker> {
  late final FixedExtentScrollController _controller;

  @override
  void initState() {
    super.initState();
    _controller = FixedExtentScrollController(initialItem: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fillColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? const Color(0xFF3A3A3A) : const Color(0xFFE1E5E3);
    final textColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final fadedTextColor = isDark ? Colors.white38 : const Color(0xFF1C1C1E).withValues(alpha: 0.3);

    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Stack(
        children: [
          // Selection highlight band
          Center(
            child: Container(
              height: widget.itemExtent,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : const Color(0xFF6D357F).withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          // Wheel
          ListWheelScrollView.useDelegate(
            controller: _controller,
            itemExtent: widget.itemExtent,
            diameterRatio: 1.2,
            magnification: 1.15,
            useMagnifier: true,
            physics: const FixedExtentScrollPhysics(),
            onSelectedItemChanged: widget.onChanged,
            childDelegate: ListWheelChildBuilderDelegate(
              childCount: widget.itemCount,
              builder: (context, index) {
                return Center(
                  child: Text(
                    widget.labelBuilder(index),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Poppins',
                      color: index == _controller.selectedItem
                          ? textColor
                          : fadedTextColor,
                    ),
                  ),
                );
              },
            ),
          ),
          // Top gradient fade
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: widget.itemExtent * 1.2,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [fillColor, fillColor.withValues(alpha: 0)],
                  ),
                ),
              ),
            ),
          ),
          // Bottom gradient fade
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: widget.itemExtent * 1.2,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [fillColor, fillColor.withValues(alpha: 0)],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A segmented pill that displays a value and opens a wheel picker on tap.
class SegmentedPill extends StatelessWidget {
  const SegmentedPill({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.isActive = false,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fillColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isActive
        ? const Color(0xFF6D357F)
        : (isDark ? const Color(0xFF3A3A3A) : const Color(0xFFE1E5E3));
    final textColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final labelColor = isDark ? Colors.white54 : const Color(0xFF6B7280);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: fillColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: isActive ? 1.5 : 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: labelColor,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: textColor,
                fontFamily: 'Poppins',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
