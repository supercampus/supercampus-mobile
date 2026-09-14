import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A short, one-shot brand moment shown over the first rendered frame.
///
/// The approved artwork stays at a fixed size throughout. Motion is provided
/// by the orbit, light sweep and text reveal around it, so the logo is never
/// cropped or subjected to a zoom animation.
class LaunchBrandIntro extends StatefulWidget {
  const LaunchBrandIntro({super.key});

  @override
  State<LaunchBrandIntro> createState() => _LaunchBrandIntroState();
}

class _LaunchBrandIntroState extends State<LaunchBrandIntro>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1900),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final value = _controller.value;
        final exit = Curves.easeInCubic.transform(
          ((value - 0.84) / 0.16).clamp(0.0, 1.0),
        );
        final reveal = Curves.easeOutCubic.transform(
          (value / 0.42).clamp(0.0, 1.0),
        );
        final tagline = Curves.easeOutBack.transform(
          ((value - 0.38) / 0.32).clamp(0.0, 1.0),
        );

        return IgnorePointer(
          ignoring: value >= 0.98,
          child: Opacity(
            opacity: 1 - exit,
            child: Transform.translate(
              offset: Offset(0, -18 * exit),
              child: ColoredBox(
                color: const Color(0xFF5712F4),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CustomPaint(painter: _LaunchEnergyPainter(value)),
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 224,
                            height: 224,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(42),
                              child: Image.asset(
                                'assets/branding/supercampus_app_icon.png',
                                fit: BoxFit.contain,
                                semanticLabel: 'SuperCampus',
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),
                          ClipRect(
                            child: Align(
                              heightFactor: reveal.clamp(0.001, 1.0),
                              alignment: Alignment.bottomCenter,
                              child: const Text(
                                'SuperCampus',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'Poppins',
                                  fontSize: 24,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 7),
                          Transform.translate(
                            offset: Offset(0, 12 * (1 - tagline)),
                            child: Opacity(
                              opacity: tagline.clamp(0.0, 1.0),
                              child: const Text(
                                'the one stop for campus application',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Color(0xFFE9DEFF),
                                  fontFamily: 'Poppins',
                                  fontSize: 9,
                                  fontWeight: FontWeight.w400,
                                  letterSpacing: 0.35,
                                ),
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
          ),
        );
      },
    );
  }
}

class _LaunchEnergyPainter extends CustomPainter {
  const _LaunchEnergyPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero) - const Offset(0, 42);
    final orbitProgress = Curves.easeInOutCubic.transform(progress);
    final orbitPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.white.withValues(alpha: 0.16);
    for (var index = 0; index < 3; index++) {
      final radius = 128.0 + index * 28;
      final start = -math.pi / 2 + orbitProgress * math.pi * (1.4 + index * .2);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        math.pi * (0.36 + index * 0.08),
        false,
        orbitPaint,
      );
    }

    final sweepX = (progress * 1.8 - 0.4) * size.width;
    final sweep = Path()
      ..moveTo(sweepX - 120, 0)
      ..lineTo(sweepX + 28, 0)
      ..lineTo(sweepX - 150, size.height)
      ..lineTo(sweepX - 298, size.height)
      ..close();
    canvas.drawPath(
      sweep,
      Paint()
        ..shader = const LinearGradient(
          colors: [Colors.transparent, Color(0x2EFFFFFF), Colors.transparent],
        ).createShader(Rect.fromLTWH(sweepX - 300, 0, 330, size.height)),
    );
  }

  @override
  bool shouldRepaint(_LaunchEnergyPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
