import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/utils/formatters.dart';
import '../data/canteen_models.dart';
import 'widgets/order_delivered_view.dart';

/// The pickup screen is always drawn on white — the brightest, most reliable
/// background for a counter scanner — and only the QR colour changes. Every
/// colour here keeps enough contrast against white to scan.
class OrderPlacedTheme {
  const OrderPlacedTheme({required this.name, required this.qrColor});

  final String name;
  final Color qrColor;

  Color get backgroundColor => Colors.white;
  Color get accentColor => qrColor;
  Color get textColor => const Color(0xFF0A0A12);
  Color get subtextColor => const Color(0xFF6B7280);
  Color get cardBackgroundColor => qrColor.withValues(alpha: 0.06);
  Color get cardBorderColor => qrColor.withValues(alpha: 0.18);
  Color get buttonColor => qrColor;
  Color get buttonTextColor => Colors.white;

  static const List<OrderPlacedTheme> palette = [
    // The app accent palette, each stop darkened just enough to hold at
    // least 4.5:1 on white (QR scan + white button text).
    OrderPlacedTheme(name: 'Electric Purple', qrColor: Color(0xFF7B42F6)),
    OrderPlacedTheme(name: 'Hot Pink', qrColor: Color(0xFFD6006B)),
    OrderPlacedTheme(name: 'Radiant Orange', qrColor: Color(0xFFC24700)),
    OrderPlacedTheme(name: 'Deep Purple', qrColor: Color(0xFF4B1FB8)),
    OrderPlacedTheme(name: 'Deep Magenta', qrColor: Color(0xFFB8005C)),
    OrderPlacedTheme(name: 'Neon Violet', qrColor: Color(0xFF9D4EDD)),
    OrderPlacedTheme(name: 'Deep Cyan', qrColor: Color(0xFF007A70)),
    OrderPlacedTheme(name: 'Electric Violet', qrColor: Color(0xFF9B1FE8)),
    OrderPlacedTheme(name: 'Deep Void', qrColor: Color(0xFF0A0A12)),
  ];

  static OrderPlacedTheme random({String? seed}) {
    if (seed != null && seed.isNotEmpty) {
      final index = seed.hashCode.abs() % palette.length;
      return palette[index];
    }
    return palette[Random().nextInt(palette.length)];
  }
}

class OrderPickupSheet extends StatefulWidget {
  const OrderPickupSheet({
    super.key,
    required this.order,
    this.onRefresh,
    this.latestOrderFinder,
  });

  final CanteenOrder order;
  final Future<void> Function()? onRefresh;
  final CanteenOrder? Function()? latestOrderFinder;

  @override
  State<OrderPickupSheet> createState() => _OrderPickupSheetState();
}

