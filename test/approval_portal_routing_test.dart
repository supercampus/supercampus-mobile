import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/app.dart';
import 'package:supercampus_mobile/src/core/access/effective_permissions.dart';
import 'package:supercampus_mobile/src/core/access/module_catalog.dart';
import 'package:supercampus_mobile/src/core/access/permissions_repository.dart';
import 'package:supercampus_mobile/src/features/authentication/data/auth_repository.dart';
import 'package:supercampus_mobile/src/features/gatepass/data/approval_portal_repository.dart';
import 'package:supercampus_mobile/src/features/modules/presentation/module_stack.dart';

class _PersonaAuthRepository implements AuthRepository {
  _PersonaAuthRepository(this.session);

  final UserSession session;

  @override
  Future<UserSession> signIn({
    required String email,
    required String password,
    required String tenantDomain,
    UserRole? roleHint,
  }) async => session;

  @override
  Future<UserSession> refresh(UserSession session) async => session;

  @override
  Future<void> sendPasswordReset(String email) async {}
}

class _EmptyApprovalRepository implements ApprovalPortalRepository {
  const _EmptyApprovalRepository(this.viewerKind);

  final String viewerKind;

  @override
  Future<ApprovalPortalStore> load() async => ApprovalPortalStore(
    viewerKind: viewerKind,
    children: const [],
    requests: const [],
  );

  @override
  Future<void> decide({
    required String requestId,
    required bool approved,
    String? note,
  }) async {}
}

class _ApprovalPermissionsRepository implements PermissionsRepository {
  const _ApprovalPermissionsRepository();

  @override
  Future<EffectivePermissions> loadFor(UserSession session) async =>
      const EffectivePermissions(
        grants: {'gatepass.outpass.read', 'gatepass.outpass.approve'},
        scopes: {'gatepass': PermissionScope.institution},
      );
}

Future<void> _signIn(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const ValueKey('institution-domain')),
    'mec',
  );
  final continueButton = find.byKey(
    const ValueKey('continue-from-institution'),
  );
  await tester.ensureVisible(continueButton);
  await tester.pumpAndSettle();
  await tester.tap(continueButton);
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextFormField).at(0), 'persona@mec.local');
  await tester.enterText(find.byType(TextFormField).at(1), 'password');
  await tester.tap(find.text('Sign in'));
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(binding.platformDispatcher.clearAccessibilityFeaturesTestValue);
  });

  testWidgets('warden lands in the shared stack then opens approvals', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const session = UserSession(
      email: 'warden@mec.local',
      displayName: 'MEC Hostel Warden',
      role: UserRole.staff,
      roleId: 'warden',
      roleIds: ['warden'],
      jwtToken: 'test-token',
      portalFamilies: [PortalFamily.staff],
    );
    await tester.pumpWidget(
      SupercampusApp(
        authRepository: _PersonaAuthRepository(session),
        permissionsRepository: const _ApprovalPermissionsRepository(),
        approvalPortalRepository: const _EmptyApprovalRepository('warden'),
      ),
    );
    await _signIn(tester);

    expect(find.byType(ModuleStack), findsOneWidget);
    expect(find.byKey(const ValueKey('module-card-gatepass')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('open-module-gatepass')));
    await tester.pumpAndSettle();
    expect(find.text('Warden approvals'), findsOneWidget);
    expect(find.text('Apply outpass'), findsNothing);
  });

  testWidgets('parent lands in the shared stack then opens approvals', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const session = UserSession(
      email: 'selvamoorthy@gmail.com',
      displayName: 'Selvamoorthy',
      role: UserRole.parent,
      roleId: 'parent',
      roleIds: ['parent'],
      jwtToken: 'test-token',
      portalFamilies: [PortalFamily.parent],
    );
    await tester.pumpWidget(
      SupercampusApp(
        authRepository: _PersonaAuthRepository(session),
        permissionsRepository: const _ApprovalPermissionsRepository(),
        approvalPortalRepository: const _EmptyApprovalRepository('parent'),
      ),
    );
    await _signIn(tester);

    expect(find.byType(ModuleStack), findsOneWidget);
    expect(find.byKey(const ValueKey('module-card-gatepass')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('open-module-gatepass')));
    await tester.pumpAndSettle();
    expect(find.text('Parent / Guardian'), findsOneWidget);
    expect(find.text('Apply outpass'), findsNothing);
  });
}
