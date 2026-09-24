import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/utils/formatters.dart';
import '../data/canteen_models.dart';
import 'widgets/order_delivered_view.dart';

/// Palette theme definitions derived from the attached brand guidelines:
/// - Pantone 381 C: Lime Green (#C6FF00)
/// - Pantone 2665 C: Neon Violet / Purple (#7B42F6)
/// - Pantone 212 C: Hot Pink (#FF2D95)
/// - Pantone 1495 C: Radiant Orange (#FF6F20)
/// - Pantone 7442 C: Vivid Violet (#9D4EDD)
/// - Neon Violet (#9D4EDD) & Electric Cyan (#00F5D4)
/// - Radiant Rush: Hot Pink (#FF2D95), Bright Orange (#FF6F20), Electric Yellow (#FFEA00)
/// - Minimalist White and Deep Charcoal/Black backgrounds from mockup 1 & 3
class OrderPlacedTheme {
  const OrderPlacedTheme({
    required this.name,
    required this.backgroundColor,
    required this.qrColor,
    required this.accentColor,
    required this.textColor,
    required this.subtextColor,
    required this.cardBackgroundColor,
    required this.cardBorderColor,
    required this.buttonColor,
    required this.buttonTextColor,
    this.isDark = false,
  });

  final String name;
  final Color backgroundColor;
  final Color qrColor;
  final Color accentColor;
  final Color textColor;
  final Color subtextColor;
  final Color cardBackgroundColor;
  final Color cardBorderColor;
  final Color buttonColor;
  final Color buttonTextColor;
  final bool isDark;

