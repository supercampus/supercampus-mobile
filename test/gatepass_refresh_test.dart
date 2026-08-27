import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/features/authentication/data/auth_repository.dart';
import 'package:supercampus_mobile/src/features/gatepass/data/gatepass_models.dart';
import 'package:supercampus_mobile/src/features/gatepass/data/mock_gatepass_repository.dart';
import 'package:supercampus_mobile/src/features/gatepass/presentation/gatepass_shell.dart';

class _CountingGatepassRepository extends MockGatepassRepository {
  _CountingGatepassRepository()
    : super(studentName: 'Test Student', email: 'student@example.com');

  int loadCount = 0;

  @override
  Future<GatepassStore> loadStore() {
    loadCount++;
    return super.loadStore();
  }
}

void main() {
  testWidgets('standing still does not periodically rotate the gate QR', (
    tester,
  ) async {
    final repository = _CountingGatepassRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: GatepassShell(
          session: const UserSession(
            email: 'student@example.com',
            displayName: 'Test Student',
            role: UserRole.student,
          ),
          repository: repository,
          onExitModule: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(repository.loadCount, 1);

    await tester.pump(const Duration(minutes: 2));
    await tester.pumpAndSettle();

    expect(repository.loadCount, 1);
  });
}
