import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/core/widgets/swipe_action_card.dart';
import 'package:supercampus_mobile/src/features/canteen/data/canteen_models.dart';

Future<void> _pumpCard(
  WidgetTester tester, {
  required List<String> fired,
  bool forward = true,
  bool backward = true,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 400,
            child: SwipeActionCard(
              forward: forward
                  ? SwipeAction(
                      label: 'Preparing',
                      icon: Icons.local_fire_department_outlined,
                      color: const Color(0xFF2563EB),
                      onCommit: () => fired.add('forward'),
                    )
                  : null,
              backward: backward
                  ? SwipeAction(
                      label: 'Reject',
                      icon: Icons.close_rounded,
                      color: const Color(0xFFB42318),
                      onCommit: () => fired.add('backward'),
                    )
                  : null,
              child: const SizedBox(height: 90, child: Text('Order card')),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('swipe commits', () {
    testWidgets('a drag that stops short of the commit point does nothing', (
      tester,
    ) async {
      final fired = <String>[];
      await _pumpCard(tester, fired: fired);

      // 40px on a 400px card is a tenth of the way — well under the threshold.
      await tester.drag(find.text('Order card'), const Offset(40, 0));
      await tester.pumpAndSettle();

      expect(fired, isEmpty);
    });

    testWidgets('dragging well past the commit point fires the forward action', (
      tester,
    ) async {
      final fired = <String>[];
      await _pumpCard(tester, fired: fired);

      await tester.drag(find.text('Order card'), const Offset(220, 0));
      await tester.pumpAndSettle();

      expect(fired, ['forward']);
    });

    testWidgets('dragging left fires the reject action', (tester) async {
      final fired = <String>[];
      await _pumpCard(tester, fired: fired);

      await tester.drag(find.text('Order card'), const Offset(-220, 0));
      await tester.pumpAndSettle();

      expect(fired, ['backward']);
    });

    testWidgets('a short hard flick commits, because momentum is projected', (
      tester,
    ) async {
      final fired = <String>[];
      await _pumpCard(tester, fired: fired);

      // Too short to commit on distance alone; the throw is what carries it.
      await tester.fling(find.text('Order card'), const Offset(60, 0), 1200);
      await tester.pumpAndSettle();

      expect(fired, ['forward']);
    });

    testWidgets('a direction with no action attached cannot fire', (
      tester,
    ) async {
      final fired = <String>[];
      await _pumpCard(tester, fired: fired, forward: false);

      await tester.drag(find.text('Order card'), const Offset(260, 0));
      await tester.pumpAndSettle();

      expect(fired, isEmpty);
    });

    testWidgets('the action label surfaces while dragging, before release', (
      tester,
    ) async {
      final fired = <String>[];
      await _pumpCard(tester, fired: fired);

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Order card')),
      );
      await gesture.moveBy(const Offset(120, 0));
      await tester.pump();

      // Feedback is continuous during the gesture, not only at the end.
      expect(find.text('Preparing'), findsOneWidget);
      expect(fired, isEmpty);

      await gesture.up();
      await tester.pumpAndSettle();
    });
  });

  group('counter service flow', () {
    test('the queue advances one step at a time', () {
      expect(
        CanteenOrderStatus.pending.nextServiceStep,
        CanteenOrderStatus.preparing,
      );
      expect(
        CanteenOrderStatus.accepted.nextServiceStep,
        CanteenOrderStatus.preparing,
      );
      expect(
        CanteenOrderStatus.preparing.nextServiceStep,
        CanteenOrderStatus.ready,
      );
      expect(
        CanteenOrderStatus.ready.nextServiceStep,
        CanteenOrderStatus.completed,
      );
    });

    test('settled orders neither advance nor reject', () {
      for (final status in [
        CanteenOrderStatus.completed,
        CanteenOrderStatus.rejected,
        CanteenOrderStatus.cancelled,
      ]) {
        expect(status.nextServiceStep, isNull, reason: '$status advanced');
        expect(status.canReject, isFalse, reason: '$status was rejectable');
      }
    });

    test('an order in flight can still be rejected', () {
      for (final status in [
        CanteenOrderStatus.pending,
        CanteenOrderStatus.accepted,
        CanteenOrderStatus.preparing,
        CanteenOrderStatus.ready,
      ]) {
        expect(status.canReject, isTrue, reason: '$status was not rejectable');
      }
    });
  });
}
