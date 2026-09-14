import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/features/gatepass/data/mock_gatepass_repository.dart';
import 'package:supercampus_mobile/src/features/gatepass/presentation/gatepass_access_screen.dart';

void main() {
  testWidgets('shows the six-digit fallback code without pass metadata', (
    tester,
  ) async {
    final storeFuture = MockGatepassRepository(
      studentName: 'Vishnu',
      email: 'vishnu@mec.local',
    ).loadStore();
    await tester.pump(const Duration(milliseconds: 500));
    final store = await storeFuture;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: GatepassAccessScreen(store: store)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('123456'), findsOneWidget);
    expect(find.text('Server-verified gate QR'), findsOneWidget);
    expect(find.text('GP-240803'), findsNothing);
    expect(find.text('ACTIVE'), findsNothing);
    expect(find.text('Hosteller'), findsNothing);
    expect(find.textContaining('Valid until'), findsNothing);
    expect(find.textContaining('Increase screen brightness'), findsNothing);
  });
}
