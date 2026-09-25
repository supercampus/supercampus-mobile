import 'package:flutter/material.dart';

/// A 1-second animated brand logo reveal shown over the first rendered frame.
///
/// Features a pure white canvas, animated hero logo reveal in the center,
/// and signature 'SuperCampus' script branding at the bottom.
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
      duration: const Duration(milliseconds: 1000),
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
        if (value >= 1.0) return const SizedBox.shrink();

        // 0.0 -> 0.40: Logo smooth scale & fade-in reveal
        final revealProgress = Curves.easeOutCubic.transform(
          (value / 0.40).clamp(0.0, 1.0),
        );
        final logoScale = 0.85 + (0.15 * revealProgress);
        final logoOpacity = revealProgress;

        // 0.15 -> 0.50: Bottom signature text fades in
        final textOpacity = Curves.easeOut.transform(
          ((value - 0.15) / 0.35).clamp(0.0, 1.0),
        );

        // 0.75 -> 1.0: Whole intro gracefully dissolves as app opens
        final exitProgress = Curves.easeInOutCubic.transform(
          ((value - 0.75) / 0.25).clamp(0.0, 1.0),
        );
        final totalOpacity = (1.0 - exitProgress).clamp(0.0, 1.0);

        return IgnorePointer(
          ignoring: value >= 0.75,
          child: Opacity(
            opacity: totalOpacity,
            child: ColoredBox(
              color: Colors.white,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Center(
                    child: Transform.scale(
                      scale: logoScale,
                      child: Opacity(
                        opacity: logoOpacity,
                        child: SizedBox(
                          width: 146,
                          height: 126,
                          child: Image.asset(
                            'assets/branding/supercampus_mark_hero_hd.png',
                            fit: BoxFit.contain,
                            semanticLabel: 'SuperCampus Logo',
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 48,
                    left: 0,
                    right: 0,
                    child: Opacity(
                      opacity: textOpacity,
                      child: const Text(
                        'SuperCampus',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Brittany',
                          fontSize: 26,
                          color: Color(0xFF18181B),
                          height: 1.1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
