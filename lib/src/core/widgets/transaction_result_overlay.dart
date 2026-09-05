import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

enum TransactionResult { success, failure }

Future<void> showTransactionResult(
  BuildContext context, {
  required TransactionResult result,
  required String title,
  String? message,
  String? amount,
  String? reference,
}) {
  return showGeneralDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, _, __) => _TransactionResultView(
      result: result,
      title: title,
      message: message,
      amount: amount,
      reference: reference,
    ),
    transitionBuilder: (context, animation, _, child) => FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: child,
    ),
  );
}

class _TransactionResultView extends StatefulWidget {
  const _TransactionResultView({
    required this.result,
    required this.title,
    this.message,
    this.amount,
    this.reference,
  });

  final TransactionResult result;
  final String title;
  final String? message;
  final String? amount;
  final String? reference;

  @override
  State<_TransactionResultView> createState() => _TransactionResultViewState();
}

class _TransactionResultViewState extends State<_TransactionResultView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _dismissTimer;

  bool get _successful => widget.result == TransactionResult.success;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1550),
    )..forward();
    _dismissTimer = Timer(const Duration(milliseconds: 2600), _close);
  }

  void _close() {
    if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = _successful
        ? const Color(0xFF16A269)
        : const Color(0xFFE24747);
    final deepAccent = _successful
        ? const Color(0xFF08794A)
        : const Color(0xFFB4232A);
    final background = _successful
        ? const Color(0xFFF4FBF7)
        : const Color(0xFFFFF7F7);
    final scale = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.05, 0.48, curve: Curves.elasticOut),
    );
    final details = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.42, 0.78, curve: Curves.easeOutCubic),
    );

    return Material(
      color: background,
      child: SafeArea(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.2),
                    radius: 1.05,
                    colors: [accent.withValues(alpha: 0.13), background],
                  ),
                ),
              ),
              IgnorePointer(
                child: CustomPaint(
                  painter: _CelebrationPainter(
                    progress: CurvedAnimation(
                      parent: _controller,
                      curve: const Interval(0.18, 0.9, curve: Curves.easeOut),
                    ).value,
                    color: accent,
                    successful: _successful,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 34, 28, 28),
                child: Column(
                  children: [
                    const Spacer(flex: 3),
                    ScaleTransition(
                      scale: scale,
                      child: _ResultMedallion(
                        progress: CurvedAnimation(
                          parent: _controller,
                          curve: const Interval(
                            0.24,
                            0.62,
                            curve: Curves.easeOutCubic,
                          ),
                        ).value,
                        color: accent,
                        deepColor: deepAccent,
                        successful: _successful,
                      ),
                    ),
                    const SizedBox(height: 34),
                    FadeTransition(
                      opacity: details,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.18),
                          end: Offset.zero,
                        ).animate(details),
                        child: Column(
                          children: [
                            if (widget.amount case final amount?) ...[
                              Text(
                                amount,
                                key: const ValueKey(
                                  'transaction-result-amount',
                                ),
                                style: TextStyle(
                                  color: deepAccent,
                                  fontSize: 34,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -1,
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            Text(
                              widget.title,
                              key: const ValueKey('transaction-result-title'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFF171A21),
                                fontSize: 25,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.35,
                              ),
                            ),
                            if (widget.message case final message?) ...[
                              const SizedBox(height: 10),
                              Text(
                                message,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xFF687080),
                                  fontSize: 15,
                                  height: 1.4,
                                ),
                              ),
                            ],
                            if (widget.reference case final reference?) ...[
                              const SizedBox(height: 18),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.75),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: accent.withValues(alpha: 0.16),
                                  ),
                                ),
                                child: Text(
                                  reference,
                                  style: const TextStyle(
                                    color: Color(0xFF687080),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const Spacer(flex: 4),
                    FadeTransition(
                      opacity: CurvedAnimation(
                        parent: _controller,
                        curve: const Interval(0.72, 1, curve: Curves.easeOut),
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton(
                          key: const ValueKey('transaction-result-done'),
                          style: FilledButton.styleFrom(
                            backgroundColor: deepAccent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: _close,
                          child: Text(_successful ? 'Done' : 'Try again'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultMedallion extends StatelessWidget {
  const _ResultMedallion({
    required this.progress,
    required this.color,
    required this.deepColor,
    required this.successful,
  });

  final double progress;
  final Color color;
  final Color deepColor;
  final bool successful;

  @override
  Widget build(BuildContext context) => Container(
    width: 146,
    height: 146,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white,
      boxShadow: [
        BoxShadow(
          color: color.withValues(alpha: 0.22),
          blurRadius: 42,
          spreadRadius: 8,
        ),
      ],
      border: Border.all(color: color.withValues(alpha: 0.18), width: 2),
    ),
    padding: const EdgeInsets.all(22),
    child: DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, deepColor],
        ),
      ),
      child: CustomPaint(
        key: ValueKey(successful ? 'animated-check' : 'animated-cross'),
        painter: _ResultMarkPainter(progress: progress, success: successful),
      ),
    ),
  );
}

class _ResultMarkPainter extends CustomPainter {
  const _ResultMarkPainter({required this.progress, required this.success});

  final double progress;
  final bool success;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final path = Path();
    if (success) {
      path
        ..moveTo(size.width * 0.25, size.height * 0.52)
        ..lineTo(size.width * 0.43, size.height * 0.69)
        ..lineTo(size.width * 0.76, size.height * 0.34);
    } else {
      path
        ..moveTo(size.width * 0.31, size.height * 0.31)
        ..lineTo(size.width * 0.69, size.height * 0.69)
        ..moveTo(size.width * 0.69, size.height * 0.31)
        ..lineTo(size.width * 0.31, size.height * 0.69);
    }
    for (final metric in path.computeMetrics()) {
      canvas.drawPath(metric.extractPath(0, metric.length * progress), paint);
    }
  }

  @override
  bool shouldRepaint(_ResultMarkPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.success != success;
}

class _CelebrationPainter extends CustomPainter {
  const _CelebrationPainter({
    required this.progress,
    required this.color,
    required this.successful,
  });

  final double progress;
  final Color color;
  final bool successful;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.34);
    final paint = Paint()..strokeCap = StrokeCap.round;
    final count = successful ? 18 : 10;
    for (var index = 0; index < count; index++) {
      final angle = (math.pi * 2 / count) * index - math.pi / 2;
      final stagger = (index % 4) * 0.035;
      final local = ((progress - stagger) / (1 - stagger)).clamp(0.0, 1.0);
      final radius = 82 + (118 * Curves.easeOutCubic.transform(local));
      final point = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      paint
        ..color = color.withValues(alpha: (1 - local) * 0.55)
        ..strokeWidth = index.isEven ? 5 : 3;
      if (successful) {
        final tangent = Offset(-math.sin(angle), math.cos(angle)) * 5;
        canvas.drawLine(point - tangent, point + tangent, paint);
      } else {
        canvas.drawCircle(point, index.isEven ? 3 : 2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_CelebrationPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.successful != successful;
}
