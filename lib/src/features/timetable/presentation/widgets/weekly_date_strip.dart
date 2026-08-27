import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';

class WeeklyDateStrip extends StatefulWidget {
  const WeeklyDateStrip({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
  });

  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  @override
  State<WeeklyDateStrip> createState() => _WeeklyDateStripState();
}

class _WeeklyDateStripState extends State<WeeklyDateStrip> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelectedDate();
    });
  }

  @override
  void didUpdateWidget(covariant WeeklyDateStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDate != widget.selectedDate) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToSelectedDate();
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToSelectedDate() {
    if (!_scrollController.hasClients) return;

    final int selectedIndex = widget.selectedDate.day - 1;

    const double navBoxWidth = 76.0;
    const double itemWidth = 64.0;
    const double itemMargin = 10.0;

    final double screenWidth = MediaQuery.of(context).size.width;
    final double targetOffset =
        (navBoxWidth + itemMargin) +
        (selectedIndex * (itemWidth + itemMargin)) -
        (screenWidth / 2) +
        (itemWidth / 2);

    final double maxScroll = _scrollController.position.maxScrollExtent;
    final double clampedOffset = targetOffset.clamp(0.0, maxScroll);

    _scrollController.animateTo(
      clampedOffset,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  void _changeMonth(int delta) {
    final newMonth = DateTime(
      widget.selectedDate.year,
      widget.selectedDate.month + delta,
      1,
    );
    widget.onDateSelected(newMonth);
  }

  @override
  Widget build(BuildContext context) {
    final year = widget.selectedDate.year;
    final month = widget.selectedDate.month;
    final int daysInMonth = DateTime(year, month + 1, 0).day;

    final List<DateTime> monthDates = List.generate(
      daysInMonth,
      (index) => DateTime(year, month, index + 1),
    );

    final monthYearLabel = DateFormat('MMMM yyyy').format(widget.selectedDate);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Month and Year Label Header above the strip
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            children: [
              const Icon(
                Icons.calendar_month_rounded,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                monthYearLabel,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.ink,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$daysInMonth Days',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Horizontal Full-Month Date Strip with Navigation Boxes
        SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              // Far-Left Navigation Box: "Previous Month"
              GestureDetector(
                onTap: () => _changeMonth(-1),
                child: Container(
                  width: 76,
                  margin: const EdgeInsets.only(right: 10, top: 4, bottom: 6),
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.chevron_left_rounded,
                        size: 20,
                        color: AppColors.primary,
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Previous\nMonth',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Full Month Date Boxes (1 through daysInMonth)
              ...monthDates.map((date) {
                final isSelected =
                    date.year == widget.selectedDate.year &&
                    date.month == widget.selectedDate.month &&
                    date.day == widget.selectedDate.day;

                return GestureDetector(
                  onTap: () => widget.onDateSelected(date),
                  child: AnimatedScale(
                    scale: isSelected ? 1.04 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      width: 64,
                      margin: const EdgeInsets.only(
                        right: 10,
                        top: 4,
                        bottom: 6,
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : Colors.grey.shade200,
                          width: isSelected ? 1.5 : 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isSelected
                                ? AppColors.primary.withValues(alpha: 0.35)
                                : Colors.black.withValues(alpha: 0.04),
                            blurRadius: isSelected ? 10 : 4,
                            offset: Offset(0, isSelected ? 5 : 2),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            DateFormat('E').format(date).toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? Colors.white.withValues(alpha: 0.8)
                                  : AppColors.muted,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('dd').format(date),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('MMM').format(date).toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: isSelected
                                  ? Colors.white.withValues(alpha: 0.75)
                                  : AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),

              // Far-Right Navigation Box: "Next Month"
              GestureDetector(
                onTap: () => _changeMonth(1),
                child: Container(
                  width: 76,
                  margin: const EdgeInsets.only(right: 10, top: 4, bottom: 6),
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: AppColors.primary,
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Next\nMonth',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