  static const List<OrderPlacedTheme> palette = [
    // 1. Classic Light - Neon Violet (Mockup 1 & 2 from user image)
    OrderPlacedTheme(
      name: 'Classic Violet Light',
      backgroundColor: Colors.white,
      qrColor: Color(0xFF7B42F6),
      accentColor: Color(0xFF7B42F6),
      textColor: Color(0xFF18171D),
      subtextColor: Color(0xFF6B7280),
      cardBackgroundColor: Color(0xFFF7F7F8),
      cardBorderColor: Color(0xFFE5E7EB),
      buttonColor: Color(0xFF7B42F6),
      buttonTextColor: Colors.white,
      isDark: false,
    ),
    // 2. Midnight Dark - Neon Violet (Mockup 3 & 4 from user image)
    OrderPlacedTheme(
      name: 'Neon Violet Dark',
      backgroundColor: Color(0xFF000000),
      qrColor: Color(0xFF9D4EDD),
      accentColor: Color(0xFF9D4EDD),
      textColor: Colors.white,
      subtextColor: Color(0xFF9CA3AF),
      cardBackgroundColor: Color(0xFF18181C),
      cardBorderColor: Color(0xFF27272A),
      buttonColor: Color(0xFF7B42F6),
      buttonTextColor: Colors.white,
      isDark: true,
    ),
    // 3. Electric Cyan Dark (Image 4 #00F5D4)
    OrderPlacedTheme(
      name: 'Electric Cyan Dark',
      backgroundColor: Color(0xFF0D0D12),
      qrColor: Color(0xFF00F5D4),
      accentColor: Color(0xFF00F5D4),
      textColor: Colors.white,
      subtextColor: Color(0xFFA1A1AA),
      cardBackgroundColor: Color(0xFF1E1E24),
      cardBorderColor: Color(0xFF2D2D36),
      buttonColor: Color(0xFF00F5D4),
      buttonTextColor: Color(0xFF0D0D12),
      isDark: true,
    ),
    // 4. Hot Pink Light (Image 2 & 5 #FF2D95)
    OrderPlacedTheme(
      name: 'Hot Pink Light',
      backgroundColor: Colors.white,
      qrColor: Color(0xFFFF2D95),
      accentColor: Color(0xFFFF2D95),
      textColor: Color(0xFF18171D),
      subtextColor: Color(0xFF6B7280),
      cardBackgroundColor: Color(0xFFFFF1F7),
      cardBorderColor: Color(0xFFFFD6E7),
      buttonColor: Color(0xFFFF2D95),
      buttonTextColor: Colors.white,
      isDark: false,
    ),
    // 5. Hot Pink Dark (Image 2 & 5 #FF2D95)
    OrderPlacedTheme(
      name: 'Hot Pink Dark',
      backgroundColor: Color(0xFF0F080C),
      qrColor: Color(0xFFFF2D95),
      accentColor: Color(0xFFFF2D95),
      textColor: Colors.white,
      subtextColor: Color(0xFFA1A1AA),
      cardBackgroundColor: Color(0xFF22121B),
      cardBorderColor: Color(0xFF381B2B),
      buttonColor: Color(0xFFFF2D95),
      buttonTextColor: Colors.white,
      isDark: true,
    ),
    // 6. Lime Green Dark (Image 2 & 3 #C6FF00)
    OrderPlacedTheme(
      name: 'Lime Green Dark',
      backgroundColor: Color(0xFF0A0E0A),
      qrColor: Color(0xFFC6FF00),
      accentColor: Color(0xFFC6FF00),
      textColor: Colors.white,
      subtextColor: Color(0xFFA1A1AA),
      cardBackgroundColor: Color(0xFF161E16),
      cardBorderColor: Color(0xFF273827),
      buttonColor: Color(0xFFC6FF00),
      buttonTextColor: Color(0xFF0A0E0A),
      isDark: true,
    ),
    // 7. Radiant Orange Light (Image 2 & 5 #FF6F20)
    OrderPlacedTheme(
      name: 'Radiant Orange Light',
      backgroundColor: Colors.white,
      qrColor: Color(0xFFFF6F20),
      accentColor: Color(0xFFFF6F20),
      textColor: Color(0xFF18171D),
      subtextColor: Color(0xFF6B7280),
      cardBackgroundColor: Color(0xFFFFF7F2),
      cardBorderColor: Color(0xFFFFE2D1),
      buttonColor: Color(0xFFFF6F20),
      buttonTextColor: Colors.white,
      isDark: false,
    ),
    // 8. Radiant Orange Dark (Image 2 & 5 #FF6F20)
    OrderPlacedTheme(
      name: 'Radiant Orange Dark',
      backgroundColor: Color(0xFF120B07),
      qrColor: Color(0xFFFF6F20),
      accentColor: Color(0xFFFF6F20),
      textColor: Colors.white,
      subtextColor: Color(0xFFA1A1AA),
      cardBackgroundColor: Color(0xFF22160F),
      cardBorderColor: Color(0xFF3B2317),
      buttonColor: Color(0xFFFF6F20),
      buttonTextColor: Colors.white,
      isDark: true,
    ),
    // 9. Electric Yellow Dark (Image 5 #FFEA00)
    OrderPlacedTheme(
      name: 'Electric Yellow Dark',
      backgroundColor: Color(0xFF0F0F08),
      qrColor: Color(0xFFFFEA00),
      accentColor: Color(0xFFFFEA00),
      textColor: Colors.white,
      subtextColor: Color(0xFFA1A1AA),
      cardBackgroundColor: Color(0xFF212112),
      cardBorderColor: Color(0xFF3B3B1F),
      buttonColor: Color(0xFFFFEA00),
      buttonTextColor: Color(0xFF0F0F08),
      isDark: true,
    ),
    // 10. Neon Violet Surface + Electric Cyan QR (Image 4 pair)
    OrderPlacedTheme(
      name: 'Neon Violet & Cyan Pop',
      backgroundColor: Color(0xFF6E3FF3),
      qrColor: Color(0xFF00F5D4),
      accentColor: Color(0xFF00F5D4),
      textColor: Colors.white,
      subtextColor: Color(0xFFE0E7FF),
      cardBackgroundColor: Color(0x33000000),
      cardBorderColor: Color(0x33FFFFFF),
      buttonColor: Color(0xFF00F5D4),
      buttonTextColor: Color(0xFF18171D),
      isDark: true,
    ),
    // 11. Lime Pop Surface + Deep Purple QR (Image 2 pair)
    OrderPlacedTheme(
      name: 'Lime Pop & Deep Purple',
      backgroundColor: Color(0xFFC6FF00),
      qrColor: Color(0xFF4C1D95),
      accentColor: Color(0xFF4C1D95),
      textColor: Color(0xFF18171D),
      subtextColor: Color(0xFF374151),
      cardBackgroundColor: Color(0x1F000000),
      cardBorderColor: Color(0x28000000),
      buttonColor: Color(0xFF4C1D95),
      buttonTextColor: Colors.white,
      isDark: false,
    ),
    // 12. Hot Pink Surface + Electric Yellow QR (Image 5 Radiant Rush)
    OrderPlacedTheme(
      name: 'Radiant Rush Pop',
      backgroundColor: Color(0xFFFF2D95),
      qrColor: Color(0xFFFFEA00),
      accentColor: Color(0xFFFFEA00),
      textColor: Colors.white,
      subtextColor: Color(0xFFFFF0F5),
      cardBackgroundColor: Color(0x33000000),
      cardBorderColor: Color(0x44FFFFFF),
      buttonColor: Color(0xFFFFEA00),
      buttonTextColor: Color(0xFF18171D),
      isDark: true,
    ),
    // 13. Electric Cyan Surface + Deep Indigo QR (Image 4 pair)
    OrderPlacedTheme(
      name: 'Electric Cyan & Deep Indigo',
      backgroundColor: Color(0xFF00F5D4),
      qrColor: Color(0xFF3B0764),
      accentColor: Color(0xFF3B0764),
      textColor: Color(0xFF18171D),
      subtextColor: Color(0xFF1F2937),
      cardBackgroundColor: Color(0x1F000000),
      cardBorderColor: Color(0x25000000),
      buttonColor: Color(0xFF3B0764),
      buttonTextColor: Colors.white,
      isDark: false,
    ),
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
    if (_order.status == CanteenOrderStatus.completed) return;
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
        if (_order.status == CanteenOrderStatus.completed) {
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

  String get _formattedToken {
    if (_order.tokenNumber != null) {
      return '#${_order.tokenNumber.toString().padLeft(3, '0')}';
    }
    final digits = _order.displayId.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isNotEmpty) {
      final sub = digits.length > 3
          ? digits.substring(digits.length - 3)
          : digits.padLeft(3, '0');
      return '#$sub';
    }
    return '#001';
  }

  String get _formattedOrderId {
    final id = _order.orderNumber ?? _order.displayId;
    return id.startsWith('#') ? 'order id: $id' : 'order id: #$id';
  }

  @override
  Widget build(BuildContext context) {
    if (_order.status == CanteenOrderStatus.completed) {
      return SafeArea(
        child: Container(
          color: _theme.backgroundColor,
          child: OrderDeliveredView(
            order: _order,
            onDone: () => Navigator.of(context).pop(),
            compact: true,
          ),
        ),
      );
    }

    return Container(
      color: _theme.backgroundColor,
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
                      color: _theme.subtextColor,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Show this QR at the counter.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: _theme.subtextColor,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _shuffleTheme,
                    tooltip: 'Shuffle color theme',
                    icon: Icon(
                      Icons.palette_outlined,
                      size: 20,
                      color: _theme.subtextColor,
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
                            size: 220,
                            padding: EdgeInsets.zero,
                            eyeStyle: QrEyeStyle(
                              eyeShape: QrEyeShape.circle,
                              color: _theme.qrColor,
                            ),
                            dataModuleStyle: QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.circle,
                              color: _theme.qrColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Large bold token number (#001)
                        Text(
                          _formattedToken,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _theme.accentColor,
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
                            color: _theme.subtextColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Collapsible "ordered items" card
                        Material(
                          color: _theme.cardBackgroundColor,
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
                                    Border.all(color: _theme.cardBorderColor),
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
                                          color: _theme.textColor,
                                        ),
                                      ),
                                      Icon(
                                        _isItemsExpanded
                                            ? Icons.keyboard_arrow_up_rounded
                                            : Icons.keyboard_arrow_down_rounded,
                                        color: _theme.subtextColor,
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
                                                color: _theme.textColor,
                                              ),
                                            ),
                                            Text(
                                              formatCurrency(_order.total),
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                                color: _theme.textColor,
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
                                                  color: _theme.textColor,
                                                ),
                                              ),
                                              Text(
                                                formatCurrency(line.total),
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                  color: _theme.textColor,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    Divider(
                                      color: _theme.cardBorderColor,
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
                                            color: _theme.textColor,
                                          ),
                                        ),
                                        Text(
                                          formatCurrency(_order.total),
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                            color: _theme.textColor,
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
                    backgroundColor: _theme.buttonColor,
                    foregroundColor: _theme.buttonTextColor,
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
