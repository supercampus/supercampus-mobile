import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/module_navigation_buttons.dart';
import '../../data/canteen_models.dart';
import 'menu_item_art.dart';
import 'order_status_badge.dart';

/// Opens [CanteenOrderDetailPage] for [order] on top of the current page.
Future<void> openCanteenOrderDetail(BuildContext context, CanteenOrder order) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(builder: (_) => CanteenOrderDetailPage(order: order)),
  );
}

/// Everything the counter knows about one order.
///
/// Built only from what [CanteenOrder] carries: rows whose data the order does
/// not have are left out rather than filled with placeholders.
class CanteenOrderDetailPage extends StatelessWidget {
  const CanteenOrderDetailPage({super.key, required this.order});

  final CanteenOrder order;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final placed = order.createdAt.toLocal();
    final itemCount = order.lines.fold<int>(0, (sum, l) => sum + l.quantity);
    final customer = order.customerName?.trim();
    final handledBy = order.captainName?.trim();

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: AppBar(
        titleSpacing: 0,
        leading: ModuleBackButton(
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text('Order #${order.displayId}'),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                _SummaryCard(order: order, itemCount: itemCount),
                const SizedBox(height: 24),
                const _SectionLabel('Items'),
                _GroupedCard(
                  children: [
                    if (order.lines.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'No item details on this order.',
                          style: TextStyle(color: p.inkSecondary),
                        ),
                      )
                    else
                      for (final line in order.lines) _ItemRow(line: line),
                    _TotalRow(total: order.total),
                  ],
                ),
                const SizedBox(height: 24),
                const _SectionLabel('Details'),
                _GroupedCard(
                  children: [
                    _DetailRow(
                      label: 'Customer',
                      value: (customer == null || customer.isEmpty)
                          ? 'Campus user'
                          : customer,
                    ),
                    _DetailRow(
                      label: 'Placed',
                      value:
                          '${formatShortDate(placed)}, ${formatTime(placed)}',
                    ),
                    _DetailRow(
                      label: 'Fulfilment',
                      value: order.fulfilmentMode.label,
                    ),
                    if (order.tokenNumber != null)
                      _DetailRow(
                        label: 'Token',
                        value: '${order.tokenNumber}',
                      ),
                    if (handledBy != null && handledBy.isNotEmpty)
                      _DetailRow(label: 'Handled by', value: handledBy),
                  ],
                ),
                const SizedBox(height: 24),
                const _SectionLabel('Status'),
                _GroupedCard(children: [_StatusTimeline(order: order)]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.order, required this.itemCount});

  final CanteenOrder order;
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return _GroupedCard(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              OrderNumberStatusBadge(order: order, width: 96, height: 44),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatCurrency(order.total),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                        color: p.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$itemCount ${itemCount == 1 ? 'item' : 'items'}'
                      ' · ${order.fulfilmentMode.label}',
                      style: TextStyle(color: p.inkSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
              OrderStatusGradientBadge(
                status: order.status,
                fontSize: 11,
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
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
}

/// An inset-grouped card: rows separated by hairlines, no row borders.
class _GroupedCard extends StatelessWidget {
  const _GroupedCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, indent: 16, color: p.divider),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.line});

  final CartLine line;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: MenuItemArt(item: line.item, size: 40),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: p.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${line.quantity} × ${formatCurrency(line.item.price)}',
                  style: TextStyle(color: p.inkSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            formatCurrency(line.total),
            style: TextStyle(fontWeight: FontWeight.w600, color: p.ink),
          ),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({required this.total});

  final double total;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Total',
              style: TextStyle(fontWeight: FontWeight.w700, color: p.ink),
            ),
          ),
          Text(
            formatCurrency(total),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: p.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: p.inkSecondary)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(color: p.ink, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

/// The steps the order has been through. Only the time it was placed is on
/// record, so later steps show that they happened, not when.
class _StatusTimeline extends StatelessWidget {
  const _StatusTimeline({required this.order});

  final CanteenOrder order;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final placed = order.createdAt.toLocal();
    final status = order.status;
    final stopped =
        status == CanteenOrderStatus.rejected ||
        status == CanteenOrderStatus.cancelled;

    // Instant orders go straight from placed to delivered.
    final flow = <CanteenOrderStatus>[
      CanteenOrderStatus.pending,
      if (!order.isInstantOrder) ...[
        CanteenOrderStatus.preparing,
        CanteenOrderStatus.ready,
      ],
      CanteenOrderStatus.completed,
    ];
    int rank(CanteenOrderStatus s) => switch (s) {
      CanteenOrderStatus.pending || CanteenOrderStatus.accepted => 0,
      CanteenOrderStatus.preparing => 1,
      CanteenOrderStatus.ready => 2,
      CanteenOrderStatus.completed => 3,
      _ => 0,
    };
    final reached = rank(status);

    final steps = <_Step>[
      for (final step in flow)
        if (!stopped || step == CanteenOrderStatus.pending)
          _Step(
            label: step == CanteenOrderStatus.pending
                ? 'Placed'
                : OrderStatusGradients.labelForStatus(step),
            detail: step == CanteenOrderStatus.pending
                ? '${formatShortDate(placed)}, ${formatTime(placed)}'
                : null,
            done: stopped || rank(step) <= reached,
            current: !stopped && rank(step) == reached,
            color: step == CanteenOrderStatus.pending
                ? p.brandInk
                : OrderStatusGradients.forStatus(step).colors.first,
          ),
      if (stopped)
        _Step(
          label: status.label,
          done: true,
          current: true,
          color: p.danger,
        ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Column(
        children: [
          for (var i = 0; i < steps.length; i++)
            _StepRow(step: steps[i], last: i == steps.length - 1),
        ],
      ),
    );
  }
}

class _Step {
  const _Step({
    required this.label,
    required this.done,
    required this.current,
    required this.color,
    this.detail,
  });

  final String label;
  final String? detail;
  final bool done;
  final bool current;
  final Color color;
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step, required this.last});

  final _Step step;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final dotColor = step.done ? step.color : p.borderStrong;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 20,
            child: Column(
              children: [
                const SizedBox(height: 3),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: step.done ? dotColor : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(color: dotColor, width: 2),
                  ),
                ),
                if (!last)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      color: step.done ? dotColor.withValues(alpha: 0.4) : p.border,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.label,
                    style: TextStyle(
                      color: step.done ? p.ink : p.inkTertiary,
                      fontWeight:
                          step.current ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  if (step.detail != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      step.detail!,
                      style: TextStyle(color: p.inkSecondary, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
