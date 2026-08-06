import 'dart:async';

import 'insight.dart';

/// Stand-in for the live data the engine will eventually watch.
///
/// The real implementation merges streams from the canteen, attendance and
/// timetable repositories — which are all `Future`-based today, so they need
/// to expose `Stream`s before this can be swapped in. The contract stays the
/// same: emit a fresh [InsightContext] whenever anything a source reads has
/// changed, and the engine re-ranks.
abstract interface class InsightFeed {
  Stream<InsightContext> watch();
}

class MockInsightFeed implements InsightFeed {
  const MockInsightFeed();

  @override
  Stream<InsightContext> watch() {
    var attended = 82;
    var total = 100;
    var balance = 240.0;
    var tick = 0;

    Timer? timer;
    late final StreamController<InsightContext> controller;

    InsightContext snapshot() => InsightContext(
      now: DateTime.now(),
      attendance: AttendanceSnapshot(attended: attended, total: total),
      walletBalance: balance,
    );

    // A StreamController rather than `async*` with `Stream.periodic`: cancel
    // has to stop the timer synchronously, otherwise it outlives the widget
    // that owns the subscription.
    controller = StreamController<InsightContext>(
      onListen: () {
        controller.add(snapshot());

        // Simulated activity so the re-ranking is visible while developing:
        // classes tick by and lunch gets bought.
        timer = Timer.periodic(const Duration(seconds: 12), (_) {
          tick++;
          if (tick.isEven) {
            total += 1;
            // Every fourth class is a miss, so the buffer erodes over time.
            if (tick % 4 != 0) attended += 1;
          } else {
            balance = (balance - 45).clamp(0.0, 5000.0);
          }
          controller.add(snapshot());
        });
      },
      onCancel: () {
        timer?.cancel();
        timer = null;
      },
    );

    return controller.stream;
  }
}
