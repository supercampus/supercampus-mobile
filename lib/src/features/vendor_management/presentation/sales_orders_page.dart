part of 'vendor_management_shell.dart';

/// Which orders the Orders tab lists.
@immutable
class _OrderQuery {
  const _OrderQuery({
    this.period = SalesPeriod.week,
    this.status = OrderStatusFilter.all,
    this.shopKey,
  });

  final SalesPeriod period;
  final OrderStatusFilter status;
  final String? shopKey;

  _OrderQuery copyWith({
    SalesPeriod? period,
    OrderStatusFilter? status,
    String? Function()? shopKey,
  }) => _OrderQuery(
    period: period ?? this.period,
    status: status ?? this.status,
    shopKey: shopKey == null ? this.shopKey : shopKey(),
  );

  @override
  bool operator ==(Object other) =>
      other is _OrderQuery &&
      other.period == period &&
      other.status == status &&
      other.shopKey == shopKey;

  @override
  int get hashCode => Object.hash(period, status, shopKey);
}

class _SalesOrdersPage extends StatefulWidget {
  const _SalesOrdersPage({
    required this.repository,
    required this.query,
    required this.onQueryChanged,
    required this.stores,
  });

  final VendorRepository repository;
  final _OrderQuery query;
  final ValueChanged<_OrderQuery> onQueryChanged;

  /// Shops to filter by, as the dashboard last reported them.
  final List<StoreSales> stores;

  @override
  State<_SalesOrdersPage> createState() => _SalesOrdersPageState();
}

class _SalesOrdersPageState extends State<_SalesOrdersPage> {
  SalesOrderPage? _page;
  Object? _error;
  bool _loading = true;
  int _request = 0;

  static const _limit = 100;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _SalesOrdersPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query) _load();
  }

  Future<void> _load() async {
    final request = ++_request;
    final query = widget.query;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await widget.repository.listSalesOrders(
        period: query.period,
        shopKey: query.shopKey,
        status: query.status,
        limit: _limit,
      );
      if (!mounted || request != _request) return;
      setState(() {
        _page = page;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || request != _request) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  String _storeLabel(String? shopKey) {
    if (shopKey == null) return 'All stores';
    for (final store in widget.stores) {
      if (store.shopKey == shopKey) return store.name;
    }
    return shopKey;
  }

  Future<void> _pickStore() async {
    final p = context.palette;
    final picked = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheet) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
        children: [
          for (final option in [
            (key: '', name: 'All stores', category: ''),
            for (final s in widget.stores)
              (key: s.shopKey, name: s.name, category: s.category),
          ])
            ListTile(
              leading: option.key.isEmpty
                  ? Icon(Icons.storefront_rounded, color: p.inkSecondary)
                  : _ShopAvatar(option.category, size: 32),
              title: Text(option.name),
              trailing: (widget.query.shopKey ?? '') == option.key
                  ? Icon(Icons.check_rounded, color: p.brandInk)
                  : null,
              onTap: () => Navigator.pop(sheet, option.key),
            ),
        ],
      ),
    );
    if (picked == null || !mounted) return;
    widget.onQueryChanged(
      widget.query.copyWith(shopKey: () => picked.isEmpty ? null : picked),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final query = widget.query;
    final page = _page;
    final error = _error;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(
            children: [
              _Segments<SalesPeriod>(
                values: SalesPeriod.values,
                selected: query.period,
                label: (period) => switch (period) {
                  SalesPeriod.today => 'Today',
                  SalesPeriod.week => 'Week',
                  SalesPeriod.month => 'Month',
                  SalesPeriod.all => 'All time',
                },
                onChanged: (period) =>
                    widget.onQueryChanged(query.copyWith(period: period)),
              ),
              const SizedBox(height: 8),
              _Segments<OrderStatusFilter>(
                values: OrderStatusFilter.values,
                selected: query.status,
                label: (status) => status.label,
                onChanged: (status) =>
                    widget.onQueryChanged(query.copyWith(status: status)),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: ActionChip(
                  avatar: Icon(
                    Icons.storefront_rounded,
                    size: 16,
                    color: query.shopKey == null ? p.inkSecondary : p.brandInk,
                  ),
                  label: Text(_storeLabel(query.shopKey)),
                  onPressed: widget.stores.isEmpty ? null : _pickStore,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 3,
          child: _loading && page != null
              ? const LinearProgressIndicator(minHeight: 2)
              : null,
        ),
        Expanded(child: _body(context, page, error)),
      ],
    );
  }

  Widget _body(BuildContext context, SalesOrderPage? page, Object? error) {
    final p = context.palette;
    if (page == null) {
      if (error != null) {
        return _loadFailure(error, _load, "You don't have access to orders.");
      }
      return const Center(child: CircularProgressIndicator());
    }
    if (page.orders.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: [
            const SizedBox(height: 60),
            _MessageState(
              icon: Icons.receipt_long_outlined,
              title: 'No orders',
              message: widget.query == const _OrderQuery()
                  ? 'Nothing has been ordered from campus shops this week.'
                  : 'No orders match these filters.',
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        itemCount: page.orders.length + 1,
        separatorBuilder: (_, i) =>
            i == 0 ? const SizedBox(height: 4) : Divider(height: 1, color: p.divider),
        itemBuilder: (context, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                page.total > page.orders.length
                    ? 'Newest ${formatCount(page.orders.length)} of ${formatCount(page.total)} orders'
                    : '${formatCount(page.total)} order${page.total == 1 ? '' : 's'}',
                style: TextStyle(fontSize: 12.5, color: p.inkSecondary),
              ),
            );
          }
          final order = page.orders[i - 1];
          return _OrderRow(
            order: order,
            onTap: () => _showOrder(context, order),
          );
        },
      ),
    );
  }
}

