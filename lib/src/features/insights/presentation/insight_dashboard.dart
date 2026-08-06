import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/access/effective_permissions.dart';
import '../../../core/theme/app_theme.dart';
import '../data/insight.dart';
import '../data/insight_engine.dart';
import '../data/mock_insight_feed.dart';
import '../data/sources/attendance_headroom_source.dart';
import '../data/sources/wallet_balance_source.dart';

/// Rotating insight surface for the upper half of the dashboard.
///
/// Ranked on-device by [InsightEngine] — no model, no network, no third
/// party. Cards cross-fade on a timer and re-rank whenever the feed emits new
/// data, so the surface reflects the current state rather than a snapshot.
class InsightDashboard extends StatefulWidget {
  const InsightDashboard({
    super.key,
    required this.permissions,
    this.feed = const MockInsightFeed(),
    this.rotation = const Duration(seconds: 6),
  });

  final EffectivePermissions permissions;
  final InsightFeed feed;
  final Duration rotation;

  @override
  State<InsightDashboard> createState() => _InsightDashboardState();
}

class _InsightDashboardState extends State<InsightDashboard> {
  final _engine = InsightEngine(
    sources: const [AttendanceHeadroomSource(), WalletBalanceSource()],
  );

  StreamSubscription<InsightContext>? _subscription;
  Timer? _rotationTimer;

  List<Insight> _insights = const [];
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _subscription = widget.feed.watch().listen(_onContext);
    _restartRotation();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _rotationTimer?.cancel();
    super.dispose();
  }

  void _onContext(InsightContext context) {
    final ranked = _engine.rank(context, widget.permissions);
    if (!mounted) return;
    setState(() {
      _insights = ranked;
      if (_index >= ranked.length) _index = 0;
    });
    _markCurrentShown();
  }

  void _restartRotation() {
    _rotationTimer?.cancel();
    _rotationTimer = Timer.periodic(widget.rotation, (_) => _advance());
  }

  void _advance() {
    if (_insights.length < 2) return;
    setState(() => _index = (_index + 1) % _insights.length);
    _markCurrentShown();
  }

  void _markCurrentShown() {
    if (_index < _insights.length) _engine.markShown(_insights[_index]);
  }

  @override
  Widget build(BuildContext context) {
    if (_insights.isEmpty) return const _InsightSkeleton();

    final index = _index.clamp(0, _insights.length - 1);
    final insight = _insights[index];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: GestureDetector(
        // Tapping moves on early; the timer restarts so the next card still
        // gets its full dwell.
        onTap: () {
          _advance();
          _restartRotation();
        },
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 460),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.07),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          child: _InsightCard(
            key: ValueKey('${insight.sourceId}:${insight.signature}'),
            insight: insight,
            total: _insights.length,
            active: index,
          ),
        ),
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({
    super.key,
    required this.insight,
    required this.total,
    required this.active,
  });

  final Insight insight;
  final int total;
  final int active;

  @override
  Widget build(BuildContext context) {
    final accent = _accent(insight.tone);
    final metric = insight.metric;

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF181C24), Color(0xFF272E3D)],
          ),
        ),
        child: Stack(
          children: [
            // Soft accent bloom behind the gauge, and a hairline ring for
            // depth — cheap decoration, no blur pass.
            Positioned(
              right: -54,
              top: -66,
              child: Container(
                width: 210,
                height: 210,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      accent.withValues(alpha: 0.34),
                      accent.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: -70,
              bottom: -90,
              child: Container(
                width: 190,
                height: 190,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.05),
                    width: 1.2,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Eyebrow(
                    icon: insight.icon,
                    label: _label(insight.sourceId),
                    accent: accent,
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                insight.headline,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w500,
                                  height: 1.22,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (insight.supporting != null) ...[
                                const SizedBox(height: 7),
                                Text(
                                  insight.supporting!,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.55),
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w300,
                                    height: 1.35,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (metric != null) ...[
                          const SizedBox(width: 16),
                          _Gauge(metric: metric, accent: accent),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _Segments(total: total, active: active, accent: accent),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Brightened tone colours — the light-canvas palette is unreadable on a
  /// dark surface.
  Color _accent(InsightTone tone) => switch (tone) {
    InsightTone.positive => const Color(0xFF44D07B),
    InsightTone.caution => const Color(0xFFFFB84D),
    InsightTone.urgent => const Color(0xFFFF6B6B),
    InsightTone.neutral => const Color(0xFF6FD3FF),
  };

  String _label(String sourceId) => switch (sourceId) {
    'attendance_headroom' => 'Attendance',
    'wallet_balance' => 'Canteen wallet',
    _ => 'Today',
  };
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow({
    required this.icon,
    required this.label,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 14, color: accent),
        ),
        const SizedBox(width: 9),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.62),
            fontSize: 10.5,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.3,
          ),
        ),
      ],
    );
  }
}

class _Gauge extends StatelessWidget {
  const _Gauge({required this.metric, required this.accent});

  final InsightMetric metric;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    // Sweeps to the new value whenever the card changes, then settles — a
    // one-shot tween rather than a repeating animation.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: metric.value.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => SizedBox(
        width: 86,
        height: 86,
        child: CustomPaint(
          painter: _GaugePainter(value: value, accent: accent),
          child: Center(
            child: Text(
              metric.label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  const _GaugePainter({required this.value, required this.accent});

  final double value;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 7.0;
    final arcRect = (Offset.zero & size).deflate(stroke / 2);

    canvas.drawArc(
      arcRect,
      0,
      2 * math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = Colors.white.withValues(alpha: 0.10),
    );

    canvas.drawArc(
      arcRect,
      -math.pi / 2,
      2 * math.pi * value,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: -math.pi / 2,
          endAngle: 3 * math.pi / 2,
          colors: [accent.withValues(alpha: 0.45), accent],
        ).createShader(arcRect),
    );
  }

  @override
  bool shouldRepaint(_GaugePainter oldDelegate) =>
      oldDelegate.value != value || oldDelegate.accent != accent;
}

class _Segments extends StatelessWidget {
  const _Segments({
    required this.total,
    required this.active,
    required this.accent,
  });

  final int total;
  final int active;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    if (total < 2) return const SizedBox(height: 4);

    return Row(
      children: [
        for (var i = 0; i < total; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.only(right: 6),
            width: i == active ? 26 : 10,
            height: 4,
            decoration: BoxDecoration(
              color: i == active
                  ? accent
                  : Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
      ],
    );
  }
}

class _InsightSkeleton extends StatelessWidget {
  const _InsightSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF181C24), Color(0xFF272E3D)],
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.2)),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}
