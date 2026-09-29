import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';

/// Shared pieces for the Admin Desk system pages: an iOS-style large title,
/// inset grouped surfaces on the sunken page, and quiet empty/error states.

final _money = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 2,
);
final _moneyWhole = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 0,
);

String formatRupees(double value) {
  final whole = value == value.roundToDouble();
  return (whole ? _moneyWhole : _money).format(value);
}

String formatSignedRupees(double value) =>
    '${value < 0 ? '−' : '+'}${formatRupees(value.abs())}';

String formatStamp(DateTime? value) =>
    value == null ? '—' : DateFormat('d MMM yyyy, h:mm a').format(value);

String formatShortDay(DateTime value) => DateFormat('d MMM yyyy').format(value);

/// "Just now", "5 min ago", "3 h ago", then the date.
String formatRelative(DateTime? value, {DateTime? now}) {
  if (value == null) return '—';
  final difference = (now ?? DateTime.now()).difference(value);
  if (difference.inMinutes < 1) return 'Just now';
  if (difference.inHours < 1) return '${difference.inMinutes} min ago';
  if (difference.inDays < 1) return '${difference.inHours} h ago';
  if (difference.inDays < 7) return '${difference.inDays} d ago';
  return DateFormat('d MMM yyyy').format(value);
}

class SystemPageHeader extends StatelessWidget {
  const SystemPageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final canPop = Navigator.of(context).canPop();
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (canPop)
                IconButton(
                  tooltip: 'Back',
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: palette.ink,
                  ),
                )
              else
                const SizedBox(height: 48),
              const Spacer(),
              if (trailing != null) trailing!,
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 0, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.6,
                    color: palette.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 14, color: palette.inkSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A rounded surface on the sunken page, like an iOS inset group.
class SystemCard extends StatelessWidget {
  const SystemCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(16, 14, 16, 14),
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: context.palette.surface,
    borderRadius: BorderRadius.circular(16),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(padding: padding, child: child),
    ),
  );
}

class SystemSectionLabel extends StatelessWidget {
  const SystemSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
    child: Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
        color: context.palette.inkSecondary,
      ),
    ),
  );
}

/// Label and value, several to a row, separated by hairlines.
class SystemMetricRow extends StatelessWidget {
  const SystemMetricRow({super.key, required this.metrics});

  final List<(String label, String value, Color? color)> metrics;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SystemCard(
      child: Row(
        children: [
          for (var i = 0; i < metrics.length; i++) ...[
            if (i > 0)
              Container(
                width: 0.5,
                height: 38,
                margin: const EdgeInsets.symmetric(horizontal: 10),
                color: palette.divider,
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    metrics[i].$1,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: palette.inkSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      metrics[i].$2,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                        color: metrics[i].$3 ?? palette.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class SystemSearchField extends StatelessWidget {
  const SystemSearchField({
    super.key,
    required this.controller,
    required this.hint,
    required this.onSubmitted,
    this.fieldKey,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onSubmitted;
  final Key? fieldKey;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return TextField(
      key: fieldKey,
      controller: controller,
      textInputAction: TextInputAction.search,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(Icons.search_rounded, color: palette.inkSecondary),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) => value.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  tooltip: 'Clear',
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () {
                    controller.clear();
                    onSubmitted('');
                  },
                ),
        ),
        filled: true,
        fillColor: palette.surface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

/// A horizontal row of single-choice chips.
class SystemChoiceChips<T> extends StatelessWidget {
  const SystemChoiceChips({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<(T value, String label)> options;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Row(
      children: [
        for (final option in options)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(option.$2),
              selected: option.$1 == selected,
              showCheckmark: false,
              onSelected: (_) => onSelected(option.$1),
            ),
          ),
      ],
    ),
  );
}

class SystemMessage extends StatelessWidget {
  const SystemMessage({
    super.key,
    required this.icon,
    required this.title,
    this.body,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 48, 32, 48),
      child: Column(
        children: [
          Icon(icon, size: 40, color: palette.inkTertiary),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: palette.ink,
            ),
          ),
          if (body != null) ...[
            const SizedBox(height: 6),
            Text(
              body!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: palette.inkSecondary),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

/// A small tinted status label.
class SystemBadge extends StatelessWidget {
  const SystemBadge({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ink = context.isDarkTheme
        ? Color.lerp(color, Colors.white, 0.35)!
        : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ink),
      ),
    );
  }
}

/// One label/value line in a detail sheet.
class SystemDetailLine extends StatelessWidget {
  const SystemDetailLine({super.key, required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = value?.trim();
    if (text == null || text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 116,
            child: Text(
              label,
              style: TextStyle(fontSize: 14, color: palette.inkSecondary),
            ),
          ),
          Expanded(
            child: SelectableText(
              text,
              style: TextStyle(fontSize: 14, color: palette.ink),
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens a scrollable detail sheet with a title and lines.
Future<void> showSystemDetailSheet(
  BuildContext context, {
  required String title,
  String? subtitle,
  required List<Widget> children,
  Widget? footer,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: context.palette.surface,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, controller) => SingleChildScrollView(
        controller: controller,
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          MediaQuery.paddingOf(context).bottom + 20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
                color: context.palette.ink,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 14,
                  color: context.palette.inkSecondary,
                ),
              ),
            ],
            const SizedBox(height: 12),
            ...children,
            if (footer != null) ...[const SizedBox(height: 16), footer],
          ],
        ),
      ),
    ),
  );
}

/// Picks a from/to day range; null when cancelled.
Future<DateTimeRange?> pickDayRange(
  BuildContext context, {
  DateTime? from,
  DateTime? to,
}) {
  final now = DateTime.now();
  return showDateRangePicker(
    context: context,
    firstDate: DateTime(now.year - 5),
    lastDate: DateTime(now.year, now.month, now.day),
    initialDateRange: from != null && to != null
        ? DateTimeRange(start: from, end: to)
        : null,
  );
}
