import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/features/gatepass/data/gatepass_models.dart';
import 'package:supercampus_mobile/src/features/gatepass/data/gatepass_qr_selector.dart';
import 'package:supercampus_mobile/src/features/gatepass/data/mock_gatepass_repository.dart';

void main() {
  test(
    'module card uses the same active approved-pass QR as Gatepass',
    () async {
      final store = await MockGatepassRepository(
        studentName: 'Vishnu S',
        email: 'student@mec.local',
      ).loadStore();

      final active = store.requests.firstWhere(
        (request) => request.status == ApprovalStatus.approved,
      );

      expect(gatepassCardQr(store), active.qrPayload);
      expect(gatepassCardQr(store), isNot(store.dailyPass!.qrPayload));
    },
  );

  test('module card falls back to the actual daily access QR', () async {
    final loaded = await MockGatepassRepository(
      studentName: 'Vishnu S',
      email: 'student@mec.local',
    ).loadStore();
    final store = GatepassStore(
      student: loaded.student,
      workflow: loaded.workflow,
      dailyPass: loaded.dailyPass,
      requests: const [],
      visitors: loaded.visitors,
      movements: loaded.movements,
      zone: loaded.zone,
    );

    expect(gatepassCardQr(store), loaded.dailyPass!.qrPayload);
  });
}
