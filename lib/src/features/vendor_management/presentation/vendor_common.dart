part of 'vendor_management_shell.dart';

final _wholeNumber = NumberFormat.decimalPattern('en_IN');
final _twoDecimals = NumberFormat('#,##,##0.00', 'en_IN');

/// ₹1,613 — or ₹1,613.50 when there are paise to show.
String formatRupees(num amount) {
  final rounded = (amount * 100).round() / 100;
  return rounded == rounded.roundToDouble()
      ? '₹${_wholeNumber.format(rounded.round())}'
      : '₹${_twoDecimals.format(rounded)}';
}

String formatCount(num count) => _wholeNumber.format(count.round());

/// "2 kg", "3 clothes", "×2".
String formatQuantity(double quantity, [String? unit]) {
  final text = quantity == quantity.roundToDouble()
      ? quantity.round().toString()
      : quantity.toStringAsFixed(1);
  return unit == null || unit.isEmpty ? '×$text' : '$text $unit';
}

IconData categoryIcon(String category) {
  final lower = category.toLowerCase();
  if (lower.contains('canteen') ||
      lower.contains('food') ||
      lower.contains('mess') ||
      lower.contains('dining')) {
    return Icons.restaurant_rounded;
  }
  if (lower.contains('stationery') || lower.contains('book')) {
    return Icons.edit_note_rounded;
  }
  if (lower.contains('laundry')) return Icons.local_laundry_service_rounded;
  return Icons.storefront_rounded;
}

/// The white, hairline-bordered card every section sits on.
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.child,
    this.title,
    this.subtitle,
    this.padding = const EdgeInsets.all(16),
  });

  final String? title;
  final String? subtitle;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.border),
      ),
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
                color: p.ink,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: TextStyle(fontSize: 12.5, color: p.inkSecondary),
              ),
            ],
            const SizedBox(height: 14),
          ],
          child,
        ],
      ),
    );
  }
}

/// A small tinted capsule: "Open", "Paid", "Owner".
class _Pill extends StatelessWidget {
  const _Pill(this.label, {required this.color, required this.background});

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: color,
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

_Pill _statusPill(BuildContext context, OrderStatusFilter bucket, String label) {
  final p = context.palette;
  return switch (bucket) {
    OrderStatusFilter.completed => _Pill(
      label,
      color: p.success,
      background: p.successSoft,
    ),
    OrderStatusFilter.cancelled => _Pill(
      label,
      color: p.danger,
      background: p.dangerSoft,
    ),
    _ => _Pill(label, color: p.warning, background: p.warningSoft),
  };
}

_Pill _tradingPill(BuildContext context, {required bool active, required bool open}) {
  final p = context.palette;
  if (!active) {
    return _Pill('Disabled', color: p.inkSecondary, background: p.surfaceMuted);
  }
  return open
      ? _Pill('Open', color: p.success, background: p.successSoft)
      : _Pill('Closed', color: p.warning, background: p.warningSoft);
}

class _ShopAvatar extends StatelessWidget {
  const _ShopAvatar(this.category, {this.size = 40});

  final String category;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: p.brandSoft,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(categoryIcon(category), color: p.brandInk, size: size * 0.5),
    );
  }
}

/// Segmented control for mutually exclusive choices (period, status).
class _Segments<T> extends StatelessWidget {
  const _Segments({
    required this.values,
    required this.selected,
    required this.label,
    required this.onChanged,
  });

  final List<T> values;
  final T selected;
  final String Function(T) label;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: p.surfaceSunken,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          for (final value in values)
            Expanded(
              child: Semantics(
                button: true,
                selected: value == selected,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(value),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: value == selected ? p.surface : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                      boxShadow: value == selected
                          ? [
                              BoxShadow(
                                color: p.shadow.withValues(alpha: 0.08),
                                blurRadius: 6,
                                offset: const Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      label(value),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: value == selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: value == selected ? p.ink : p.inkSecondary,
                      ),
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

/// A calm, explicit "not yours to see" page instead of a raw server refusal.
class _NoAccessState extends StatelessWidget {
  const _NoAccessState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => _MessageState(
    icon: Icons.lock_outline_rounded,
    title: 'No access',
    message: message,
  );
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
    this.onRetry,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: p.inkTertiary),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: p.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: p.inkSecondary, fontSize: 14),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Error body for a failed load: access refusals read as such.
Widget _loadFailure(Object error, VoidCallback onRetry, String deniedMessage) {
  if (isAccessDenied(error)) return _NoAccessState(message: deniedMessage);
  return _MessageState(
    icon: Icons.cloud_off_rounded,
    title: "Couldn't load",
    message: userFacingError(error),
    onRetry: onRetry,
  );
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 36,
      height: 5,
      decoration: BoxDecoration(
        color: context.palette.borderStrong,
        borderRadius: BorderRadius.circular(3),
      ),
    ),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(fontSize: 13.5, color: p.inkSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: p.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