String _orderTime(DateTime? at) {
  if (at == null) return '';
  final local = at.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  final time = DateFormat('h:mm a').format(local).toLowerCase();
  if (day == today) return 'Today, $time';
  if (day == today.subtract(const Duration(days: 1))) return 'Yesterday, $time';
  if (local.year == now.year) return '${DateFormat('d MMM').format(local)}, $time';
  return '${DateFormat('d MMM yyyy').format(local)}, $time';
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.order, required this.onTap});

  final SalesOrder order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            _ShopAvatar(order.category, size: 38),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.customerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: p.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${order.reference} · ${order.storeName} · ${_orderTime(order.createdAt)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, color: p.inkSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatRupees(order.total),
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: order.statusBucket == OrderStatusFilter.cancelled
                        ? p.inkTertiary
                        : p.ink,
                    decoration: order.statusBucket == OrderStatusFilter.cancelled
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                const SizedBox(height: 4),
                _statusPill(context, order.statusBucket, order.statusLabel),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

void _showOrder(BuildContext context, SalesOrder order) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheet) => _OrderDetailSheet(order: order),
  );
}

class _OrderDetailSheet extends StatelessWidget {
  const _OrderDetailSheet({required this.order});

  final SalesOrder order;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.92,
      minChildSize: 0.35,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
        children: [
          const _SheetHandle(),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.isLaundry ? 'Laundry charge' : 'Order ${order.reference}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                        color: p.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      order.storeName,
                      style: TextStyle(fontSize: 13.5, color: p.inkSecondary),
                    ),
                  ],
                ),
              ),
              _statusPill(context, order.statusBucket, order.statusLabel),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: p.surfaceSunken,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                for (final line in order.lines)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            line.name,
                            style: TextStyle(fontSize: 14, color: p.ink),
                          ),
                        ),
                        Text(
                          formatQuantity(line.quantity, line.unitLabel),
                          style: TextStyle(fontSize: 13, color: p.inkSecondary),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 76,
                          child: Text(
                            line.lineTotal == null ? '' : formatRupees(line.lineTotal!),
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: p.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Divider(height: 1, color: p.divider),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Total',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: p.ink,
                          ),
                        ),
                      ),
                      Text(
                        formatRupees(order.total),
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: p.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _DetailRow('Customer', order.customerName),
          _DetailRow('Placed', _orderTime(order.createdAt)),
          if (order.updatedAt != null && order.updatedAt != order.createdAt)
            _DetailRow('Last update', _orderTime(order.updatedAt)),
          if (order.fulfilmentLabel != null)
            _DetailRow('Fulfilment', order.fulfilmentLabel!),
          if (order.tokenNumber != null)
            _DetailRow('Token', '${order.tokenNumber}'),
          if (order.rejectionReason != null && order.rejectionReason!.isNotEmpty)
            _DetailRow('Reason', order.rejectionReason!),
          if (order.statusBucket == OrderStatusFilter.cancelled &&
              order.status == 'rejected')
            _DetailRow('Payment', 'Refunded to the wallet'),
        ],
      ),
    );
  }
}
