import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supercampus_mobile/src/features/authentication/data/auth_repository.dart';
import 'package:supercampus_mobile/src/features/authentication/data/session_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('session and device identity survive a new store instance', () async {
    final expiresAt = DateTime.utc(2026, 9, 8, 12);
    final firstStore = SessionStore();
    await firstStore.save(
      UserSession(
        email: 'student@mec.local',
        displayName: 'Student',
        role: UserRole.student,
        jwtToken: 'access-token',
        refreshToken: 'refresh-token',
        accessTokenExpiresAt: expiresAt,
        portalFamilies: const [PortalFamily.student],
        activePortalFamily: PortalFamily.student,
        roleIds: const ['student'],
      ),
    );
    final firstDeviceId = await firstStore.deviceId();

    final restored = await SessionStore().load();
    final restoredDeviceId = await SessionStore().deviceId();

    expect(restored?.email, 'student@mec.local');
    expect(restored?.refreshToken, 'refresh-token');
    expect(restored?.accessTokenExpiresAt, expiresAt);
    expect(restored?.portalFamilies, [PortalFamily.student]);
    expect(restoredDeviceId, firstDeviceId);
  });

  test('sign out clears the session but keeps the device identity', () async {
    final store = SessionStore();
    final deviceId = await store.deviceId();
    await store.save(
      const UserSession(
        email: 'student@mec.local',
        displayName: 'Student',
        role: UserRole.student,
      ),
    );

    await store.clear();

    expect(await SessionStore().load(), isNull);
    expect(await SessionStore().deviceId(), deviceId);
  });
}
