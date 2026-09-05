import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/core/access/effective_permissions.dart';
import 'package:supercampus_mobile/src/core/access/module_catalog.dart';
import 'package:supercampus_mobile/src/features/modules/presentation/module_stack.dart';

void main() {
  testWidgets('caption follows the selected module', (tester) async {
    const permissions = EffectivePermissions(
      grants: {'academics.*', 'canteen.*'},
    );
    final modules = [
      ModuleCatalog.byId(ModuleCatalog.academics)!,
      ModuleCatalog.byId(ModuleCatalog.canteen)!,
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: ModuleStack.heightFor(modules.length),
            child: ModuleStack(
              modules: modules,
              permissions: permissions,
              onOpenModule: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('module-caption-academics')),
      findsOneWidget,
    );
    await tester.drag(find.byType(PageView), const Offset(0, -180));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('module-caption-canteen')),
      findsOneWidget,
    );
  });
}