class _OrderPickupSheetState extends State<OrderPickupSheet> {
  late CanteenOrder _order;
  late OrderPlacedTheme _theme;
  Timer? _timer;
  bool _isItemsExpanded = false;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    _theme = OrderPlacedTheme.random(seed: widget.order.id);
    _startPolling();
  }

  void _shuffleTheme() {
    setState(() {
      int nextIndex;
      do {
        nextIndex = Random().nextInt(OrderPlacedTheme.palette.length);
      } while (OrderPlacedTheme.palette[nextIndex].name == _theme.name &&
          OrderPlacedTheme.palette.length > 1);
      _theme = OrderPlacedTheme.palette[nextIndex];
    });
  }

  void _startPolling() {
    if (!_order.status.isActive) return;
    _timer = Timer.periodic(const Duration(milliseconds: 1500), (_) async {
      if (!mounted) return;
      if (widget.onRefresh != null) {
        try {
          await widget.onRefresh!();
        } catch (_) {}
      }
      if (!mounted) return;
      final latest = widget.latestOrderFinder?.call();
      if (latest != null && latest.status != _order.status) {
        setState(() {
          _order = latest;
        });
        if (!_order.status.isActive) {
          _timer?.cancel();
          _timer = null;
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Four digits, like the home status card: #0057.
  String get _formattedToken {
    if (_order.tokenNumber != null) {
      return '#${_order.tokenNumber.toString().padLeft(4, '0')}';
    }
    final digits = _order.displayId.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isNotEmpty) {
      final sub = digits.length > 4
          ? digits.substring(digits.length - 4)
          : digits.padLeft(4, '0');
      return '#$sub';
    }
    return '#0001';
  }

  String get _formattedOrderId {
    final id = _order.orderNumber ?? _order.displayId;
    return id.startsWith('#') ? 'order id: $id' : 'order id: #$id';
  }

  @override
  Widget build(BuildContext context) {
    final theme = _theme;
    // As large as the screen comfortably allows, so it scans from a distance.
    final qrSize =
        (MediaQuery.sizeOf(context).width - 72).clamp(220.0, 300.0).toDouble();
    // A settled order (delivered, rejected or cancelled) has nothing left to
    // scan, so it shows its outcome instead of the pickup QR.
    if (!_order.status.isActive) {
      return SafeArea(
        child: Container(
          color: theme.backgroundColor,
          child: OrderDeliveredView(
            order: _order,
            onDone: () => Navigator.of(context).pop(),
            compact: true,
          ),
        ),
      );
    }

    return Container(
      color: theme.backgroundColor,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            children: [
              // Top header row: "Show this QR at the counter." and subtle theme shuffle button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Close',
                    icon: Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: theme.subtextColor,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Show this QR at the counter.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: theme.subtextColor,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _shuffleTheme,
                    tooltip: 'Change QR colour',
                    icon: Icon(
                      Icons.palette_outlined,
                      size: 20,
                      color: theme.subtextColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Center content: QR, Token, Order ID, and Collapsible ordered items
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Stylized QR code with circular dots and circular eyes
                        Container(
                          padding: const EdgeInsets.all(8),
                          child: QrImageView(
                            data: _order.qrPayload ?? _order.id,
                            size: qrSize,
                            backgroundColor: Colors.white,
                            padding: EdgeInsets.zero,
                            eyeStyle: QrEyeStyle(
                              eyeShape: QrEyeShape.circle,
                              color: theme.qrColor,
                            ),
                            dataModuleStyle: QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.circle,
                              color: theme.qrColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Large bold token number (#0057)
                        Text(
                          _formattedToken,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: theme.accentColor,
                            fontSize: 42,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),

                        // Order ID
                        Text(
                          _formattedOrderId,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: theme.subtextColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Collapsible "ordered items" card
                        Material(
                          color: theme.cardBackgroundColor,
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => setState(
                              () => _isItemsExpanded = !_isItemsExpanded,
                            ),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeInOut,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border:
                                    Border.all(color: theme.cardBorderColor),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'ordered items',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: theme.textColor,
                                        ),
                                      ),
                                      Icon(
                                        _isItemsExpanded
                                            ? Icons.keyboard_arrow_up_rounded
                                            : Icons.keyboard_arrow_down_rounded,
                                        color: theme.subtextColor,
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                  if (_isItemsExpanded) ...[
                                    const SizedBox(height: 14),
                                    if (_order.lines.isEmpty)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 4,
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'Canteen order',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: theme.textColor,
                                              ),
                                            ),
                                            Text(
                                              formatCurrency(_order.total),
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                                color: theme.textColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    else
                                      for (final line in _order.lines)
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 4,
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                line.quantity > 1
                                                    ? '${line.item.name} x${line.quantity}'
                                                    : line.item.name,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: theme.textColor,
                                                ),
                                              ),
                                              Text(
                                                formatCurrency(line.total),
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                  color: theme.textColor,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    Divider(
                                      color: theme.cardBorderColor,
                                      height: 24,
                                    ),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Total',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                            color: theme.textColor,
                                          ),
                                        ),
                                        Text(
                                          formatCurrency(_order.total),
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                            color: theme.textColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Full-width pill "Done" button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.buttonColor,
                    foregroundColor: theme.buttonTextColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
